import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/money/money.dart';

const _panel = Color(0xFF141019);
const _field = Color(0xFF0C0A0F);
const _card = Color(0xFF1A141F);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _line = Color(0xFF2E2333);

enum _Mode { amount, percent }

/// Line-discount editor with an Amount $ / Percent % toggle and a live "Line becomes"
/// preview (p.11). Percent resolves to cents client-side, clamped to [0, gross] (the
/// server stores the cents amount, so the contract is unchanged). Returns the new
/// discount in cents (0 = removed), or null if cancelled.
Future<int?> showLineDiscountDialog(
  BuildContext context, {
  required String lineName,
  required int grossCents,
  required int currentDiscountCents,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _DiscountDialog(
      lineName: lineName,
      grossCents: grossCents,
      currentDiscountCents: currentDiscountCents,
    ),
  );
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({
    required this.lineName,
    required this.grossCents,
    required this.currentDiscountCents,
  });
  final String lineName;
  final int grossCents;
  final int currentDiscountCents;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  _Mode _mode = _Mode.amount;
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentDiscountCents > 0
        ? centsToDecimalString(widget.currentDiscountCents)
        : '',
  );

  int _clamp(int cents) => cents < 0 ? 0 : (cents > widget.grossCents ? widget.grossCents : cents);

  /// The discount the current field value resolves to, in cents.
  int _resolveCents() {
    if (_mode == _Mode.amount) return _clamp(centsFromServer(_controller.text));
    final pct = double.tryParse(_controller.text.trim()) ?? 0;
    return _clamp((widget.grossCents * pct / 100).round());
  }

  void _setMode(_Mode mode) {
    if (mode == _mode) return;
    // Convert the shown value so the discount stays equivalent across the toggle.
    final cents = _resolveCents();
    if (mode == _Mode.percent) {
      final pct = widget.grossCents > 0 ? cents / widget.grossCents * 100 : 0.0;
      _controller.text = pct <= 0
          ? ''
          : (pct == pct.roundToDouble() ? pct.round().toString() : pct.toStringAsFixed(1));
    } else {
      _controller.text = cents > 0 ? centsToDecimalString(cents) : '';
    }
    setState(() => _mode = mode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final becomes = widget.grossCents - _resolveCents();
    final isPercent = _mode == _Mode.percent;

    return Dialog(
      backgroundColor: _panel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Discount on ${widget.lineName}',
                  style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Line price ${formatCents(widget.grossCents)} · current discount '
                '−${formatCents(widget.currentDiscountCents)}',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  _modeChip('Amount \$', _Mode.amount),
                  const SizedBox(width: 10),
                  _modeChip('Percent %', _Mode.percent),
                ],
              ),
              const SizedBox(height: 16),
              Text(isPercent ? 'Discount percent' : 'Discount amount',
                  style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: isPercent
                    ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                    : moneyInputFormatters(),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: _ink, fontSize: 28, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  prefixText: isPercent ? null : '− \$ ',
                  prefixStyle:
                      const TextStyle(color: _muted, fontSize: 22, fontWeight: FontWeight.w700),
                  suffixText: isPercent ? ' %' : null,
                  suffixStyle:
                      const TextStyle(color: _muted, fontSize: 22, fontWeight: FontWeight.w700),
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
              Text('Line becomes ${formatCents(becomes)}',
                  style: const TextStyle(color: _muted, fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(0),
                  child: const Text('Remove discount',
                      style: TextStyle(color: _pink, fontWeight: FontWeight.w700)),
                ),
              ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(_resolveCents()),
                    child: const Text('Apply',
                        style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, _Mode mode) {
    final selected = _mode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _setMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A1420) : _card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _pink : _line, width: 1.4),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? _ink : _muted,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      ),
    );
  }
}
