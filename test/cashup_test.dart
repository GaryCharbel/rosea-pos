import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/reports/domain/cashup.dart';

void main() {
  group('CashUp.fromRpc', () {
    test('parses cents, drops zero-net methods, sorts staff by commission desc', () {
      final c = CashUp.fromRpc(<String, dynamic>{
        'currency': 'USD',
        'takings_by_method': <String, dynamic>{'cash': 6000, 'card': 4000, 'other': 0},
        'tip_total': 1500,
        'ticket_count': 3,
        'avg_ticket': 3333,
        'by_staff': <dynamic>[
          {'name': 'Maya', 'rate': 30.5, 'services_count': 1, 'services_cents': 5000,
             'products_cents': 0, 'commission_cents': 1525},
          {'name': 'Lea', 'rate': 40, 'services_count': 2, 'services_cents': 9000,
             'products_cents': 0, 'commission_cents': 3600},
        ],
      });

      expect(c.currency, 'USD');
      expect(c.takingsByMethod, {'cash': 6000, 'card': 4000}); // zero-net 'other' dropped
      expect(c.grossTakingsCents, 10000);
      expect(c.tipTotalCents, 1500);
      expect(c.ticketCount, 3);
      expect(c.avgTicketCents, 3333);
      // sorted by commission, highest first
      expect(c.byStaff.map((s) => s.name).toList(), ['Lea', 'Maya']);
      expect(c.byStaff.first.ratePercent, 40);
      expect(c.byStaff[1].ratePercent, 30.5);
      expect(c.byStaff.first.servicesCount, 2);
      expect(c.totalCommissionCents, 3600 + 1525);
      expect(c.isEmpty, isFalse);
    });

    test('defaults missing fields and reports empty', () {
      final c = CashUp.fromRpc(<String, dynamic>{});
      expect(c.currency, '');
      expect(c.takingsByMethod, isEmpty);
      expect(c.byStaff, isEmpty);
      expect(c.ticketCount, 0);
      expect(c.avgTicketCents, 0);
      expect(c.grossTakingsCents, 0);
      expect(c.tipTotalCents, 0);
      expect(c.isEmpty, isTrue);
    });
  });
}
