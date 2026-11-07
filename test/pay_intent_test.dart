import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/core/errors/app_error.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/domain/checkout_draft.dart';
import 'package:rosea_pos/features/checkout/domain/pay_intent.dart';
import 'package:rosea_pos/features/checkout/domain/payment_draft.dart';

DraftLine _line() => const DraftLine(
      id: 'l1',
      refId: 'svc1',
      kind: CatalogKind.service,
      name: 'Cut',
      unitPriceCents: 5000,
      qty: 1,
      lineDiscountCents: 0,
      performerStaffId: 'st1',
      performerName: 'Lea',
    );

void main() {
  group('validatePayable', () {
    test('passes a settled ticket with a performer', () {
      final err = validatePayable(
        draft: CheckoutDraft(lines: [_line()]),
        pay: const PaymentDraft(
            payments: [Payment(id: 'p', method: PaymentMethod.cash, appliedCents: 5000)]),
        openedByStaffId: 'st1',
      );
      expect(err, isNull);
    });

    test('empty ticket, missing performer, and split mismatch are actionable', () {
      expect(
        validatePayable(draft: const CheckoutDraft(), pay: const PaymentDraft(), openedByStaffId: 'st1'),
        isA<PayError>(),
      );
      expect(
        validatePayable(draft: CheckoutDraft(lines: [_line()]), pay: const PaymentDraft(), openedByStaffId: null),
        isA<PayError>(),
      );
      final mismatch = validatePayable(
        draft: CheckoutDraft(lines: [_line()]),
        pay: const PaymentDraft(
            payments: [Payment(id: 'p', method: PaymentMethod.cash, appliedCents: 4000)]),
        openedByStaffId: 'st1',
      );
      expect(mismatch, isA<PayError>());
      expect(mismatch!.message, contains('Adjust the split'));
    });
  });

  group('PayIntent', () {
    final intent = PayIntent(
      clientTx: 'tx-1',
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
      tips: const [PayTip(staffId: 'st2', amountCents: 500, method: PaymentMethod.card)],
    );

    test('rpc args convert cents to numeric decimal strings', () {
      expect(intent.rpcPayments(), [
        {'method': 'cash', 'amount': '50.00'},
      ]);
      expect(intent.rpcTips(), [
        {'staff_id': 'st2', 'amount': '5.00', 'method': 'card'},
      ]);
    });

    test('json round-trips losslessly (durable outbox storage)', () {
      final back = PayIntent.decode(intent.encode());
      expect(back.clientTx, 'tx-1');
      expect(back.openedByStaffId, 'st1');
      expect(back.totalCents, 5000);
      expect(back.lines.single.refId, 'svc1');
      expect(back.lines.single.kind, CatalogKind.service);
      expect(back.payments.single.appliedCents, 5000);
      expect(back.tips.single.method, PaymentMethod.card);
    });
  });
}
