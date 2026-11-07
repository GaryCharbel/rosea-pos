import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../catalog/domain/catalog.dart';
import '../staff/staff_member.dart';
import 'domain/checkout_draft.dart';

/// Owns the in-progress ticket. All mutations are immutable rebuilds so the UI and
/// tests see clean transitions. Line money stays in integer cents.
class CheckoutDraftController extends Notifier<CheckoutDraft> {
  final Uuid _uuid = const Uuid();

  @override
  CheckoutDraft build() => const CheckoutDraft();

  /// Ring up a catalog item for [performer]. Tapping the same item again for the same
  /// performer (with no line discount) just bumps that line's qty, matching POS feel;
  /// a different performer makes a new line (performer-per-line invariant).
  void addItem(CatalogItem item, StaffMember performer) {
    final int existing = state.lines.indexWhere((l) =>
        l.refId == item.id &&
        l.kind == item.kind &&
        l.performerStaffId == performer.id &&
        l.lineDiscountCents == 0);

    if (existing != -1) {
      final line = state.lines[existing];
      _replaceAt(existing, line.copyWith(qty: line.qty + 1));
      return;
    }

    state = state.withLines(<DraftLine>[
      ...state.lines,
      DraftLine(
        id: _uuid.v4(),
        refId: item.id,
        kind: item.kind,
        name: item.name,
        unitPriceCents: item.priceCents,
        qty: 1,
        lineDiscountCents: 0,
        performerStaffId: performer.id,
        performerName: performer.name,
      ),
    ]);
  }

  void removeLine(String lineId) {
    state = state.withLines(state.lines.where((l) => l.id != lineId).toList());
  }

  /// Set the quantity; a qty of 0 or less removes the line. The line discount is
  /// re-clamped so it can never exceed the new gross.
  void setQty(String lineId, int qty) {
    if (qty <= 0) {
      removeLine(lineId);
      return;
    }
    _update(lineId, (l) {
      final gross = l.unitPriceCents * qty;
      return l.copyWith(
        qty: qty,
        lineDiscountCents: l.lineDiscountCents > gross ? gross : l.lineDiscountCents,
      );
    });
  }

  void increment(String lineId) => _update(lineId, (l) => l.copyWith(qty: l.qty + 1));
  void decrement(String lineId) {
    final line = state.lines.firstWhere((l) => l.id == lineId);
    setQty(lineId, line.qty - 1);
  }

  /// Clamp the per-line discount into [0, gross] (mirrors the server CHECK).
  void setLineDiscountCents(String lineId, int cents) {
    _update(lineId, (l) {
      final clamped = cents < 0 ? 0 : (cents > l.grossCents ? l.grossCents : cents);
      return l.copyWith(lineDiscountCents: clamped);
    });
  }

  void setLinePerformer(String lineId, StaffMember performer) {
    _update(lineId, (l) =>
        l.copyWith(performerStaffId: performer.id, performerName: performer.name));
  }

  void clear() => state = const CheckoutDraft();

  // ── helpers ──
  void _update(String lineId, DraftLine Function(DraftLine) f) {
    state = state.withLines(
      state.lines.map((l) => l.id == lineId ? f(l) : l).toList(),
    );
  }

  void _replaceAt(int index, DraftLine line) {
    final next = <DraftLine>[...state.lines];
    next[index] = line;
    state = state.withLines(next);
  }
}

final checkoutDraftProvider =
    NotifierProvider<CheckoutDraftController, CheckoutDraft>(CheckoutDraftController.new);
