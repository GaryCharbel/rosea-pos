import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog.dart';

/// One line on the in-progress ticket. Prices are integer cents. Every line is
/// credited to the staff member who performed/sold it (performer-per-line) — that is
/// a product-logic invariant, so a line can never exist without a performer.
@immutable
class DraftLine {
  const DraftLine({
    required this.id,
    required this.refId,
    required this.kind,
    required this.name,
    required this.unitPriceCents,
    required this.qty,
    required this.lineDiscountCents,
    required this.performerStaffId,
    required this.performerName,
  });

  /// Local line id (uuid) — the stable key while ringing up. Not the server row id.
  final String id;

  /// The catalog service/product id this line was rung from.
  final String refId;
  final CatalogKind kind;
  final String name;
  final int unitPriceCents;
  final int qty;
  final int lineDiscountCents;
  final String performerStaffId;
  final String performerName;

  /// price × qty, before the line discount.
  int get grossCents => unitPriceCents * qty;

  /// What the line actually contributes to the ticket (never negative).
  int get lineTotalCents => grossCents - lineDiscountCents;

  DraftLine copyWith({
    int? qty,
    int? lineDiscountCents,
    String? performerStaffId,
    String? performerName,
  }) {
    return DraftLine(
      id: id,
      refId: refId,
      kind: kind,
      name: name,
      unitPriceCents: unitPriceCents,
      qty: qty ?? this.qty,
      lineDiscountCents: lineDiscountCents ?? this.lineDiscountCents,
      performerStaffId: performerStaffId ?? this.performerStaffId,
      performerName: performerName ?? this.performerName,
    );
  }
}

/// The in-progress ticket held locally while ringing up (works through a WiFi blip).
/// It is persisted to the server + paid in the pay flow (Phase 4.4).
@immutable
class CheckoutDraft {
  const CheckoutDraft({this.lines = const <DraftLine>[]});

  final List<DraftLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;

  /// Sum of price×qty across lines (pre-discount).
  int get subtotalCents => lines.fold(0, (s, l) => s + l.grossCents);

  /// Sum of per-line discounts.
  int get discountCents => lines.fold(0, (s, l) => s + l.lineDiscountCents);

  /// What the customer owes: subtotal − discounts.
  int get totalCents => lines.fold(0, (s, l) => s + l.lineTotalCents);

  CheckoutDraft withLines(List<DraftLine> newLines) => CheckoutDraft(lines: newLines);
}
