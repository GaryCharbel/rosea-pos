import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog.dart';
import '../../clients/client.dart';

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
  const CheckoutDraft({
    this.lines = const <DraftLine>[],
    this.client,
    this.ticketDiscountCents = 0,
  });

  final List<DraftLine> lines;

  /// The customer attached to this ticket (optional — walk-ins have none). Carried to
  /// the server ticket row as `client_id`.
  final Client? client;

  /// A whole-ticket discount (on top of any per-line discounts), in cents. Always
  /// within [0, preTicketTotalCents]. pay_ticket distributes it pro-rata for commission.
  final int ticketDiscountCents;

  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;

  /// Sum of price×qty across lines (pre-discount).
  int get subtotalCents => lines.fold(0, (s, l) => s + l.grossCents);

  /// Sum of per-line discounts.
  int get discountCents => lines.fold(0, (s, l) => s + l.lineDiscountCents);

  /// Line total before the whole-ticket discount (Σ line totals).
  int get preTicketTotalCents => lines.fold(0, (s, l) => s + l.lineTotalCents);

  /// What the customer owes: Σ line totals − the ticket discount (never negative).
  int get totalCents {
    final t = preTicketTotalCents - ticketDiscountCents;
    return t < 0 ? 0 : t;
  }

  int _clampTicketDiscount(int cents, int pre) =>
      cents < 0 ? 0 : (cents > pre ? pre : cents);

  CheckoutDraft withLines(List<DraftLine> newLines) {
    final pre = newLines.fold(0, (int s, DraftLine l) => s + l.lineTotalCents);
    return CheckoutDraft(
      lines: newLines,
      client: client,
      // keep the ticket discount within the (possibly smaller) new total
      ticketDiscountCents: _clampTicketDiscount(ticketDiscountCents, pre),
    );
  }

  CheckoutDraft withClient(Client? c) =>
      CheckoutDraft(lines: lines, client: c, ticketDiscountCents: ticketDiscountCents);

  CheckoutDraft withTicketDiscount(int cents) => CheckoutDraft(
        lines: lines,
        client: client,
        ticketDiscountCents: _clampTicketDiscount(cents, preTicketTotalCents),
      );
}
