import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/checkout/domain/payment_draft.dart';

Payment _p(String id, PaymentMethod m, int applied, {int change = 0}) =>
    Payment(id: id, method: m, appliedCents: applied, changeCents: change);
Tip _t(String id, int cents) =>
    Tip(id: id, staffId: 's1', staffName: 'Lea', amountCents: cents, method: PaymentMethod.cash);

void main() {
  group('PaymentDraft derived money', () {
    test('paid, change, and tip totals sum across rows', () {
      final d = PaymentDraft(
        payments: [_p('1', PaymentMethod.cash, 4000, change: 1000), _p('2', PaymentMethod.card, 1000)],
        tips: [_t('t1', 500), _t('t2', 300)],
      );
      expect(d.paidCents, 5000); // applied only (excludes change)
      expect(d.changeCents, 1000);
      expect(d.tipTotalCents, 800);
    });

    test('remaining is total − paid, clamped at 0; isSettled is exact equality', () {
      final d = PaymentDraft(payments: [_p('1', PaymentMethod.cash, 5000)]);
      expect(d.remainingCents(6000), 1000);
      expect(d.isSettled(6000), isFalse);

      expect(d.remainingCents(5000), 0);
      expect(d.isSettled(5000), isTrue);

      // overpaid applied (shouldn't happen via the controller, but math is safe)
      expect(d.remainingCents(4000), 0);
      expect(d.isSettled(4000), isFalse);
    });

    test('a zero total is settled with no tenders', () {
      const d = PaymentDraft();
      expect(d.remainingCents(0), 0);
      expect(d.isSettled(0), isTrue);
    });
  });
}
