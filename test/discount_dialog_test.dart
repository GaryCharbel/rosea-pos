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
}
