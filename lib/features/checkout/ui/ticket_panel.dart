import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/money/money.dart';
import '../../staff/staff_member.dart';
import '../../staff/staff_repo.dart';
import '../checkout_controller.dart';
import '../domain/checkout_draft.dart';
import '../domain/pay_intent.dart';
import '../domain/payment_draft.dart';
import '../pay_controller.dart';
import '../payment_controller.dart';
import 'receipt_dialog.dart';

const _bg = Color(0xFF0C0A0F);
const _panel = Color(0xFF141019);
const _card = Color(0xFF1A141F);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _green = Color(0xFF3ECF8E);
const _line = Color(0xFF2E2333);

/// The right-hand ticket: lines (each credited to a performer) on top, and the payment
/// composer inline at the bottom — split tenders via Cash/Card/Other + quick-cash, with
/// live remaining/change, then Take payment → receipt. (No pop-up payment sheet.)
class TicketPanel extends ConsumerWidget {
  const TicketPanel({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(checkoutDraftProvider);
    final ctrl = ref.read(checkoutDraftProvider.notifier);

    ref.listen<PayState>(payControllerProvider, (_, next) => _onPayState(context, ref, next));

    return Container(
      color: _panel,
      child: Column(
        children: <Widget>[
          _header(context, ref, draft, ctrl),
          const Divider(height: 1, color: _line),
          Expanded(
            child: draft.isEmpty
                ? const _EmptyTicket()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: draft.lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _LineTile(line: draft.lines[i]),
                  ),
          ),
          const Divider(height: 1, color: _line),
          _PaymentArea(onClose: onClose),
        ],
      ),
    );
  }

  Widget _header(
      BuildContext context, WidgetRef ref, CheckoutDraft draft, CheckoutDraftController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        children: <Widget>[
          const Text('Ticket',
              style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('${draft.lineCount} ${draft.lineCount == 1 ? 'line' : 'lines'}',
              style: const TextStyle(color: _muted, fontSize: 13)),
          const Spacer(),
          if (!draft.isEmpty)
            TextButton(
              onPressed: () {
                ctrl.clear();
                ref.read(paymentDraftProvider.notifier).clear();
              },
              child: const Text('Clear', style: TextStyle(color: _muted)),
            ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: _muted),
              tooltip: 'Close',
            ),
        ],
      ),
    );
  }

  void _onPayState(BuildContext context, WidgetRef ref, PayState next) {
    void finishTicket() {
      ref.read(checkoutDraftProvider.notifier).clear();
      ref.read(paymentDraftProvider.notifier).clear();
      ref.read(payControllerProvider.notifier).reset();
    }

    switch (next) {
      case PaySuccess(:final receipt):
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => ReceiptDialog(
            receipt: receipt,
            onDone: () {
              Navigator.of(dialogCtx).pop();
              finishTicket();
              onClose?.call();
            },
          ),
        );
      case PayQueued(:final message):
        _toast(context, message);
        finishTicket();
        onClose?.call();
      case PayFailed(:final message):
        _toast(context, message);
        ref.read(payControllerProvider.notifier).reset();
      case PayIdle():
      case PaySending():
        break;
    }
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        backgroundColor: _card, content: Text(message, style: const TextStyle(color: _ink))));
}

/// The inline payment composer at the bottom of the ticket (scrolls if it gets tall).
class _PaymentArea extends ConsumerWidget {
  const _PaymentArea({this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(checkoutDraftProvider);
    final pay = ref.watch(paymentDraftProvider);
    final payState = ref.watch(payControllerProvider);
    final total = draft.totalCents;
    final remaining = pay.remainingCents(total);
    final settled = pay.isSettled(total);
    final overpaid = pay.paidCents > total;

    return Container(
      color: _bg,
      constraints: const BoxConstraints(maxHeight: 360),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _row('Subtotal', draft.subtotalCents, muted: true),
            if (draft.discountCents > 0) _row('Discount', -draft.discountCents, muted: true),
            const SizedBox(height: 4),
            _row('Total', total, big: true, color: _pink),
            if (!draft.isEmpty) ...<Widget>[
              const Divider(height: 18, color: _line),
              if (pay.changeCents > 0) _row('Change due', pay.changeCents, color: _green),
              if (pay.tipTotalCents > 0) _row('Tips', pay.tipTotalCents, muted: true),
              for (final p in pay.payments) _TenderRow(payment: p),
              if (overpaid)
                _note('Tenders exceed the total — the ticket changed. Clear and re-enter.')
              else if (remaining > 0) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Remaining ${formatCents(remaining)}',
                        style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                  for (final cents in _quickCash(remaining))
                    _chip(cents == remaining ? 'Cash ${formatCents(cents)}' : formatCents(cents),
                        () => ref.read(paymentDraftProvider.notifier).addCashTender(cents, remaining)),
                  _chip('Cash…', () => _promptThen(context, 'Cash tendered', remaining,
                      (c) => ref.read(paymentDraftProvider.notifier).addCashTender(c, remaining)),
                      outlined: true),
                  _chip('Card…', () => _promptThen(context, 'Card amount', remaining,
                      (c) => ref.read(paymentDraftProvider.notifier)
                          .addCardOrOther(PaymentMethod.card, c, remaining)),
                      outlined: true),
                  _chip('Other…', () => _promptThen(context, 'Other amount', remaining,
                      (c) => ref.read(paymentDraftProvider.notifier)
                          .addCardOrOther(PaymentMethod.other, c, remaining)),
                      outlined: true),
                ]),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addTip(context, ref),
                  icon: const Icon(Icons.add, size: 16, color: _pink),
                  label: const Text('Add tip',
                      style: TextStyle(color: _pink, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _pink,
                  disabledBackgroundColor: const Color(0xFF3A2430),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _footerAction(context, ref, draft, pay, settled, overpaid, payState),
                child: _footerChild(draft, remaining, settled, overpaid, payState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _footerAction(BuildContext context, WidgetRef ref, CheckoutDraft draft,
      PaymentDraft pay, bool settled, bool overpaid, PayState payState) {
    if (draft.isEmpty || payState is PaySending) return null;
    if (overpaid) return () => ref.read(paymentDraftProvider.notifier).clearPayments();
    if (settled) return () => _takePayment(context, ref);
    return null;
  }

  Widget _footerChild(
      CheckoutDraft draft, int remaining, bool settled, bool overpaid, PayState payState) {
    if (payState is PaySending) {
      return const SizedBox(
          height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _ink));
    }
    final text = draft.isEmpty
        ? 'Add items to take payment'
        : overpaid
            ? 'Clear tenders & re-enter'
            : settled
                ? 'Take payment'
                : 'Add ${formatCents(remaining)} to settle';
    return Text(text,
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16));
  }

  void _takePayment(BuildContext context, WidgetRef ref) {
    final draft = ref.read(checkoutDraftProvider);
    final pay = ref.read(paymentDraftProvider);
    final active = ref.read(activeStaffProvider);
    final AppError? problem =
        validatePayable(draft: draft, pay: pay, openedByStaffId: active?.id);
    if (problem != null) {
      _toast(context, problem.message);
      return;
    }
    final intent = PayIntent(
      clientTx: const Uuid().v4(),
      openedByStaffId: active!.id,
      totalCents: draft.totalCents,
      lines: <PayLine>[
        for (final l in draft.lines)
          PayLine(
            refId: l.refId,
            kind: l.kind,
            name: l.name,
            unitPriceCents: l.unitPriceCents,
            qty: l.qty,
            lineDiscountCents: l.lineDiscountCents,
            performerStaffId: l.performerStaffId,
          ),
      ],
      payments: <PayTender>[
        for (final p in pay.payments) PayTender(method: p.method, appliedCents: p.appliedCents),
      ],
      tips: <PayTip>[
        for (final t in pay.tips)
          PayTip(staffId: t.staffId, amountCents: t.amountCents, method: t.method),
      ],
    );
    ref.read(payControllerProvider.notifier).pay(intent);
  }

  Future<void> _promptThen(
      BuildContext context, String title, int defaultCents, void Function(int) apply) async {
    final entered = await _promptAmount(context, title, defaultCents);
    if (entered != null && entered > 0) apply(entered);
  }

  Future<void> _addTip(BuildContext context, WidgetRef ref) async {
    final staff = await _pickStaff(context, ref);
    if (staff == null || !context.mounted) return;
    final amount = await _promptAmount(context, 'Tip for ${staff.name}', 0);
    if (amount == null || amount <= 0) return;
    ref.read(paymentDraftProvider.notifier).addTip(staff, amount, PaymentMethod.cash);
  }

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

  Widget _row(String label, int cents, {bool big = false, bool muted = false, Color color = _ink}) {
    final style = TextStyle(
      color: big ? color : (muted ? _muted : _ink),
      fontSize: big ? 22 : 14,
      fontWeight: big ? FontWeight.w900 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: big ? const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800) : style),
          Text(formatCents(cents), style: style),
        ],
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(color: _muted, fontSize: 12.5)),
      );

  Widget _chip(String label, VoidCallback onTap, {bool outlined = false}) {
    return Material(
      color: outlined ? Colors.transparent : _card,
      shape: StadiumBorder(side: BorderSide(color: outlined ? _line : Colors.transparent)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(label,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
        ),
      ),
    );
  }

  Future<int?> _promptAmount(BuildContext context, String title, int defaultCents) {
    final controller = TextEditingController(
        text: defaultCents > 0 ? centsToDecimalString(defaultCents) : '');
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
              prefixText: '\$ ', prefixStyle: TextStyle(color: _muted)),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: _muted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _pink),
            onPressed: () => Navigator.of(ctx).pop(centsFromServer(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
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
                    textAlign: TextAlign.center, style: TextStyle(color: _muted))),
            data: (List<StaffMember> list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No active staff yet.',
                        textAlign: TextAlign.center, style: TextStyle(color: _muted)))
                : ListView(shrinkWrap: true, children: <Widget>[
                    for (final s in list)
                      ListTile(
                        leading: const Icon(Icons.person, color: _pink),
                        title: Text(s.name, style: const TextStyle(color: _ink)),
                        onTap: () => Navigator.of(ctx).pop(s),
                      ),
                  ]),
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
    return Row(
      children: <Widget>[
        const Icon(Icons.payments_outlined, size: 16, color: _muted),
        const SizedBox(width: 8),
        Expanded(child: Text('${payment.method.label}$change',
            style: const TextStyle(color: _ink, fontSize: 13))),
        Text(formatCents(payment.appliedCents),
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 13)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => ref.read(paymentDraftProvider.notifier).removePayment(payment.id),
          icon: const Icon(Icons.close, size: 16, color: _muted),
          tooltip: 'Remove tender',
        ),
      ],
    );
  }
}

class _EmptyTicket extends StatelessWidget {
  const _EmptyTicket();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Tap services or products to add them to the ticket.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
      ),
    );
  }
}

class _LineTile extends ConsumerWidget {
  const _LineTile({required this.line});
  final DraftLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(checkoutDraftProvider.notifier);
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(line.name,
                      style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Text(formatCents(line.lineTotalCents),
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ctrl.removeLine(line.id),
                  icon: const Icon(Icons.close, size: 18, color: _muted),
                  tooltip: 'Remove line',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Flexible(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _pickPerformer(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1420),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _pink.withValues(alpha: 0.5)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                        const Icon(Icons.person, size: 14, color: _pink),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(line.performerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _qtyStepper(ctrl),
              ],
            ),
            if (line.lineDiscountCents > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${formatCents(line.unitPriceCents)} × ${line.qty}  −${formatCents(line.lineDiscountCents)} discount',
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 30)),
                onPressed: () => _editDiscount(context, ref),
                child: Text(
                  line.lineDiscountCents > 0 ? 'Edit discount' : 'Add discount',
                  style: const TextStyle(color: _pink, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyStepper(CheckoutDraftController ctrl) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _stepBtn(Icons.remove, () => ctrl.decrement(line.id)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('${line.qty}',
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        _stepBtn(Icons.add, () => ctrl.increment(line.id)),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFF241A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: _ink),
      ),
    );
  }

  Future<void> _pickPerformer(BuildContext context, WidgetRef ref) async {
    final chosen = await showModalBottomSheet<StaffMember>(
      context: context,
      backgroundColor: _panel,
      builder: (ctx) => _PerformerSheet(currentId: line.performerStaffId),
    );
    if (chosen != null) {
      ref.read(checkoutDraftProvider.notifier).setLinePerformer(line.id, chosen);
    }
  }

  Future<void> _editDiscount(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: line.lineDiscountCents > 0 ? centsToDecimalString(line.lineDiscountCents) : '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Line discount', style: TextStyle(color: _ink)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: moneyInputFormatters(),
          style: const TextStyle(color: _ink),
          decoration: InputDecoration(
            prefixText: '− ',
            prefixStyle: const TextStyle(color: _muted),
            hintText: 'max ${formatCents(line.grossCents)}',
            hintStyle: const TextStyle(color: _muted),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(0),
            child: const Text('Remove', style: TextStyle(color: _muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _pink),
            onPressed: () => Navigator.of(ctx).pop(centsFromServer(controller.text)),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != null) {
      ref.read(checkoutDraftProvider.notifier).setLineDiscountCents(line.id, result);
    }
  }
}

class _PerformerSheet extends ConsumerWidget {
  const _PerformerSheet({required this.currentId});
  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffPublicProvider);
    return SafeArea(
      child: staff.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator(color: _pink)),
        ),
        error: (Object e, _) => const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Couldn't load the team. Check your connection and try again.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ),
        data: (List<StaffMember> list) {
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No active staff yet. Add them in the backoffice first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text('Who performed this?',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              for (final s in list)
                ListTile(
                  leading: const Icon(Icons.person, color: _pink),
                  title: Text(s.name, style: const TextStyle(color: _ink)),
                  trailing: s.id == currentId
                      ? const Icon(Icons.check_circle, color: _pink)
                      : null,
                  onTap: () => Navigator.of(context).pop(s),
                ),
            ],
          );
        },
      ),
    );
  }
}
