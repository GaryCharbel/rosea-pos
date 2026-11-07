import 'package:drift/drift.dart';

import '../domain/pay_intent.dart';
import 'outbox_database.dart';

/// Durable queue of pay attempts. The client_tx is the key, so re-enqueuing the same
/// checkout is a no-op and a retry replays the identical (idempotent) call.
class OutboxRepo {
  OutboxRepo(this._db);

  final OutboxDatabase _db;

  /// Record a new attempt (ignored if this client_tx is already queued).
  Future<void> enqueue(PayIntent intent) async {
    final now = DateTime.now();
    await _db.into(_db.payOutbox).insert(
          PayOutboxCompanion.insert(
            clientTx: intent.clientTx,
            payload: intent.encode(),
            createdAt: now,
            updatedAt: now,
            status: const Value('pending'),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> markSending(String clientTx) async {
    await _patch(
      clientTx,
      PayOutboxCompanion(
        status: const Value('sending'),
        attempts: Value(await _attempts(clientTx) + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markPaid(String clientTx, {int? ticketNo, required String resultJson}) => _patch(
        clientTx,
        PayOutboxCompanion(
          status: const Value('paid'),
          ticketNo: Value(ticketNo),
          resultJson: Value(resultJson),
          errorMessage: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Transient/offline failure: keep it queued (pending) to retry the idempotent call.
  Future<void> markPending(String clientTx, String errorMessage) => _patch(
        clientTx,
        PayOutboxCompanion(
          status: const Value('pending'),
          errorMessage: Value(errorMessage),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Hard failure (the ticket must change): stop auto-retrying, surface the reason.
  Future<void> markFailed(String clientTx, String errorMessage) => _patch(
        clientTx,
        PayOutboxCompanion(
          status: const Value('failed'),
          errorMessage: Value(errorMessage),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Attempts interrupted mid-send (app killed) are safe to re-queue — the server
  /// replays by client_tx. Call once on boot before flushing.
  Future<void> recoverInterrupted() async {
    await (_db.update(_db.payOutbox)..where((t) => t.status.equals('sending')))
        .write(PayOutboxCompanion(status: const Value('pending'), updatedAt: Value(DateTime.now())));
  }

  /// Pending intents, oldest first. [maxAttempts], when set, excludes rows that have
  /// already been auto-retried that many times — they stay queued (never lost) but stop
  /// hammering in the background; the owner can force them from the outbox screen (4.5).
  Future<List<PayIntent>> pendingIntents({int? maxAttempts}) async {
    final rows = await (_db.select(_db.payOutbox)
          ..where((t) => maxAttempts == null
              ? t.status.equals('pending')
              : t.status.equals('pending') & t.attempts.isSmallerThanValue(maxAttempts))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    return rows.map((r) => PayIntent.decode(r.payload)).toList();
  }

  Future<PayOutboxData?> byClientTx(String clientTx) =>
      (_db.select(_db.payOutbox)..where((t) => t.clientTx.equals(clientTx))).getSingleOrNull();

  Future<int> _attempts(String clientTx) async {
    final row = await byClientTx(clientTx);
    return row?.attempts ?? 0;
  }

  Future<void> _patch(String clientTx, PayOutboxCompanion patch) async {
    await (_db.update(_db.payOutbox)..where((t) => t.clientTx.equals(clientTx))).write(patch);
  }
}
