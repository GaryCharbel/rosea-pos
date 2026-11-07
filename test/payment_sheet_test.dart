import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/checkout_controller.dart';
import 'package:rosea_pos/features/checkout/domain/checkout_draft.dart';
import 'package:rosea_pos/features/checkout/ui/payment_sheet.dart';

/// Seeds a ticket total of 50.00 (Cut ×1) so the sheet has something to settle.
class _SeededDraft extends CheckoutDraftController {
  @override
  CheckoutDraft build() => const CheckoutDraft(lines: [
        DraftLine(
          id: 'l1',
          refId: 'svc1',
          kind: CatalogKind.service,
          name: 'Cut',
          unitPriceCents: 5000,
          qty: 1,
          lineDiscountCents: 0,
          performerStaffId: 'st1',
          performerName: 'Lea',
        ),
      ]);
}

void main() {
  testWidgets('shows remaining and settles when an exact cash tender is added',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [checkoutDraftProvider.overrideWith(_SeededDraft.new)],
      child: const MaterialApp(home: Scaffold(body: PaymentSheet())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('50.00'), findsWidgets); // total + remaining
    expect(find.text('Add 50.00 to settle'), findsOneWidget); // footer before tender

    await tester.tap(find.text('Cash 50.00')); // exact-remaining quick-cash chip
    await tester.pumpAndSettle();

    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Take payment'), findsOneWidget); // enabled once settled
  });
}
