import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../auth/session_controller.dart';
import '../cashup_repo.dart';
import '../domain/cashup.dart';

const _bg = Color(0xFF0C0A0F);
const _card = Color(0xFF1A141F);
const _card2 = Color(0xFF211826);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _gold = Color(0xFFC9A24B);
const _line = Color(0xFF2E2333);

/// Owner-only read-out (§8.6): net takings per method + tips (cash-up) and commission
/// per staff for a date range. Reconcile payroll and the till. No export yet.
class CashUpScreen extends ConsumerWidget {
  const CashUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isOwner = session is Authenticated && session.isOwner;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        title: const Text('Cash-up & commission',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: !isOwner
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('This read-out is for the salon owner.',
                    textAlign: TextAlign.center, style: TextStyle(color: _muted)),
              ),
            )
          : Column(
              children: <Widget>[
                _RangeBar(),
                const Divider(height: 1, color: _line),
                Expanded(
                  child: ref.watch(cashUpProvider).when(
                        loading: () => const Center(child: CircularProgressIndicator(color: _pink)),
                        error: (Object e, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Text(
                                  "Couldn't load the read-out. Check your connection and try again.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _muted),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () => ref.invalidate(cashUpProvider),
                                  style: FilledButton.styleFrom(backgroundColor: _pink),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        data: (CashUp c) => c.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('No sales in this range yet.',
                                      style: TextStyle(color: _muted)),
                                ),
                              )
                            : _Body(cashUp: c),
                      ),
                ),
              ],
            ),
    );
  }
}

class _RangeBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(cashUpRangeProvider);
    final label = _label(range);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.calendar_today, size: 16, color: _muted),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton(
            onPressed: () => _pick(context, ref, range),
            child: const Text('Change', style: TextStyle(color: _pink, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  String _label(CashUpRange r) {
    final lastDay = r.to.subtract(const Duration(days: 1));
    String d(DateTime x) => '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    return d(r.from) == d(lastDay) ? d(r.from) : '${d(r.from)} → ${d(lastDay)}';
  }

  // Cap the window so the read-out never pulls an unbounded number of ledger rows to
  // the client (the aggregation is client-side; a server-side SUM would lift this).
  static const int _maxDays = 92;

  Future<void> _pick(BuildContext context, WidgetRef ref, CashUpRange current) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDateRange: DateTimeRange(
          start: current.from, end: current.to.subtract(const Duration(days: 1))),
    );
    if (picked == null || !context.mounted) return;
    if (picked.end.difference(picked.start).inDays >= _maxDays) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          backgroundColor: _card,
          content: Text('Pick a range up to 3 months. For longer spans, use the dashboard (later).',
              style: TextStyle(color: _ink)),
        ));
      return;
    }
    final from = DateTime(picked.start.year, picked.start.month, picked.start.day);
    final to = DateTime(picked.end.year, picked.end.month, picked.end.day)
        .add(const Duration(days: 1)); // inclusive end day
    ref.read(cashUpRangeProvider.notifier).state = (from: from, to: to);
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.cashUp});
  final CashUp cashUp;

  @override
  Widget build(BuildContext context) {
    final cur = cashUp.currency;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _kpiRow(cashUp),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '${cashUp.ticketCount} ${cashUp.ticketCount == 1 ? 'ticket' : 'tickets'}'
            '${cashUp.ticketCount > 0 ? ' · avg ${formatCents(cashUp.avgTicketCents, currency: cur)}' : ''}',
            style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('TAKINGS BY METHOD'),
        if (cashUp.takingsByMethod.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('—', style: TextStyle(color: _muted)),
          )
        else ...<Widget>[
          for (final e in cashUp.takingsByMethod.entries) _methodRow(e.key, e.value),
          const SizedBox(height: 12),
          _TakingsBar(byMethod: cashUp.takingsByMethod),
        ],
        const SizedBox(height: 18),
        _sectionLabel('COMMISSION BY STAFF'),
        if (cashUp.byStaff.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('—', style: TextStyle(color: _muted)),
          )
        else
          for (final s in cashUp.byStaff) _staffRow(s, cur),
        const Divider(height: 24, color: _line),
        _row('Total commission', cashUp.totalCommissionCents, bold: true),
      ],
    );
  }

  /// The three KPI cards — stacked on phones, side by side on wider screens (p.8).
  Widget _kpiRow(CashUp c) {
    final cards = <Widget>[
      _kpi('Gross takings', c.grossTakingsCents, accent: _ink),
      _kpi('Tips', c.tipTotalCents, accent: _gold),
      _kpi('Total commission', c.totalCommissionCents, accent: _pink, highlight: true),
    ];
    return LayoutBuilder(
      builder: (context, cons) {
        if (cons.maxWidth >= 560) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
              ],
            ),
          );
        }
        return Column(
          children: <Widget>[
            cards[0],
            const SizedBox(height: 12),
            cards[1],
            const SizedBox(height: 12),
            cards[2],
          ],
        );
      },
    );
  }

  Widget _kpi(String label, int cents, {required Color accent, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_card2, _card]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? _pink : _line, width: highlight ? 1.5 : 1),
        boxShadow: <BoxShadow>[
          highlight
              ? BoxShadow(
                  color: _pink.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))
              : const BoxShadow(color: Colors.black, blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(),
              style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Text(formatCents(cents, currency: cashUp.currency),
              style: TextStyle(color: accent, fontSize: 28, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );

  Widget _row(String label, int cents, {bool bold = false}) {
    final style = TextStyle(
        color: _ink, fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: style),
          Text(formatCents(cents, currency: cashUp.currency), style: style),
        ],
      ),
    );
  }

  /// A per-staff cash-up line: name + "rate% · N services · services total" and the
  /// net commission on the right.
  Widget _staffRow(StaffRow s, String currency) {
    final rate = s.ratePercent == s.ratePercent.roundToDouble()
        ? s.ratePercent.toStringAsFixed(0)
        : s.ratePercent.toStringAsFixed(1);
    final svc = '${s.servicesCount} ${s.servicesCount == 1 ? 'service' : 'services'}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.name,
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text('$rate% · $svc · ${formatCents(s.servicesCents, currency: currency)}',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatCents(s.commissionCents, currency: currency),
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _methodRow(String wire, int cents) {
    final icon = switch (wire) {
      'cash' => Icons.payments_outlined,
      'card' => Icons.credit_card_outlined,
      _ => Icons.add_circle_outline,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: _pink),
          ),
          const SizedBox(width: 12),
          Text(_methodLabel(wire),
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          Text(formatCents(cents, currency: cashUp.currency),
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }

  String _methodLabel(String wire) =>
      switch (wire) { 'cash' => 'Cash', 'card' => 'Card', _ => 'Other' };
}

/// Proportional split of takings across methods (p.8, bottom-left bar).
class _TakingsBar extends StatelessWidget {
  const _TakingsBar({required this.byMethod});
  final Map<String, int> byMethod;

  static const Map<String, Color> _colors = <String, Color>{
    'cash': _pink,
    'card': Color(0xFF7A3B52),
    'other': _gold,
  };

  @override
  Widget build(BuildContext context) {
    // Size each segment against the sum of the shown method amounts so the bar is
    // always proportional (a separate gross figure could differ and skew it).
    final total = byMethod.values.fold<int>(0, (s, v) => s + v);
    if (total <= 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: <Widget>[
            for (final e in byMethod.entries)
              if (e.value > 0)
                Expanded(
                  flex: (e.value / total * 1000).round().clamp(1, 1000),
                  child: Container(color: _colors[e.key] ?? _gold),
                ),
          ],
        ),
      ),
    );
  }
}
