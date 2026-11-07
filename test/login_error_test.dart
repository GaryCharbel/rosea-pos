import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/core/errors/app_error.dart';
import 'package:rosea_pos/features/auth/session_controller.dart';
import 'package:rosea_pos/features/auth/ui/login_screen.dart';

/// A session whose sign-in always fails with actionable copy — and whose build()
/// never touches Supabase (so the widget test runs offline).
class _FailingSession extends SessionController {
  @override
  SessionState build() => const Unauthenticated();

  @override
  Future<AppError?> signIn({required String email, required String password}) async =>
      const AuthError('Email or password is incorrect. Check them and try again.');
}

void main() {
  testWidgets('a failed sign-in surfaces the actionable message, never a generic error',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionProvider.overrideWith(_FailingSession.new)],
      child: const MaterialApp(home: LoginScreen()),
    ));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'owner@test.com');
    await tester.enterText(fields.at(1), 'wrongpass');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect. Check them and try again.'),
        findsOneWidget);
    // and the banned generic copy never appears
    expect(find.textContaining('unexpected error', findRichText: true), findsNothing);
  });
}
