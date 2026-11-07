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
                        error: (Object e, _) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              "Couldn't load the read-out. Check your connection and pull to refresh.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted),
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

  Future<void> _pick(BuildContext context, WidgetRef ref, CashUpRange current) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDateRange: DateTimeRange(
          start: current.from, end: current.to.subtract(const Duration(days: 1))),
    );
    if (picked != null) {
      final from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      final to = DateTime(picked.end.year, picked.end.month, picked.end.day)
          .add(const Duration(days: 1)); // inclusive end day
      ref.read(cashUpRangeProvider.notifier).state = (from: from, to: to);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.cashUp});
  final CashUp cashUp;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _kpi('Gross takings', cashUp.grossTakingsCents, accent: _pink)),
            const SizedBox(width: 12),
            Expanded(child: _kpi('Tips', cashUp.tipTotalCents, accent: _gold)),
          ],
        ),
        const SizedBox(height: 18),
        _sectionLabel('TAKINGS BY METHOD'),
        if (cashUp.takingsByMethod.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('—', style: TextStyle(color: _muted)),
          )
        else
          for (final e in cashUp.takingsByMethod.entries) _row(_methodLabel(e.key), e.value),
        const SizedBox(height: 18),
        _sectionLabel('COMMISSION BY STAFF'),
        for (final s in cashUp.commissionByStaff) _row(s.staffName, s.amountCents),
        const Divider(height: 24, color: _line),
        _row('Total commission', cashUp.totalCommissionCents, bold: true),
      ],
    );
  }

  Widget _kpi(String label, int cents, {required Color accent}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_card2, _card]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(),
              style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Text(formatCents(cents),
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
        children: <Widget>[Text(label, style: style), Text(formatCents(cents), style: style)],
      ),
    );
  }

  String _methodLabel(String wire) =>
      switch (wire) { 'cash' => 'Cash', 'card' => 'Card', _ => 'Other' };
}
