import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../staff/staff_member.dart';
import '../../staff/staff_repo.dart';
import '../checkout_controller.dart';
import '../domain/payment_draft.dart';
import '../payment_controller.dart';

const _bg = Color(0xFF0C0A0F);
const _panel = Color(0xFF141019);
const _card = Color(0xFF1A141F);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _green = Color(0xFF3ECF8E);
const _line = Color(0xFF2E2333);

/// Composes the split payment + tips for the ticket, with live remaining/change. The
/// actual pay_ticket call + receipt arrive in Phase 4.4 — here the tenders are recorded
/// locally and "Take payment" is enabled once the ticket is settled.
class PaymentSheet extends ConsumerWidget {
  const PaymentSheet({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(checkoutDraftProvider).totalCents;
    final pay = ref.watch(paymentDraftProvider);
    final remaining = pay.remainingCents(total);
    final settled = pay.isSettled(total);

    return Container(
      color: _panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _header(context),
          const Divider(height: 1, color: _line),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _summary(total, pay, remaining),
                const SizedBox(height: 16),
                if (pay.payments.isNotEmpty) ...<Widget>[
                  _sectionLabel('TENDERS'),
                  for (final p in pay.payments) _TenderRow(payment: p),
                  const SizedBox(height: 12),
                ],
                if (remaining > 0) ...<Widget>[
                  _sectionLabel('TAKE PAYMENT'),
                  _cashRow(context, ref, remaining),
                  const SizedBox(height: 8),
                  Row(children: <Widget>[
                    Expanded(child: _methodBtn(context, ref, PaymentMethod.card, remaining)),
                    const SizedBox(width: 8),
                    Expanded(child: _methodBtn(context, ref, PaymentMethod.other, remaining)),
                  ]),
                  const SizedBox(height: 12),
                ],
                _sectionLabel('TIPS'),
                for (final t in pay.tips) _TipRow(tip: t),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _addTip(context, ref),
                    icon: const Icon(Icons.add, size: 18, color: _pink),
                    label: const Text('Add tip',
                        style: TextStyle(color: _pink, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          _footer(context, settled, remaining),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Row(
          children: <Widget>[
            const Text('Payment',
                style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, color: _muted),
              tooltip: 'Close',
            ),
          ],
        ),
      );

  Widget _summary(int total, PaymentDraft pay, int remaining) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: <Widget>[
          _row('Total', formatCents(total), bold: true),
          if (pay.paidCents > 0) ...<Widget>[
            const SizedBox(height: 6),
            _row('Paid', formatCents(pay.paidCents), color: _muted),
          ],
          if (pay.changeCents > 0) ...<Widget>[
            const SizedBox(height: 6),
            _row('Change due', formatCents(pay.changeCents), color: _green),
          ],
          if (pay.tipTotalCents > 0) ...<Widget>[
            const SizedBox(height: 6),
            _row('Tips', formatCents(pay.tipTotalCents), color: _muted),
          ],
          const SizedBox(height: 10),
          _row(
            remaining > 0 ? 'Remaining' : 'Settled',
            remaining > 0 ? formatCents(remaining) : '✓',
            big: true,
            color: remaining > 0 ? _pink : _green,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, bool big = false, Color color = _ink}) {
    final size = big ? 22.0 : 15.0;
    final weight = big || bold ? FontWeight.w800 : FontWeight.w500;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: TextStyle(color: big ? color : _muted, fontSize: big ? 16 : 14)),
        Text(value, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: _muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );

  Widget _cashRow(BuildContext context, WidgetRef ref, int remaining) {
    final quick = _quickCash(remaining);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final cents in quick)
          _chip(
            cents == remaining ? 'Cash ${formatCents(cents)}' : formatCents(cents),
            () => ref.read(paymentDraftProvider.notifier).addCashTender(cents, remaining),
          ),
        _chip('Cash…', () async {
          final entered = await _promptAmount(context, 'Cash tendered', remaining);
          if (entered != null && entered > 0) {
            ref.read(paymentDraftProvider.notifier).addCashTender(entered, remaining);
          }
        }, outlined: true),
      ],
    );
  }

  Widget _methodBtn(BuildContext context, WidgetRef ref, PaymentMethod method, int remaining) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        side: const BorderSide(color: _line),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: () async {
        final entered = await _promptAmount(context, '${method.label} amount', remaining);
        if (entered != null && entered > 0) {
          ref.read(paymentDraftProvider.notifier).addCardOrOther(method, entered, remaining);
        }
      },
      child: Text(method.label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _chip(String label, VoidCallback onTap, {bool outlined = false}) {
    return Material(
      color: outlined ? Colors.transparent : _card,
      shape: StadiumBorder(side: BorderSide(color: outlined ? _line : Colors.transparent)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(label,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, bool settled, int remaining) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _pink,
            disabledBackgroundColor: const Color(0xFF3A2430),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: settled
              ? () {
                  // Pay flow (validate + pay_ticket + receipt) lands in Phase 4.4.
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                      backgroundColor: _card,
                      content: Text('Ready to charge — the pay step wires up next.',
                          style: TextStyle(color: _ink)),
                    ));
                }
              : null,
          child: Text(
            settled ? 'Take payment' : 'Add ${formatCents(remaining)} to settle',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ),
    );
  }

  /// Exact remaining + the next $5/$10/$20 round-ups (deduped), at most four chips.
  List<int> _quickCash(int remaining) {
    if (remaining <= 0) return const <int>[];
    final set = <int>{remaining};
    for (final step in <int>[500, 1000, 2000]) {
      final up = ((remaining + step - 1) ~/ step) * step;
      if (up > remaining) set.add(up);
    }
    final list = set.toList()..sort();
    return list.take(4).toList();
  }

  Future<int?> _promptAmount(BuildContext context, String title, int defaultCents) async {
    final controller = TextEditingController(text: centsToDecimalString(defaultCents));
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: Text(title, style: const TextStyle(color: _ink)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: moneyInputFormatters(),
          style: const TextStyle(color: _ink),
          decoration: const InputDecoration(
            prefixText: '\$ ',
            prefixStyle: TextStyle(color: _muted),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _pink),
            onPressed: () => Navigator.of(ctx).pop(centsFromServer(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTip(BuildContext context, WidgetRef ref) async {
    final staff = await _pickStaff(context, ref);
    if (staff == null || !context.mounted) return;
    final amount = await _promptAmount(context, 'Tip for ${staff.name}', 0);
    if (amount == null || amount <= 0) return;
    ref.read(paymentDraftProvider.notifier).addTip(staff, amount, PaymentMethod.cash);
  }

  Future<StaffMember?> _pickStaff(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<StaffMember>(
      context: context,
      backgroundColor: _panel,
      builder: (ctx) => Consumer(builder: (context, ref, _) {
        final staff = ref.watch(staffPublicProvider);
        return SafeArea(
          child: staff.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator(color: _pink))),
            error: (Object e, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text("Couldn't load the team. Check your connection and try again.",
                  textAlign: TextAlign.center, style: TextStyle(color: _muted)),
            ),
            data: (List<StaffMember> list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No active staff yet.',
                        textAlign: TextAlign.center, style: TextStyle(color: _muted)))
                : ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final s in list)
                        ListTile(
                          leading: const Icon(Icons.person, color: _pink),
                          title: Text(s.name, style: const TextStyle(color: _ink)),
                          onTap: () => Navigator.of(ctx).pop(s),
                        ),
                    ],
                  ),
          ),
        );
      }),
    );
  }
}

class _TenderRow extends ConsumerWidget {
  const _TenderRow({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final change = payment.changeCents > 0 ? '  (change ${formatCents(payment.changeCents)})' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.payments_outlined, size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${payment.method.label}$change',
                style: const TextStyle(color: _ink, fontSize: 14)),
          ),
          Text(formatCents(payment.appliedCents),
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(paymentDraftProvider.notifier).removePayment(payment.id),
            icon: const Icon(Icons.close, size: 18, color: _muted),
            tooltip: 'Remove tender',
          ),
        ],
      ),
    );
  }
}

class _TipRow extends ConsumerWidget {
  const _TipRow({required this.tip});
  final Tip tip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          const Icon(Icons.volunteer_activism_outlined, size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${tip.staffName} · ${tip.method.label}',
                style: const TextStyle(color: _ink, fontSize: 14)),
          ),
          Text(formatCents(tip.amountCents),
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(paymentDraftProvider.notifier).removeTip(tip.id),
            icon: const Icon(Icons.close, size: 18, color: _muted),
            tooltip: 'Remove tip',
          ),
        ],
      ),
    );
  }
}
