import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../domain/receipt.dart';

const _panel = Color(0xFF141019);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _green = Color(0xFF3ECF8E);
const _line = Color(0xFF2E2333);

/// Shows the paid receipt returned by pay_ticket. (A printed 80mm PDF via `printing`
/// is a follow-up — §8.8; this is the on-screen confirmation the flow needs.)
class ReceiptDialog extends StatelessWidget {
  const ReceiptDialog({super.key, required this.receipt, required this.onDone});

  final Receipt receipt;
  final VoidCallback onDone;

  String _money(int cents) => formatCents(cents, currency: receipt.currency);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _panel,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                children: <Widget>[
                  const Icon(Icons.check_circle, color: _green, size: 40),
                  const SizedBox(height: 10),
                  Text(receipt.salonName,
                      style: const TextStyle(
                          color: _ink, fontSize: 20, fontWeight: FontWeight.w900)),
                  if (receipt.ticketNo != null)
                    Text('Receipt #${receipt.ticketNo}',
                        style: const TextStyle(color: _muted, fontSize: 13)),
                  if (receipt.receiptHeader != null && receipt.receiptHeader!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(receipt.receiptHeader!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  for (final l in receipt.lines) _lineRow(l),
                  const Divider(height: 20, color: _line),
                  _totalRow('Subtotal', receipt.subtotalCents, muted: true),
                  if (receipt.discountCents > 0) _totalRow('Discount', -receipt.discountCents, muted: true),
                  const SizedBox(height: 4),
                  _totalRow('Total', receipt.totalCents, bold: true),
                  const SizedBox(height: 10),
                  for (final p in receipt.payments) _totalRow(_methodLabel(p.method), p.amountCents, muted: true),
                  if (receipt.tipTotalCents > 0) ...<Widget>[
                    const SizedBox(height: 6),
                    for (final t in receipt.tips)
                      _totalRow('Tip · ${t.staffName}', t.amountCents, muted: true),
                  ],
                  if (receipt.receiptFooter != null && receipt.receiptFooter!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(receipt.receiptFooter!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: _pink, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: onDone,
                  child: const Text('Done — new ticket',
                      style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineRow(ReceiptLine l) {
    final qtyLabel = l.qty == 1 ? '' : '${l.qty.toString().replaceFirst(RegExp(r'\.0+$'), '')} × ';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$qtyLabel${l.name}',
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                if (l.performerName.isNotEmpty)
                  Text(l.performerName, style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
          Text(_money(l.lineTotalCents),
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _totalRow(String label, int cents, {bool bold = false, bool muted = false}) {
    final style = TextStyle(
      color: muted ? _muted : _ink,
      fontSize: bold ? 18 : 14,
      fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[Text(label, style: style), Text(_money(cents), style: style)],
      ),
    );
  }

  String _methodLabel(String wire) => switch (wire) {
        'cash' => 'Cash',
        'card' => 'Card',
        _ => 'Other',
      };
}
