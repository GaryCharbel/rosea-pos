import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/core/errors/app_error.dart';
import 'package:rosea_pos/features/auth/session_controller.dart';
import 'package:rosea_pos/features/auth/ui/login_screen.dart';

/// A session controller that never touches Supabase, so the login screen can be
/// pumped in a test without initializing the Supabase client.
class _FakeSession extends SessionController {
  @override
  SessionState build() => const Unauthenticated();

  @override
  Future<AppError?> signIn({required String email, required String password}) async => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('login screen renders email, password, and the sign-in button', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[sessionProvider.overrideWith(_FakeSession.new)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Rosea POS'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
