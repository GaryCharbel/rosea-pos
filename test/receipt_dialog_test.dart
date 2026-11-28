import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/checkout/domain/receipt.dart';
import 'package:rosea_pos/features/checkout/ui/receipt_dialog.dart';

Receipt _receipt() => const Receipt(
      ticketNo: 1047,
      status: 'paid',
      subtotalCents: 28900,
      discountCents: 1000,
      totalCents: 27900,
      salonName: 'Rosea Salon',
      currency: '',
      lines: <ReceiptLine>[
        ReceiptLine(name: "Women's cut", performerName: 'Maya Khoury', qty: 1, lineTotalCents: 4500),
        ReceiptLine(
            name: 'Balayage',
            performerName: 'Maya Khoury',
            qty: 1,
            lineTotalCents: 17000,
            lineDiscountCents: 1000),
      ],
      payments: <ReceiptPayment>[
        ReceiptPayment(method: 'card', amountCents: 20000),
        ReceiptPayment(method: 'cash', amountCents: 10000),
      ],
      tips: <ReceiptTip>[
        ReceiptTip(staffName: 'Maya Khoury', amountCents: 500),
      ],
      tipTotalCents: 500,
    );

void main() {
  testWidgets('renders the paid hero, per-line discount, change-given and tip',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReceiptDialog(
          receipt: _receipt(),
          changeGivenCents: 2100,
          onDone: () => done = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Paid hero + salon · #no subtitle.
    expect(find.text('Paid · 279.00'), findsOneWidget);
    expect(find.text('Rosea Salon · #1047'), findsOneWidget);

    // Per-line discount tag on the Balayage line.
    expect(find.textContaining('Balayage'), findsOneWidget);
    expect(find.textContaining('· −10.00'), findsOneWidget);

    // Payments section with change-given and a per-staff tip line (with its amount).
    expect(find.text('PAYMENTS'), findsOneWidget);
    expect(find.text('Change given'), findsOneWidget);
    expect(find.text('Tip · Maya Khoury'), findsOneWidget);
    expect(find.text('5.00'), findsOneWidget);

    await tester.tap(find.text('Done — new ticket'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('no change row when none was given', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReceiptDialog(receipt: _receipt(), onDone: () {})),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Change given'), findsNothing);
  });

  testWidgets('no tip row at all when there were no tips', (tester) async {
    const noTips = Receipt(
      ticketNo: 1,
      status: 'paid',
      subtotalCents: 4500,
      discountCents: 0,
      totalCents: 4500,
      salonName: 'Rosea',
      currency: '',
      lines: <ReceiptLine>[
        ReceiptLine(name: 'Cut', performerName: 'Lea', qty: 1, lineTotalCents: 4500),
      ],
      payments: <ReceiptPayment>[ReceiptPayment(method: 'cash', amountCents: 4500)],
      tips: <ReceiptTip>[],
      tipTotalCents: 0,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReceiptDialog(receipt: noTips, onDone: () {})),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tip'), findsNothing); // no 0.00 tip line
  });

  test('figures reconcile: subtotal−discount=total, payments−change=total, tips sum', () {
    final r = _receipt();
    expect(r.subtotalCents - r.discountCents, r.totalCents);
    final paid = r.payments.fold<int>(0, (s, p) => s + p.amountCents);
    const changeGiven = 2100; // card 200 + cash 100 − 21 change = 279 total
    expect(paid - changeGiven, r.totalCents);
    expect(r.tips.fold<int>(0, (s, t) => s + t.amountCents), r.tipTotalCents);
  });

  test('fromResult parses line_discount, defaulting a missing/null one to 0', () {
    final r = Receipt.fromResult(<String, dynamic>{
      'ticket_no': 5,
      'total': '170.00',
      'lines': <dynamic>[
        {'name': 'Balayage', 'line_total': '170.00', 'line_discount': '10.00', 'qty': 1},
        {'name': 'Cut', 'line_total': '45.00', 'qty': 1}, // no line_discount key
        {'name': 'Color', 'line_total': '80.00', 'line_discount': null, 'qty': 1},
      ],
    });
    expect(r.lines[0].lineDiscountCents, 1000);
    expect(r.lines[1].lineDiscountCents, 0);
    expect(r.lines[2].lineDiscountCents, 0);
  });
}
