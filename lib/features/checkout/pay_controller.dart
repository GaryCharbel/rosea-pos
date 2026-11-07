import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error.dart';
import 'data/outbox_database.dart';
import 'data/outbox_repo.dart';
import 'domain/pay_intent.dart';
import 'domain/receipt.dart';
import 'pay_gateway.dart';

/// The outcome of taking payment, driving the checkout UI.
@immutable
sealed class PayState {
  const PayState();
}

class PayIdle extends PayState {
  const PayIdle();
}

class PaySending extends PayState {
  const PaySending();
}

class PaySuccess extends PayState {
  const PaySuccess(this.receipt);
  final Receipt receipt;
}

/// Offline / transient — kept queued, will finish on retry (idempotent).
class PayQueued extends PayState {
  const PayQueued(this.message);
  final String message;
}

/// Hard failure — the ticket must change; surfaced, not auto-retried.
class PayFailed extends PayState {
  const PayFailed(this.message);
  final String message;
}

/// Orchestrates taking payment: persist a durable intent, create the server ticket +
/// lines, call pay_ticket, map the result/errors. Single-flight so a double-tap can't
/// double-submit; retries replay the identical idempotent call.
class PayController extends Notifier<PayState> {
  bool _inFlight = false;

  @override
  PayState build() => const PayIdle();

  Future<void> pay(PayIntent intent) async {
    if (_inFlight) return;
    _inFlight = true;
    state = const PaySending();
    try {
      final repo = ref.read(outboxRepoProvider);
      await repo.enqueue(intent);
      await _flush(intent, repo, ref.read(payGatewayProvider));
    } finally {
      _inFlight = false;
    }
  }

  /// Retry anything stranded by an app kill or a transient failure. Reconciles the
  /// outbox silently (no receipt dialog) — call on boot / when connectivity returns.
  Future<void> flushPending() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final repo = ref.read(outboxRepoProvider);
      await repo.recoverInterrupted();
      final gw = ref.read(payGatewayProvider);
      for (final intent in await repo.pendingIntents()) {
        final ok = await _flush(intent, repo, gw, silent: true);
        if (!ok) break; // still offline — stop hammering, the next trigger retries
      }
    } finally {
      _inFlight = false;
    }
  }

  void reset() => state = const PayIdle();

  /// Returns true on success. [silent] keeps the user-facing state untouched (boot
  /// reconcile), only updating the durable outbox.
  Future<bool> _flush(PayIntent intent, OutboxRepo repo, PayGateway gw,
      {bool silent = false}) async {
    await repo.markSending(intent.clientTx);
    try {
      final result = await gw.submit(intent);
      await repo.markPaid(intent.clientTx,
          ticketNo: (result['ticket_no'] as num?)?.toInt(), resultJson: jsonEncode(result));
      if (!silent) state = PaySuccess(Receipt.fromResult(result));
      return true;
    } catch (e) {
      final AppError err = mapPayError(e);
      final bool retriable = err is PayError && err.retriable;
      if (retriable) {
        await repo.markPending(intent.clientTx, err.message);
        if (!silent) state = PayQueued(err.message);
      } else {
        await repo.markFailed(intent.clientTx, err.message);
        if (!silent) state = PayFailed(err.message);
      }
      return false;
    }
  }
}

// ── Providers ───────────────────────────────────────────────────────────────

final outboxDatabaseProvider = Provider<OutboxDatabase>((ref) {
  final db = OutboxDatabase();
  ref.onDispose(db.close);
  return db;
});

final outboxRepoProvider = Provider<OutboxRepo>((ref) {
  return OutboxRepo(ref.watch(outboxDatabaseProvider));
});

final payGatewayProvider = Provider<PayGateway>((ref) {
  return SupabasePayGateway(Supabase.instance.client);
});

final payControllerProvider =
    NotifierProvider<PayController, PayState>(PayController.new);
