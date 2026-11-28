import 'package:flutter/foundation.dart';

/// One staff member's line in the owner cash-up (net of any reversals).
@immutable
class StaffRow {
  const StaffRow({
    required this.name,
    required this.ratePercent,
    required this.servicesCount,
    required this.servicesCents,
    required this.productsCents,
    required this.commissionCents,
  });

  final String name;

  /// The staff member's configured services commission rate, as a percent.
  final num ratePercent;
  final int servicesCount;
  final int servicesCents;
  final int productsCents;
  final int commissionCents;

  static StaffRow fromJson(Map<String, dynamic> j) => StaffRow(
        name: (j['name'] as String?) ?? '',
        ratePercent: (j['rate'] as num?) ?? 0,
        servicesCount: (j['services_count'] as num?)?.toInt() ?? 0,
        servicesCents: (j['services_cents'] as num?)?.toInt() ?? 0,
        productsCents: (j['products_cents'] as num?)?.toInt() ?? 0,
        commissionCents: (j['commission_cents'] as num?)?.toInt() ?? 0,
      );
}

/// The owner cash-up read-out for a date range, as returned by the `cashup` RPC. All
/// figures are NET integer cents (a voided sale writes negative rows, which the server
/// SUMs net), and the per-staff rate is included (owner-only, from the RPC).
@immutable
class CashUp {
  const CashUp({
    required this.currency,
    required this.takingsByMethod,
    required this.tipTotalCents,
    required this.ticketCount,
    required this.avgTicketCents,
    required this.byStaff,
  });

  /// Salon currency code (e.g. 'USD'); '' when unset.
  final String currency;

  /// Net takings per payment method ('cash'/'card'/'other'); zero-net methods dropped.
  final Map<String, int> takingsByMethod;
  final int tipTotalCents;

  /// Paid tickets closed in the range, and their average total (cents).
  final int ticketCount;
  final int avgTicketCents;

  /// Per staff, highest commission first.
  final List<StaffRow> byStaff;

  int get totalCommissionCents => byStaff.fold(0, (s, r) => s + r.commissionCents);
  int get grossTakingsCents => takingsByMethod.values.fold(0, (s, v) => s + v);

  bool get isEmpty =>
      byStaff.isEmpty && takingsByMethod.isEmpty && tipTotalCents == 0 && ticketCount == 0;

  /// Parse the `cashup` RPC payload (all amounts already integer cents).
  static CashUp fromRpc(Map<String, dynamic> j) {
    final methods = <String, int>{};
    final tbm = j['takings_by_method'];
    if (tbm is Map) {
      tbm.forEach((k, v) {
        final cents = (v as num?)?.toInt() ?? 0;
        if (cents != 0) methods['$k'] = cents;
      });
    }
    final staff = <StaffRow>[
      for (final s in (j['by_staff'] as List<dynamic>? ?? const <dynamic>[]))
        StaffRow.fromJson(Map<String, dynamic>.from(s as Map)),
    ]..sort((a, b) => b.commissionCents.compareTo(a.commissionCents));

    return CashUp(
      currency: (j['currency'] as String?) ?? '',
      takingsByMethod: methods,
      tipTotalCents: (j['tip_total'] as num?)?.toInt() ?? 0,
      ticketCount: (j['ticket_count'] as num?)?.toInt() ?? 0,
      avgTicketCents: (j['avg_ticket'] as num?)?.toInt() ?? 0,
      byStaff: staff,
    );
  }
}
