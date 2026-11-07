import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/core/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapPayError', () {
    test('server P-codes surface the actionable message and are NOT retriable', () {
      for (final code in ['P0001', 'P0002', 'P0004']) {
        final e = mapPayError(PostgrestException(message: 'Adjust the split so it matches.', code: code));
        expect(e, isA<PayError>());
        expect((e as PayError).retriable, isFalse);
        expect(e.message, 'Adjust the split so it matches.');
      }
    });

    test('insufficient_privilege (42501) gives a permission message, not retriable', () {
      final e = mapPayError(PostgrestException(message: 'permission denied', code: '42501'));
      expect((e as PayError).retriable, isFalse);
      expect(e.message, contains('staff'));
    });

    test('transport failures are retriable (queued)', () {
      final e = mapPayError(TimeoutException('timed out'));
      expect(e, isA<PayError>());
      expect((e as PayError).retriable, isTrue);
      expect(e.message.toLowerCase(), contains('queued'));
    });
  });
}
