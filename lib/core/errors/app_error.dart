import 'dart:async' show TimeoutException;

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

/// A connectivity problem (offline, DNS, timeout) — the counter can retry.
final class NetworkError extends AppError {
  const NetworkError(super.message);
}

/// A failure we did not recognise. Still actionable — not a bare "error".
final class UnexpectedError extends AppError {
  const UnexpectedError(super.message);
}

/// Heuristic for connectivity failures, without importing `dart:io` (keeps this
/// portable). Matches the common transport errors by type and by text.
bool _looksLikeNetwork(Object error) {
  if (error is TimeoutException) return true;
  final s = error.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('failed host lookup') ||
      s.contains('connection refused') ||
      s.contains('connection closed') ||
      s.contains('network is unreachable') ||
      s.contains('timed out') ||
      s.contains('timeout');
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
  if (_looksLikeNetwork(error)) {
    return const NetworkError(
      'Could not reach Rosea. Check your internet connection and try again.',
    );
  }
  return const UnexpectedError(
    'Something went wrong signing in. Try again — if it keeps happening, tell the owner.',
  );
}
