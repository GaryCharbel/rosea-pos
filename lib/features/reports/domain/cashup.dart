import 'package:flutter/foundation.dart';

/// Commission earned by one staff member over the period (net of any reversals).
@immutable
class StaffCommission {
  const StaffCommission({required this.staffName, required this.amountCents});
  final String staffName;
  final int amountCents;
}

/// The owner cash-up + commission read-out for a date range. All figures are NET:
/// a voided sale writes negative payment/commission rows, so summing cancels them.
@immutable
class CashUp {
  const CashUp({
    required this.commissionByStaff,
    required this.takingsByMethod,
    required this.tipTotalCents,
  });

  /// Commission per staff, highest first (zero-net staff dropped).
  final List<StaffCommission> commissionByStaff;

  /// Net takings per payment method ('cash'/'card'/'other'), zero-net methods dropped.
  final Map<String, int> takingsByMethod;

  final int tipTotalCents;

  int get totalCommissionCents =>
      commissionByStaff.fold(0, (s, c) => s + c.amountCents);

  int get grossTakingsCents => takingsByMethod.values.fold(0, (s, v) => s + v);

  bool get isEmpty =>
      commissionByStaff.isEmpty && takingsByMethod.isEmpty && tipTotalCents == 0;
}

/// Aggregate raw ledger rows into the read-out. Pure (no DB) so it's fully unit-tested.
/// Inputs are already filtered to the period. `amountCents` values may be negative
/// (reversals / voids); summing nets them.
CashUp buildCashUp({
  required List<({String staffName, int amountCents})> commission,
  required List<({String method, int amountCents})> payments,
  required List<int> tipCents,
}) {
  final byStaff = <String, int>{};
  for (final c in commission) {
    byStaff[c.staffName] = (byStaff[c.staffName] ?? 0) + c.amountCents;
  }
  final staff = byStaff.entries
      .where((e) => e.value != 0)
      .map((e) => StaffCommission(staffName: e.key, amountCents: e.value))
      .toList()
    ..sort((a, b) => b.amountCents.compareTo(a.amountCents));

  final byMethod = <String, int>{};
  for (final p in payments) {
    byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amountCents;
  }
  byMethod.removeWhere((_, v) => v == 0);

  final tipTotal = tipCents.fold(0, (s, t) => s + t);

  return CashUp(commissionByStaff: staff, takingsByMethod: byMethod, tipTotalCents: tipTotal);
}
