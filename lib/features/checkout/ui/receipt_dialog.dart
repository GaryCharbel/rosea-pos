import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../domain/receipt.dart';

const _panel = Color(0xFF141019);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _green = Color(0xFF3ECF8E);
const _line = Color(0xFF2E2333);

/// Shows the paid receipt returned by pay_ticket: the on-screen confirmation of the
/// sale. (No printing — invoices/receipts surface for the customer in the dashboard.)
class ReceiptDialog extends StatelessWidget {
  const ReceiptDialog({
    super.key,
    required this.receipt,
    required this.onDone,
    this.changeGivenCents = 0,
  });

  final Receipt receipt;
  final VoidCallback onDone;

  /// Cash handed back (display-only, from the tender draft — the server records only
  /// the applied amounts). Shown as "Change given" when positive.
  final int changeGivenCents;

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
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(alpha: 0.12),
                      border: Border.all(color: _green, width: 2),
                    ),
                    child: const Icon(Icons.check, color: _green, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text('Paid · ${_money(receipt.totalCents)}',
                      style: const TextStyle(
                          color: _ink, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    receipt.ticketNo != null
                        ? '${receipt.salonName} · #${receipt.ticketNo}'
                        : receipt.salonName,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
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
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('PAYMENTS',
                        style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0)),
                  ),
                  for (final p in receipt.payments)
                    _totalRow(_methodLabel(p.method), p.amountCents),
                  if (changeGivenCents > 0)
                    _totalRow('Change given', changeGivenCents, color: _green),
                  // Per-staff tips (the server breaks them out) — hidden entirely when
                  // there were none, instead of showing a 0.00 line.
                  if (receipt.tips.isNotEmpty)
                    for (final t in receipt.tips)
                      _totalRow(t.staffName.isEmpty ? 'Tip' : 'Tip · ${t.staffName}',
                          t.amountCents, muted: true)
                  else if (receipt.tipTotalCents > 0)
                    _totalRow('Tip', receipt.tipTotalCents, muted: true),
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
                Text.rich(
                  TextSpan(
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
                    children: <InlineSpan>[
                      TextSpan(text: '$qtyLabel${l.name}'),
                      if (l.lineDiscountCents > 0)
                        TextSpan(
                          text: '  · −${_money(l.lineDiscountCents)}',
                          style: const TextStyle(
                              color: _pink, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
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

  Widget _totalRow(String label, int cents,
      {bool bold = false, bool muted = false, Color? color}) {
    final style = TextStyle(
      color: color ?? (muted ? _muted : _ink),
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
