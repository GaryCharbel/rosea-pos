import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';

/// The receipt payload returned by pay_ticket (`_pay_ticket_result`). Amounts arrive
/// as `numeric` decimals and are parsed to cents. Commission is never present here.
@immutable
class Receipt {
  const Receipt({
    required this.ticketNo,
    required this.status,
    required this.subtotalCents,
    required this.discountCents,
    required this.totalCents,
    required this.salonName,
    required this.currency,
    required this.lines,
    required this.payments,
    required this.tips,
    required this.tipTotalCents,
    this.receiptHeader,
    this.receiptFooter,
  });

  final int? ticketNo;
  final String status;
  final int subtotalCents;
  final int discountCents;
  final int totalCents;
  final String salonName;
  final String currency;
  final List<ReceiptLine> lines;
  final List<ReceiptPayment> payments;
  final List<ReceiptTip> tips;
  final int tipTotalCents;
  final String? receiptHeader;
  final String? receiptFooter;

  static Receipt fromResult(Map<String, dynamic> j) {
    final salon = (j['salon'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return Receipt(
      ticketNo: (j['ticket_no'] as num?)?.toInt(),
      status: (j['status'] as String?) ?? 'paid',
      subtotalCents: centsFromServer(j['subtotal']),
      discountCents: centsFromServer(j['discount_total']),
      totalCents: centsFromServer(j['total']),
      salonName: (salon['name'] as String?) ?? 'Rosea',
      currency: (salon['currency'] as String?) ?? '',
      receiptHeader: salon['receipt_header'] as String?,
      receiptFooter: salon['receipt_footer'] as String?,
      lines: ((j['lines'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => ReceiptLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: ((j['payments'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => ReceiptPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
      tips: ((j['tips'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => ReceiptTip.fromJson(e as Map<String, dynamic>))
          .toList(),
      tipTotalCents: centsFromServer(j['tip_total']),
    );
  }
}

@immutable
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.performerName,
    required this.qty,
    required this.lineTotalCents,
  });
  final String name;
  final String performerName;
  final num qty;
  final int lineTotalCents;

  static ReceiptLine fromJson(Map<String, dynamic> j) => ReceiptLine(
        name: (j['name'] as String?) ?? '',
        performerName: (j['performer_name'] as String?) ?? '',
        qty: (j['qty'] as num?) ?? 1,
        lineTotalCents: centsFromServer(j['line_total']),
      );
}

@immutable
class ReceiptPayment {
  const ReceiptPayment({required this.method, required this.amountCents});
  final String method;
  final int amountCents;
  static ReceiptPayment fromJson(Map<String, dynamic> j) => ReceiptPayment(
        method: (j['method'] as String?) ?? '',
        amountCents: centsFromServer(j['amount']),
      );
}

@immutable
class ReceiptTip {
  const ReceiptTip({required this.staffName, required this.amountCents});
  final String staffName;
  final int amountCents;
  static ReceiptTip fromJson(Map<String, dynamic> j) => ReceiptTip(
        staffName: (j['staff_name'] as String?) ?? '',
        amountCents: centsFromServer(j['amount']),
      );
}
