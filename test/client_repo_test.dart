import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/clients/client_repo.dart';

void main() {
  group('sanitizeClientSearch', () {
    test('keeps ordinary name/phone characters', () {
      expect(sanitizeClientSearch('Rania'), 'Rania');
      expect(sanitizeClientSearch('+961 3 412 889'), '+961 3 412 889');
      expect(sanitizeClientSearch("O'Brien"), "O'Brien"); // apostrophe is harmless
    });

    test('strips PostgREST filter-grammar and LIKE-wildcard characters', () {
      // ,()" break or(...); % _ * \ are wildcards/escape — none may reach the filter.
      expect(sanitizeClientSearch('Rania, Randa'), 'Rania Randa');
      expect(sanitizeClientSearch('name.ilike.(evil)'), 'name.ilike.evil');
      expect(sanitizeClientSearch(r'50%_off*\"'), '50off');
      expect(sanitizeClientSearch('O"Brien'), 'OBrien'); // the double-quote is removed
    });

    test('trims and collapses a punctuation-only term to empty', () {
      expect(sanitizeClientSearch('   '), '');
      expect(sanitizeClientSearch('(%_)'), '');
      expect(sanitizeClientSearch('  %  '), '');
    });
  });
}
