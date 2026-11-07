import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/domain/checkout_draft.dart';

DraftLine _line(String id, int unit, int qty, int disc) => DraftLine(
      id: id,
      refId: 'r$id',
      kind: CatalogKind.service,
      name: 'L$id',
      unitPriceCents: unit,
      qty: qty,
      lineDiscountCents: disc,
      performerStaffId: 'p1',
      performerName: 'P1',
    );

void main() {
  group('DraftLine', () {
    test('gross = unit × qty; lineTotal = gross − discount', () {
      final l = _line('1', 5000, 3, 1000);
      expect(l.grossCents, 15000);
      expect(l.lineTotalCents, 14000);
    });
  });

  group('CheckoutDraft totals', () {
    test('subtotal, discount, and total sum across lines', () {
      final draft = CheckoutDraft(lines: [
        _line('1', 5000, 1, 0), // gross 5000, total 5000
        _line('2', 2000, 2, 500), // gross 4000, total 3500
      ]);
      expect(draft.subtotalCents, 9000);
      expect(draft.discountCents, 500);
      expect(draft.totalCents, 8500);
      expect(draft.lineCount, 2);
      expect(draft.isEmpty, isFalse);
    });

    test('an empty draft is zero and isEmpty', () {
      const draft = CheckoutDraft();
      expect(draft.subtotalCents, 0);
      expect(draft.totalCents, 0);
      expect(draft.isEmpty, isTrue);
    });
  });
}
