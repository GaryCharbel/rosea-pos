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

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Rosea POS · v1.0'), findsOneWidget); // version footer
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('password visibility toggles', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[sessionProvider.overrideWith(_FakeSession.new)],
      child: const MaterialApp(home: LoginScreen()),
    ));
    // Obscured by default -> offers "Show password"; tapping flips to "Hide password".
    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('forgot password surfaces guidance (a snackbar)', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[sessionProvider.overrideWith(_FakeSession.new)],
      child: const MaterialApp(home: LoginScreen()),
    ));
    await tester.tap(find.text('Forgot password?'));
    await tester.pump(); // let the SnackBar animate in
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
