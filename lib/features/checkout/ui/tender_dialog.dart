import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../domain/payment_draft.dart';

const _panel = Color(0xFF141019);
const _field = Color(0xFF0C0A0F);
const _card = Color(0xFF1A141F);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _green = Color(0xFF3ECF8E);
const _amber = Color(0xFFE7A93B);
const _line = Color(0xFF2E2333);

IconData _iconFor(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => Icons.payments_outlined,
      PaymentMethod.card => Icons.credit_card_outlined,
      PaymentMethod.other => Icons.more_horiz,
    };

/// Collects a tender amount for [method] with a live "settles / change / remaining"
/// preview (p.10). Returns the entered cents, or null if cancelled. The caller applies
/// it (cash gives change; card/other cap at the remaining).
Future<int?> showTenderDialog(
  BuildContext context, {
  required PaymentMethod method,
  required int remainingCents,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _TenderDialog(method: method, remainingCents: remainingCents),
  );
}

class _TenderDialog extends StatefulWidget {
  const _TenderDialog({required this.method, required this.remainingCents});
  final PaymentMethod method;
  final int remainingCents;

  @override
  State<_TenderDialog> createState() => _TenderDialogState();
}

class _TenderDialogState extends State<_TenderDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: centsToDecimalString(widget.remainingCents));

  int get _entered => centsFromServer(_controller.text);

  List<int> _quick() {
    final r = widget.remainingCents;
    if (r <= 0) return const <int>[];
    // Card/Other can't exceed the remaining, so round-ups above it are misleading.
    if (widget.method != PaymentMethod.cash) return <int>[r];
    final set = <int>{r};
    for (final step in <int>[500, 1000, 2000]) {
      final up = ((r + step - 1) ~/ step) * step;
      if (up > r) set.add(up);
    }
    return (set.toList()..sort()).take(3).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entered = _entered;
    final remaining = widget.remainingCents;
    final isCash = widget.method == PaymentMethod.cash;
    // Card/Other can't exceed the remaining — the applied amount caps there (the
    // PaymentController enforces the same). Cash may exceed and gives change.
    final applied = isCash ? entered : (entered > remaining ? remaining : entered);
    final settles = applied >= remaining;
    final change = (isCash && entered > remaining) ? entered - remaining : 0;
    final capped = !isCash && entered > remaining;

    final (String previewText, Color previewColor) = entered <= 0
        ? ('Enter an amount to add.', _muted)
        : settles
            ? capped
                ? ('Settles the ticket · only ${formatCents(remaining)} charged', _green)
                : change > 0
                    ? ('Settles the ticket · change ${formatCents(change)}', _green)
                    : ('Settles the ticket', _green)
            : ('Adds ${formatCents(applied)} · ${formatCents(remaining - applied)} remaining', _muted);

    return Dialog(
      backgroundColor: _panel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.method.label,
                            style: const TextStyle(
                                color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(color: _muted, fontSize: 13),
                            children: <InlineSpan>[
                              const TextSpan(text: 'Remaining on ticket: '),
                              TextSpan(
                                text: formatCents(remaining),
                                style: const TextStyle(
                                    color: _amber, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _card, borderRadius: BorderRadius.circular(12)),
                    child: Icon(_iconFor(widget.method), color: _pink),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Amount', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: moneyInputFormatters(),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: _ink, fontSize: 30, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(color: _muted, fontSize: 24, fontWeight: FontWeight.w700),
                  filled: true,
                  fillColor: _field,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _pink, width: 1.6)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  if (settles && entered > 0)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.check, size: 16, color: _green),
                    ),
                  Expanded(
                    child: Text(previewText,
                        style: TextStyle(
                            color: previewColor, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final c in _quick())
                    _chip(formatCents(c), () {
                      _controller.text = centsToDecimalString(c);
                      setState(() {});
                    }),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: _muted)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _pink,
                      disabledBackgroundColor: const Color(0xFF3A2430),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: entered > 0 ? _submit : null,
                    child: Text(entered > 0 ? 'Add ${formatCents(applied)}' : 'Add',
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final v = _entered;
    if (v <= 0) return;
    // Card/Other cap at the remaining; cash may exceed (the caller gives change).
    final out = widget.method == PaymentMethod.cash
        ? v
        : (v > widget.remainingCents ? widget.remainingCents : v);
    Navigator.of(context).pop(out);
  }

  Widget _chip(String label, VoidCallback onTap) {
    return Material(
      color: _card,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(label,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ),
    );
  }
}
