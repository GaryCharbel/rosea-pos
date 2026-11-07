import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/data/outbox_database.dart';
import 'package:rosea_pos/features/checkout/data/outbox_repo.dart';
import 'package:rosea_pos/features/checkout/domain/pay_intent.dart';
import 'package:rosea_pos/features/checkout/domain/payment_draft.dart';

PayIntent _intent(String tx) => PayIntent(
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

void main() {
  late OutboxDatabase db;
  late OutboxRepo repo;

  setUp(() {
    db = OutboxDatabase.forTesting(NativeDatabase.memory());
    repo = OutboxRepo(db);
  });
  tearDown(() async => db.close());

  test('enqueue is idempotent by client_tx', () async {
    await repo.enqueue(_intent('tx1'));
    await repo.enqueue(_intent('tx1')); // same tx -> ignored
    final row = await repo.byClientTx('tx1');
    expect(row!.status, 'pending');
    expect((await repo.pendingIntents()).length, 1);
  });

  test('state transitions: sending(++attempts) -> paid', () async {
    await repo.enqueue(_intent('tx1'));
    await repo.markSending('tx1');
    var row = await repo.byClientTx('tx1');
    expect(row!.status, 'sending');
    expect(row.attempts, 1);

    await repo.markPaid('tx1', ticketNo: 1001, resultJson: '{"ok":true}');
    row = await repo.byClientTx('tx1');
    expect(row!.status, 'paid');
    expect(row.ticketNo, 1001);
    expect(row.resultJson, '{"ok":true}');
  });

  test('markPending / markFailed record the reason', () async {
    await repo.enqueue(_intent('tx1'));
    await repo.markPending('tx1', 'offline');
    expect((await repo.byClientTx('tx1'))!.status, 'pending');
    await repo.markFailed('tx1', 'split mismatch');
    final row = await repo.byClientTx('tx1');
    expect(row!.status, 'failed');
    expect(row.errorMessage, 'split mismatch');
  });

  test('recoverInterrupted re-queues sending rows; pendingIntents decodes them', () async {
    await repo.enqueue(_intent('tx1'));
    await repo.markSending('tx1'); // interrupted mid-send
    expect((await repo.pendingIntents()), isEmpty); // not pending while sending

    await repo.recoverInterrupted();
    final pend = await repo.pendingIntents();
    expect(pend.length, 1);
    expect(pend.single.clientTx, 'tx1');
    expect(pend.single.totalCents, 5000);
  });
}
