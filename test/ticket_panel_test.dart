import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/checkout_controller.dart';
import 'package:rosea_pos/features/checkout/domain/checkout_draft.dart';
import 'package:rosea_pos/features/checkout/ui/ticket_panel.dart';

/// Seeds one line (Cut ×2, Lea) so the panel has something to render.
class _Seeded extends CheckoutDraftController {
  @override
  CheckoutDraft build() => const CheckoutDraft(lines: [
        DraftLine(
          id: 'l1',
          refId: 'svc1',
          kind: CatalogKind.service,
          name: 'Cut',
          unitPriceCents: 5000,
          qty: 2,
          lineDiscountCents: 0,
          performerStaffId: 'st1',
          performerName: 'Lea',
        ),
      ]);
}

void main() {
  testWidgets('renders a line with performer + total, and remove empties the ticket',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [checkoutDraftProvider.overrideWith(_Seeded.new)],
      child: const MaterialApp(home: Scaffold(body: TicketPanel())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Lea'), findsOneWidget); // performer chip
    expect(find.text('2'), findsOneWidget); // qty
    expect(find.text('100.00'), findsWidgets); // line total + ticket total (5000×2)

    await tester.tap(find.byIcon(Icons.close)); // remove the line
    await tester.pumpAndSettle();

    expect(find.text('Cut'), findsNothing);
    expect(find.textContaining('Tap services or products'), findsOneWidget);
  });

  testWidgets('discount dialog rejects a malformed decimal and applies a valid one',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [checkoutDraftProvider.overrideWith(_Seeded.new)],
      child: const MaterialApp(home: Scaffold(body: TicketPanel())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('100.00'), findsWidgets); // Cut ×2 = 10000c

    // open the discount dialog and type a malformed value: the formatter rejects it,
    // so the field stays empty and Apply must not crash (regression for the HIGH).
    await tester.tap(find.text('Add discount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.2.3');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(find.text('100.00'), findsWidgets); // unchanged, no crash

    // a valid discount applies: 10000 − 1500 = 8500 -> 85.00
    await tester.tap(find.text('Add discount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '15.00');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    // line total + ticket total now read 85.00 (10000 − 1500); subtotal stays 100.00
    expect(find.text('85.00'), findsWidgets);
  });
}
