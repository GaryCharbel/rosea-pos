import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/checkout/ui/discount_dialog.dart';

Future<void> _open(WidgetTester tester,
    {required int gross, int current = 0, required void Function(int?) onResult}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () async => onResult(await showLineDiscountDialog(ctx,
                lineName: 'Balayage', grossCents: gross, currentDiscountCents: current)),
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
  testWidgets('amount mode: resolves to cents with a live "Line becomes"', (tester) async {
    int? result;
    await _open(tester, gross: 10000, onResult: (v) => result = v);

    expect(find.text('Discount on Balayage'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '15.00');
    await tester.pumpAndSettle();
    expect(find.text('Line becomes 85.00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(result, 1500);
  });

  testWidgets('percent mode: 10% off 100.00 becomes 90.00 and resolves to 1000c',
      (tester) async {
    int? result;
    await _open(tester, gross: 10000, onResult: (v) => result = v);

    await tester.tap(find.text('Percent %'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10');
    await tester.pumpAndSettle();
    expect(find.text('Line becomes 90.00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(result, 1000);
  });

  testWidgets('percent over 100 clamps to the line (free line)', (tester) async {
    int? result;
    await _open(tester, gross: 10000, onResult: (v) => result = v);
    await tester.tap(find.text('Percent %'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '150');
    await tester.pumpAndSettle();
    expect(find.text('Line becomes 0.00'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(result, 10000);
  });

  testWidgets('toggling Amount→Percent keeps the value equivalent', (tester) async {
    await _open(tester, gross: 10000, onResult: (_) {});
    await tester.enterText(find.byType(TextField), '25.00'); // 25.00 off 100.00 = 25%
    await tester.pumpAndSettle();
    await tester.tap(find.text('Percent %'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '25');
    expect(find.text('Line becomes 75.00'), findsOneWidget);
  });

  testWidgets('remove returns 0, cancel returns null', (tester) async {
    int? removeResult;
    await _open(tester, gross: 10000, current: 1000, onResult: (v) => removeResult = v);
    await tester.tap(find.text('Remove discount'));
    await tester.pumpAndSettle();
    expect(removeResult, 0);

    int? cancelResult = -1;
    await _open(tester, gross: 10000, current: 1000, onResult: (v) => cancelResult = v);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cancelResult, isNull);
  });

  testWidgets('toggling Amount→Percent does not change the applied discount', (tester) async {
    int? result;
    await _open(tester, gross: 10000, onResult: (v) => result = v);
    await tester.enterText(find.byType(TextField), '33.33'); // 33.33 off 100.00
    await tester.pumpAndSettle();
    await tester.tap(find.text('Percent %'));
    await tester.pumpAndSettle();
    // Shows the equivalent percent, and Apply keeps the exact cents (used to drop to 3330).
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '33.33');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(result, 3333);
  });

  testWidgets('100% off makes the line free (exactly gross)', (tester) async {
    int? result;
    await _open(tester, gross: 12345, onResult: (v) => result = v);
    await tester.tap(find.text('Percent %'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.pumpAndSettle();
    expect(find.text('Line becomes 0.00'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(result, 12345);
  });

  testWidgets('percent rounds half-up with integer math', (tester) async {
    int? result;
    await _open(tester, gross: 333, onResult: (v) => result = v); // 333 * 50% = 166.5 -> 167
    await tester.tap(find.text('Percent %'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '50');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(result, 167);
  });

  testWidgets('percent rejects a malformed value instead of applying something bogus',
      (tester) async {
    await _open(tester, gross: 10000, onResult: (_) {});
    await tester.tap(find.text('Percent %'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.2.3');
    await tester.pump();
    final text = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(text.split('.').length > 2, isFalse); // never a second dot
    expect(find.text('Line becomes 100.00'), findsOneWidget); // no discount applied
  });

  testWidgets('opens with the current discount pre-filled and keeps it on Apply',
      (tester) async {
    int? result;
    await _open(tester, gross: 10000, current: 2000, onResult: (v) => result = v);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '20.00');
    expect(find.text('Line becomes 80.00'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(result, 2000);
  });

  testWidgets('an oversized amount does not crash the dialog', (tester) async {
    await _open(tester, gross: 10000, onResult: (_) {});
    await tester.enterText(find.byType(TextField), '9' * 30);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
