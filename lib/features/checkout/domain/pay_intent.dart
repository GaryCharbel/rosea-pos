import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/money/money.dart';
import '../../catalog/domain/catalog.dart';
import 'checkout_draft.dart';
import 'payment_draft.dart';

/// Everything needed to pay a ticket, captured once at "Take payment" so it can be
/// persisted to the durable outbox and replayed safely. [clientTx] is minted once and
/// reused on every retry (the server's paid_tx idempotency key).
@immutable
class PayIntent {
  const PayIntent({
    required this.clientTx,
    required this.openedByStaffId,
    required this.lines,
    required this.payments,
    required this.tips,
    required this.totalCents,
  });

  final String clientTx;
  final String openedByStaffId;
  final List<PayLine> lines;
  final List<PayTender> payments;
  final List<PayTip> tips;
  final int totalCents;

  /// p_payments for pay_ticket: applied amounts as `numeric` decimal strings.
  List<Map<String, dynamic>> rpcPayments() => <Map<String, dynamic>>[
        for (final p in payments)
          <String, dynamic>{
            'method': p.method.wire,
            'amount': centsToDecimalString(p.appliedCents),
          },
      ];

  /// p_tips for pay_ticket (standalone tips).
  List<Map<String, dynamic>> rpcTips() => <Map<String, dynamic>>[
        for (final t in tips)
          <String, dynamic>{
            'staff_id': t.staffId,
            'amount': centsToDecimalString(t.amountCents),
            'method': t.method.wire,
          },
      ];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'client_tx': clientTx,
        'opened_by': openedByStaffId,
        'total_cents': totalCents,
        'lines': lines.map((l) => l.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'tips': tips.map((t) => t.toJson()).toList(),
      };

  static PayIntent fromJson(Map<String, dynamic> j) => PayIntent(
        clientTx: j['client_tx'] as String,
        openedByStaffId: j['opened_by'] as String,
        totalCents: (j['total_cents'] as num).toInt(),
        lines: (j['lines'] as List<dynamic>)
            .map((e) => PayLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        payments: (j['payments'] as List<dynamic>)
            .map((e) => PayTender.fromJson(e as Map<String, dynamic>))
            .toList(),
        tips: (j['tips'] as List<dynamic>)
            .map((e) => PayTip.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String encode() => jsonEncode(toJson());
  static PayIntent decode(String s) => fromJson(jsonDecode(s) as Map<String, dynamic>);
}

@immutable
class PayLine {
  const PayLine({
    required this.refId,
    required this.kind,
    required this.name,
    required this.unitPriceCents,
    required this.qty,
    required this.lineDiscountCents,
    required this.performerStaffId,
  });

  final String refId;
  final CatalogKind kind;
  final String name;
  final int unitPriceCents;
  final int qty;
  final int lineDiscountCents;
  final String performerStaffId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ref_id': refId,
        'kind': kind.name,
        'name': name,
        'unit_price_cents': unitPriceCents,
        'qty': qty,
        'line_discount_cents': lineDiscountCents,
        'performer_staff_id': performerStaffId,
      };

  static PayLine fromJson(Map<String, dynamic> j) => PayLine(
        refId: j['ref_id'] as String,
        kind: CatalogKind.values.byName(j['kind'] as String),
        name: j['name'] as String,
        unitPriceCents: (j['unit_price_cents'] as num).toInt(),
        qty: (j['qty'] as num).toInt(),
        lineDiscountCents: (j['line_discount_cents'] as num).toInt(),
        performerStaffId: j['performer_staff_id'] as String,
      );
}

@immutable
class PayTender {
  const PayTender({required this.method, required this.appliedCents});
  final PaymentMethod method;
  final int appliedCents;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'method': method.name, 'applied_cents': appliedCents};
  static PayTender fromJson(Map<String, dynamic> j) => PayTender(
        method: PaymentMethod.values.byName(j['method'] as String),
        appliedCents: (j['applied_cents'] as num).toInt(),
      );
}

@immutable
class PayTip {
  const PayTip({required this.staffId, required this.amountCents, required this.method});
  final String staffId;
  final int amountCents;
  final PaymentMethod method;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'staff_id': staffId,
        'amount_cents': amountCents,
        'method': method.name,
      };
  static PayTip fromJson(Map<String, dynamic> j) => PayTip(
        staffId: j['staff_id'] as String,
        amountCents: (j['amount_cents'] as num).toInt(),
        method: PaymentMethod.values.byName(j['method'] as String),
      );
}

/// Client-side pre-flight: catch the obvious problems with an actionable message
/// BEFORE the network call (the server re-validates authoritatively). Returns null
/// when the draft is payable.
AppError? validatePayable({
  required CheckoutDraft draft,
  required PaymentDraft pay,
  required String? openedByStaffId,
}) {
  if (draft.isEmpty) {
    return const PayError('Add at least one service or product before taking payment.');
  }
  if (openedByStaffId == null) {
    return const PayError('Choose a performer before taking payment.');
  }
  if (pay.payments.any((p) => p.appliedCents <= 0) || pay.tips.any((t) => t.amountCents <= 0)) {
    return const PayError('Every payment and tip must be a positive amount.');
  }
  if (!pay.isSettled(draft.totalCents)) {
    return PayError(
      'Payments total ${formatCents(pay.paidCents)} but the ticket is '
      '${formatCents(draft.totalCents)}. Adjust the split so it matches.',
    );
  }
  return null;
}
