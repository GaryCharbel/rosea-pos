import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../staff/staff_member.dart';
import '../../staff/staff_repo.dart';
import '../checkout_controller.dart';
import '../domain/checkout_draft.dart';

const _bg = Color(0xFF0C0A0F);
const _panel = Color(0xFF141019);
const _card = Color(0xFF1A141F);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _line = Color(0xFF2E2333);

/// The right-hand ticket: the lines being rung up, each credited to a performer, with
/// qty steppers, per-line discount, and the live running total. Pay lands in Phase 4.4.
class TicketPanel extends ConsumerWidget {
  const TicketPanel({super.key, this.onClose});

  /// Shown as a close affordance on narrow layouts (where the panel is a sheet/route).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(checkoutDraftProvider);
    final ctrl = ref.read(checkoutDraftProvider.notifier);

    return Container(
      color: _panel,
      child: Column(
        children: <Widget>[
          _header(context, draft, ctrl),
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
          _totals(context, draft),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, CheckoutDraft draft, CheckoutDraftController ctrl) {
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
              onPressed: ctrl.clear,
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

  Widget _totals(BuildContext context, CheckoutDraft draft) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: <Widget>[
          _totalRow('Subtotal', draft.subtotalCents, muted: true),
          if (draft.discountCents > 0) ...<Widget>[
            const SizedBox(height: 4),
            _totalRow('Discount', -draft.discountCents, muted: true),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Total',
                  style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(formatCents(draft.totalCents),
                  style: const TextStyle(color: _pink, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // Pay is wired in Phase 4.4 (validation + outbox + pay_ticket).
              onPressed: null,
              style: FilledButton.styleFrom(
                backgroundColor: _pink,
                disabledBackgroundColor: const Color(0xFF3A2430),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                draft.isEmpty ? 'Add items to take payment' : 'Pay (next step)',
                style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, int cents, {bool muted = false}) {
    final style = TextStyle(color: muted ? _muted : _ink, fontSize: 14);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[Text(label, style: style), Text(formatCents(cents), style: style)],
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
                      style: const TextStyle(
                          color: _ink, fontWeight: FontWeight.w700, fontSize: 15)),
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
                // performer chip — tap to reassign who is credited for this line
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
    // The sheet itself watches staff_public, so it shows a spinner while the list
    // loads (cold) and actionable copy if it can't load — instead of silently
    // reading a not-yet-loaded value.
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
          inputFormatters: <TextInputFormatter>[
            // Reject any edit that isn't a clean decimal (one dot, <=2 fraction digits)
            // so the money codec never sees "1.2.3" and throws on Apply.
            TextInputFormatter.withFunction((oldValue, newValue) {
              final t = newValue.text;
              if (t.isEmpty) return newValue;
              return RegExp(r'^\d*\.?\d{0,2}$').hasMatch(t) ? newValue : oldValue;
            }),
          ],
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

/// Performer chooser for a line. Watches staff_public so it shows a spinner while
/// loading and actionable copy if it can't load; returns the chosen staff via pop.
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
