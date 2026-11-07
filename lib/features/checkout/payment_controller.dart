import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../staff/staff_member.dart';
import 'domain/payment_draft.dart';

/// Composes the split tenders + tips for the current ticket. Pure cents; the actual
/// pay_ticket call happens in the pay flow (Phase 4.4). Cleared whenever the ticket is.
class PaymentController extends Notifier<PaymentDraft> {
  final Uuid _uuid = const Uuid();

  @override
  PaymentDraft build() => const PaymentDraft();

  /// A cash tender of [tenderedCents] against [remainingCents]: the applied amount is
  /// capped at the remaining and the overpay becomes change (display-only). A tender
  /// at/under the remaining applies in full with no change (supports splitting).
  void addCashTender(int tenderedCents, int remainingCents) {
    if (tenderedCents <= 0 || remainingCents <= 0) return;
    final applied = tenderedCents >= remainingCents ? remainingCents : tenderedCents;
    final change = tenderedCents >= remainingCents ? tenderedCents - remainingCents : 0;
    _add(Payment(
      id: _uuid.v4(),
      method: PaymentMethod.cash,
      appliedCents: applied,
      changeCents: change,
    ));
  }

  /// A non-cash tender (card/other) for an exact [appliedCents], capped at [remaining]
  /// so a split can never overpay the ticket. No change on non-cash.
  void addCardOrOther(PaymentMethod method, int appliedCents, int remainingCents) {
    if (method == PaymentMethod.cash) return;
    if (appliedCents <= 0 || remainingCents <= 0) return;
    final applied = appliedCents > remainingCents ? remainingCents : appliedCents;
    _add(Payment(id: _uuid.v4(), method: method, appliedCents: applied));
  }

  void removePayment(String id) {
    state = state.copyWith(payments: state.payments.where((p) => p.id != id).toList());
  }

  void addTip(StaffMember staff, int amountCents, PaymentMethod method) {
    if (amountCents <= 0) return;
    state = state.copyWith(tips: <Tip>[
      ...state.tips,
      Tip(
        id: _uuid.v4(),
        staffId: staff.id,
        staffName: staff.name,
        amountCents: amountCents,
        method: method,
      ),
    ]);
  }

  void removeTip(String id) {
    state = state.copyWith(tips: state.tips.where((t) => t.id != id).toList());
  }

  void clear() => state = const PaymentDraft();

  void _add(Payment p) => state = state.copyWith(payments: <Payment>[...state.payments, p]);
}

final paymentDraftProvider =
    NotifierProvider<PaymentController, PaymentDraft>(PaymentController.new);
