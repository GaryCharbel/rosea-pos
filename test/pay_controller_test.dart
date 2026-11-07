import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/data/outbox_database.dart';
import 'package:rosea_pos/features/checkout/pay_controller.dart';
import 'package:rosea_pos/features/checkout/pay_gateway.dart';
import 'package:rosea_pos/features/checkout/domain/pay_intent.dart';
import 'package:rosea_pos/features/checkout/domain/payment_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeGateway implements PayGateway {
  _FakeGateway(this.behavior);
  Future<Map<String, dynamic>> Function(PayIntent) behavior;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> submit(PayIntent intent) {
    calls++;
    return behavior(intent);
  }
}

PayIntent _intent([String tx = 'tx1']) => PayIntent(
      clientTx: tx,
      openedByStaffId: 'st1',
      totalCents: 5000,
      lines: const [
        PayLine(
          refId: 'svc1',
          kind: CatalogKind.service,
          name: 'Cut',
          unitPriceCents: 5000,
          qty: 1,
          lineDiscountCents: 0,
          performerStaffId: 'st1',
        ),
      ],
      payments: const [PayTender(method: PaymentMethod.cash, appliedCents: 5000)],
      tips: const [],
    );

final _okResult = <String, dynamic>{
  'ticket_no': 1001,
  'status': 'paid',
  'subtotal': '50.00',
  'discount_total': '0.00',
  'total': '50.00',
  'tip_total': '0',
  'lines': <dynamic>[],
  'payments': <dynamic>[
    {'method': 'cash', 'amount': '50.00'}
  ],
  'tips': <dynamic>[],
};

ProviderContainer _container(_FakeGateway gw) {
  final c = ProviderContainer(overrides: [
    outboxDatabaseProvider.overrideWith((ref) {
      final db = OutboxDatabase.forTesting(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    }),
    payGatewayProvider.overrideWithValue(gw),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('success -> PaySuccess with receipt, outbox marked paid', () async {
    final c = _container(_FakeGateway((_) async => _okResult));
    await c.read(payControllerProvider.notifier).pay(_intent());

    final state = c.read(payControllerProvider);
    expect(state, isA<PaySuccess>());
    expect((state as PaySuccess).receipt.ticketNo, 1001);
    expect((await c.read(outboxRepoProvider).byClientTx('tx1'))!.status, 'paid');
  });

  test('transient failure -> PayQueued, outbox kept pending for retry', () async {
    final c = _container(_FakeGateway((_) async => throw TimeoutException('offline')));
    await c.read(payControllerProvider.notifier).pay(_intent());

    expect(c.read(payControllerProvider), isA<PayQueued>());
    expect((await c.read(outboxRepoProvider).byClientTx('tx1'))!.status, 'pending');
  });

  test('server rejection (P0002) -> PayFailed, outbox marked failed (no auto-retry)', () async {
    final c = _container(_FakeGateway(
        (_) async => throw PostgrestException(message: 'Adjust the split', code: 'P0002')));
    await c.read(payControllerProvider.notifier).pay(_intent());

    final state = c.read(payControllerProvider);
    expect(state, isA<PayFailed>());
    expect((state as PayFailed).message, 'Adjust the split');
    expect((await c.read(outboxRepoProvider).byClientTx('tx1'))!.status, 'failed');
  });

  test('unknown error -> PayFailed, outbox failed (not retried)', () async {
    final c = _container(_FakeGateway((_) async => throw const FormatException('boom')));
    await c.read(payControllerProvider.notifier).pay(_intent());
    expect(c.read(payControllerProvider), isA<PayFailed>());
    expect((await c.read(outboxRepoProvider).byClientTx('tx1'))!.status, 'failed');
  });

  test('single-flight: a second pay while one is in flight is ignored', () async {
    final gate = Completer<Map<String, dynamic>>();
    final gw = _FakeGateway((_) => gate.future);
    final c = _container(gw);
    final ctrl = c.read(payControllerProvider.notifier);

    final f1 = ctrl.pay(_intent());
    final f2 = ctrl.pay(_intent()); // in-flight -> no-op
    gate.complete(_okResult);
    await Future.wait([f1, f2]);

    expect(gw.calls, 1);
  });

  test('flushPending retries a stranded pending sale and completes it', () async {
    final gw = _FakeGateway((_) async => _okResult);
    final c = _container(gw);
    // seed a pending row directly via the repo
    await c.read(outboxRepoProvider).enqueue(_intent('tx9'));

    await c.read(payControllerProvider.notifier).flushPending();
    expect((await c.read(outboxRepoProvider).byClientTx('tx9'))!.status, 'paid');
  });
}
