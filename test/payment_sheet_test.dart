import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/checkout_controller.dart';
import 'package:rosea_pos/features/checkout/domain/checkout_draft.dart';
import 'package:rosea_pos/features/checkout/domain/payment_draft.dart';
import 'package:rosea_pos/features/checkout/payment_controller.dart';
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

/// A ticket of only 10.00.
class _SmallDraft extends CheckoutDraftController {
  @override
  CheckoutDraft build() => const CheckoutDraft(lines: [
        DraftLine(
          id: 'l1',
          refId: 'svc1',
          kind: CatalogKind.service,
          name: 'Cut',
          unitPriceCents: 1000,
          qty: 1,
          lineDiscountCents: 0,
          performerStaffId: 'st1',
          performerName: 'Lea',
        ),
      ]);
}

/// Tenders of 50.00 already composed (more than the 10.00 ticket) — the stale state.
class _OverpaidPayments extends PaymentController {
  @override
  PaymentDraft build() => const PaymentDraft(
        payments: [Payment(id: 'p1', method: PaymentMethod.cash, appliedCents: 5000)],
      );
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

  testWidgets('guards against stale tenders that exceed a reduced total', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        checkoutDraftProvider.overrideWith(_SmallDraft.new), // total 10.00
        paymentDraftProvider.overrideWith(_OverpaidPayments.new), // 50.00 tendered
      ],
      child: const MaterialApp(home: Scaffold(body: PaymentSheet())),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('now exceed the ticket total'), findsOneWidget);
    await tester.tap(find.text('Clear tenders & re-enter'));
    await tester.pumpAndSettle();

    // tenders cleared -> back to needing the full 10.00
    expect(find.text('Add 10.00 to settle'), findsOneWidget);
  });
}
