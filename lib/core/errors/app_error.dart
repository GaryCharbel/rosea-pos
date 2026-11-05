import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-facing error that always carries an *actionable* message
/// (Golden Rule #7: say what happened AND what to do — never "unexpected error").
sealed class AppError {
  const AppError(this.message);

  /// Message shown to the user. Written to be actionable.
  final String message;
}

/// A sign-in / authentication problem.
final class AuthError extends AppError {
  const AuthError(super.message);
}

/// Anything we did not specifically recognise (treated as a connectivity-ish
/// failure, with an actionable next step rather than a bare "error").
final class UnexpectedError extends AppError {
  const UnexpectedError(super.message);
}

/// Maps a thrown error from a sign-in call into an [AppError] with actionable copy.
///
/// Known Supabase auth failures (bad credentials, rate limiting) get specific,
/// non-leaky guidance; everything else becomes an actionable connectivity message.
AppError mapAuthError(Object error) {
  if (error is AuthException) {
    // AuthApiException.statusCode is a String? in this supabase_flutter version.
    final String? status = error is AuthApiException ? error.statusCode : null;
    final String m = error.message.toLowerCase();

    if (status == '429' || m.contains('too many')) {
      return const AuthError('Too many sign-in attempts. Wait a minute and try again.');
    }
    if (status == '400' || m.contains('invalid login') || m.contains('credentials')) {
      return const AuthError('Email or password is incorrect. Check them and try again.');
    }
    return AuthError('Could not sign in: ${error.message}');
  }
  return const UnexpectedError(
    'Could not reach Rosea. Check your internet connection and try again.',
  );
}
