import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rosea_pos/core/errors/app_error.dart';

void main() {
  group('mapAuthError', () {
    test('bad credentials -> actionable AuthError (no "unexpected error")', () {
      final e = mapAuthError(AuthException('Invalid login credentials'));
      expect(e, isA<AuthError>());
      expect(e.message.toLowerCase(), contains('incorrect'));
      expect(e.message.toLowerCase(), isNot(contains('unexpected')));
    });

    test('rate limiting -> actionable AuthError with wait guidance', () {
      final e = mapAuthError(AuthException('Too many requests'));
      expect(e, isA<AuthError>());
      expect(e.message.toLowerCase(), contains('wait'));
    });

    test('a non-auth failure -> actionable UnexpectedError (connectivity)', () {
      final e = mapAuthError(Exception('socket closed'));
      expect(e, isA<UnexpectedError>());
      expect(e.message.toLowerCase(), contains('connection'));
    });

    test('an unknown AuthException still surfaces its message, actionably', () {
      final e = mapAuthError(AuthException('Email not confirmed'));
      expect(e, isA<AuthError>());
      expect(e.message, contains('Email not confirmed'));
    });
  });
}
