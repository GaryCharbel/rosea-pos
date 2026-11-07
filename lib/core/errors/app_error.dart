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

/// A payment problem. [retriable] means a retry of the SAME idempotent call could
/// succeed (offline/transient) — the outbox keeps it queued. Non-retriable means the
/// ticket itself must change (split mismatch, already paid, permission).
final class PayError extends AppError {
  const PayError(super.message, {this.retriable = false});
  final bool retriable;
}

/// Maps a pay_ticket failure to an [AppError]. The server raises each error with a
/// SQLSTATE token (P0001/P0002/P0004, 42501) AND an actionable message — we surface
/// that message verbatim and never auto-retry it. Transport failures are retriable.
AppError mapPayError(Object error) {
  if (error is PostgrestException) {
    final String code = error.code ?? '';
    final String serverMsg = error.message.trim();
    switch (code) {
      case 'P0001': // not open / already paid / voided / not found
      case 'P0002': // split != total / bad shape
      case 'P0004': // empty ticket
        return PayError(serverMsg.isNotEmpty
            ? serverMsg
            : 'The payment was rejected. Check the ticket and try again.');
      case '42501': // insufficient_privilege
        return const PayError(
          'Only salon staff can take payments. Sign in with a staff account.',
        );
    }
    return PayError(serverMsg.isNotEmpty
        ? serverMsg
        : 'The payment was rejected. Check the ticket and try again.');
  }
  if (_looksLikeNetwork(error)) {
    return const PayError(
      "Offline — the sale is queued and will finish when you're back online.",
      retriable: true,
    );
  }
  return const PayError(
    "Couldn't reach the server to take payment. It's queued — try again in a moment.",
    retriable: true,
  );
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
