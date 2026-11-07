import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/checkout/domain/payment_draft.dart';
import 'package:rosea_pos/features/checkout/payment_controller.dart';
import 'package:rosea_pos/features/staff/staff_member.dart';

const _lea = StaffMember(id: 'st1', name: 'Lea');

void main() {
  late ProviderContainer c;
  PaymentController ctrl() => c.read(paymentDraftProvider.notifier);
  PaymentDraft draft() => c.read(paymentDraftProvider);

  setUp(() => c = ProviderContainer());
  tearDown(() => c.dispose());

  test('exact cash tender applies in full with no change', () {
    ctrl().addCashTender(5000, 5000);
    expect(draft().paidCents, 5000);
    expect(draft().changeCents, 0);
    expect(draft().isSettled(5000), isTrue);
  });

  test('cash over-tender caps applied at the remaining and returns change', () {
    ctrl().addCashTender(6000, 5000); // $60 on a $50 ticket
    expect(draft().payments.single.appliedCents, 5000);
    expect(draft().payments.single.changeCents, 1000);
    expect(draft().remainingCents(5000), 0);
  });

  test('partial cash then card settles a split (applied never exceeds total)', () {
    ctrl().addCashTender(2000, 5000); // partial, no change
    expect(draft().payments.single.changeCents, 0);
    expect(draft().remainingCents(5000), 3000);

    ctrl().addCardOrOther(PaymentMethod.card, 9999, 3000); // asks too much -> capped
    expect(draft().payments.last.appliedCents, 3000);
    expect(draft().isSettled(5000), isTrue);
  });

  test('addCardOrOther ignores cash; zero/negative amounts are no-ops', () {
    ctrl().addCardOrOther(PaymentMethod.cash, 1000, 5000); // wrong method -> ignored
    ctrl().addCardOrOther(PaymentMethod.card, 0, 5000); // zero -> ignored
    ctrl().addCashTender(0, 5000); // zero -> ignored
    expect(draft().payments, isEmpty);
  });

  test('tips add and remove, independent of the ticket total', () {
    ctrl().addTip(_lea, 500, PaymentMethod.cash);
    ctrl().addTip(_lea, 0, PaymentMethod.cash); // ignored
    expect(draft().tipTotalCents, 500);
    final id = draft().tips.single.id;
    ctrl().removeTip(id);
    expect(draft().tips, isEmpty);
  });

  test('removePayment and clear', () {
    ctrl().addCashTender(2000, 5000);
    ctrl().addCardOrOther(PaymentMethod.card, 3000, 3000);
    ctrl().removePayment(draft().payments.first.id);
    expect(draft().payments.length, 1);
    ctrl().clear();
    expect(draft().payments, isEmpty);
    expect(draft().tips, isEmpty);
  });

  test('clearPayments drops tenders but keeps tips', () {
    ctrl().addCashTender(5000, 5000);
    ctrl().addTip(_lea, 500, PaymentMethod.cash);
    ctrl().clearPayments();
    expect(draft().payments, isEmpty);
    expect(draft().tipTotalCents, 500);
  });
}
