import 'package:flutter/foundation.dart';

/// Manual tender methods (no card-terminal integration in Stage 1).
enum PaymentMethod { cash, card, other }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.other => 'Other',
      };

  /// The wire value sent to pay_ticket (matches the server payment_method enum).
  String get wire => name;
}

/// One tender applied to the ticket. [appliedCents] is what counts toward the total
/// (what pay_ticket receives); [changeCents] is display-only (cash given back) and is
/// never sent to the server.
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.method,
    required this.appliedCents,
    this.changeCents = 0,
  });

  final String id;
  final PaymentMethod method;
  final int appliedCents;
  final int changeCents;
}

/// A tip for a staff member — tracked separately from commission, per the product
/// invariant. Carries how it was tendered (for cash-up).
@immutable
class Tip {
  const Tip({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.amountCents,
    required this.method,
  });

  final String id;
  final String staffId;
  final String staffName;
  final int amountCents;
  final PaymentMethod method;
}

/// The settlement being composed for the ticket: the split tenders + any tips.
@immutable
class PaymentDraft {
  const PaymentDraft({this.payments = const <Payment>[], this.tips = const <Tip>[]});

  final List<Payment> payments;
  final List<Tip> tips;

  /// Total applied to the ticket (excludes change and tips).
  int get paidCents => payments.fold(0, (s, p) => s + p.appliedCents);

  int get tipTotalCents => tips.fold(0, (s, t) => s + t.amountCents);

  /// Change handed back across cash tenders (display-only).
  int get changeCents => payments.fold(0, (s, p) => s + p.changeCents);

  /// What still needs tendering for a ticket of [totalCents] (never negative: applied
  /// is capped at the remaining when tendering, so overpay shows as change not excess).
  int remainingCents(int totalCents) {
    final r = totalCents - paidCents;
    return r < 0 ? 0 : r;
  }

  /// Settled when the applied tenders exactly equal the total. A fully-discounted
  /// total of 0 is settled with no tenders (matches pay_ticket's empty-payment case).
  bool isSettled(int totalCents) => paidCents == totalCents;

  PaymentDraft copyWith({List<Payment>? payments, List<Tip>? tips}) =>
      PaymentDraft(payments: payments ?? this.payments, tips: tips ?? this.tips);
}
