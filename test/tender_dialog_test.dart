import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/checkout/domain/payment_draft.dart';
import 'package:rosea_pos/features/checkout/ui/tender_dialog.dart';

/// Pump a button that opens the tender dialog and records its result.
Future<void> _open(WidgetTester tester, PaymentMethod method, int remaining,
    {required void Function(int?) onResult}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () async =>
                onResult(await showTenderDialog(ctx, method: method, remainingCents: remaining)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cash: prefilled exact settles, overpay shows change, returns tendered',
      (tester) async {
    int? result;
    var returned = false;
    await _open(tester, PaymentMethod.cash, 7900, onResult: (v) {
      result = v;
      returned = true;
    });

    // Prefilled with the remaining → exact settle, no change.
    expect(find.text('Settles the ticket'), findsOneWidget);
    expect(find.text('Add 79.00'), findsOneWidget);

    // Overpay → change shown, button updates.
    await tester.enterText(find.byType(TextField), '100.00');
    await tester.pumpAndSettle();
    expect(find.text('Settles the ticket · change 21.00'), findsOneWidget);

    await tester.tap(find.text('Add 100.00'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, 10000); // tendered cents (caller caps the applied amount)
  });

  testWidgets('card: partial amount reports what remains', (tester) async {
    int? result;
    await _open(tester, PaymentMethod.card, 7900, onResult: (v) => result = v);

    expect(find.text('Card'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '50.00');
    await tester.pumpAndSettle();
    expect(find.text('Adds 50.00 · 29.00 remaining'), findsOneWidget);

    await tester.tap(find.text('Add 50.00'));
    await tester.pumpAndSettle();
    expect(result, 5000);
  });

  testWidgets('card: overpay caps at the remaining and says so', (tester) async {
    int? result;
    await _open(tester, PaymentMethod.card, 7900, onResult: (v) => result = v);

    await tester.enterText(find.byType(TextField), '100.00');
    await tester.pumpAndSettle();
    // Card can't exceed the remaining — the preview + button show the capped amount,
    // not the entered 100.00.
    expect(find.textContaining('only 79.00 charged'), findsOneWidget);
    expect(find.text('Add 79.00'), findsOneWidget);
    expect(find.text('Add 100.00'), findsNothing);

    await tester.tap(find.text('Add 79.00'));
    await tester.pumpAndSettle();
    expect(result, 7900); // capped at the remaining, not 10000
  });

  testWidgets('cancel returns null', (tester) async {
    int? result;
    var returned = false;
    await _open(tester, PaymentMethod.other, 5000, onResult: (v) {
      result = v;
      returned = true;
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, isNull);
  });
}
