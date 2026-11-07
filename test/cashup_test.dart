import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/reports/domain/cashup.dart';

void main() {
  group('buildCashUp', () {
    test('groups commission by staff, nets reversals, sorts desc, drops zero-net', () {
      final c = buildCashUp(
        commission: const [
          (staffName: 'Lea', amountCents: 4000),
          (staffName: 'Maya', amountCents: 500),
          (staffName: 'Lea', amountCents: 1000),
          (staffName: 'Maya', amountCents: -500), // reversal nets Maya to 0 -> dropped
        ],
        payments: const [],
        tipCents: const [],
      );
      expect(c.commissionByStaff.map((s) => s.staffName).toList(), ['Lea']);
      expect(c.commissionByStaff.single.amountCents, 5000);
      expect(c.totalCommissionCents, 5000);
    });

    test('nets takings per method (voids cancel) and drops zero-net methods', () {
      final c = buildCashUp(
        commission: const [],
        payments: const [
          (method: 'cash', amountCents: 5000),
          (method: 'card', amountCents: 3000),
          (method: 'card', amountCents: -3000), // voided card sale -> card nets 0, dropped
        ],
        tipCents: const [1000, 500],
      );
      expect(c.takingsByMethod, {'cash': 5000});
      expect(c.grossTakingsCents, 5000);
      expect(c.tipTotalCents, 1500);
    });

    test('empty input -> isEmpty', () {
      final c = buildCashUp(commission: const [], payments: const [], tipCents: const []);
      expect(c.isEmpty, isTrue);
    });
  });
}
