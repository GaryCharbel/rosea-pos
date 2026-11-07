import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error.dart';

/// The app's authentication state. (Named `SessionState` — not `AuthState` — because
/// supabase_flutter already exports an `AuthState` for its auth-change events.)
sealed class SessionState {
  const SessionState();
}

/// Resolving the persisted session on boot.
final class SessionLoading extends SessionState {
  const SessionLoading();
}

/// No signed-in user.
final class Unauthenticated extends SessionState {
  const Unauthenticated();
}

/// A signed-in user, with the role resolved from their profile.
final class Authenticated extends SessionState {
  const Authenticated({
    required this.userId,
    required this.role,
    this.staffId,
    this.fullName,
  });

  final String userId;
  final String role; // 'owner' | 'staff' | 'client'
  final String? staffId; // the performer identity, when role == 'staff'
  final String? fullName;

  bool get isStaffOrOwner => role == 'owner' || role == 'staff';
  bool get isOwner => role == 'owner';
}

/// Owns the Supabase session and the signed-in user's role.
///
/// The role is read from the user's own `profiles` row (RLS lets them read it).
/// Once the Custom Access Token hook is registered on the project, a JWT-claim
/// fast path can replace that round-trip.
class SessionController extends Notifier<SessionState> {
  StreamSubscription<AuthState>? _sub;
  int _gen = 0; // guards against a stale async resolve overwriting a newer state

  SupabaseClient get _client => Supabase.instance.client;

  @override
  SessionState build() {
    // onAuthStateChange emits an `initialSession` event on subscribe, so the
    // persisted session is resolved via the stream (no separate duplicate read).
    // Events that don't change the role (tokenRefreshed, etc.) are skipped.
    _sub = _client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.userUpdated:
          _resolve(data.session);
        case AuthChangeEvent.signedOut:
          _resolve(null);
        default:
          break;
      }
    });
    ref.onDispose(() => _sub?.cancel());
    return const SessionLoading();
  }

  Future<void> _resolve(Session? session) async {
    final int gen = ++_gen;
    if (session == null) {
      state = const Unauthenticated();
      return;
    }
    try {
      final row = await _client
          .from('profiles')
          .select('role, staff_id, full_name')
          .eq('id', session.user.id)
          .maybeSingle();
      if (gen != _gen) return; // a newer auth change superseded this resolve
      state = Authenticated(
        userId: session.user.id,
        role: (row?['role'] as String?) ?? 'client',
        staffId: row?['staff_id'] as String?,
        fullName: row?['full_name'] as String?,
      );
    } catch (_) {
      if (gen != _gen) return;
      // Signed in but the profile read failed; treat as a plain client for now.
      state = Authenticated(userId: session.user.id, role: 'client');
    }
  }

  /// Signs in with email + password.
  ///
  /// Returns `null` on success (the auth-state stream drives the state change) or
  /// an [AppError] with actionable copy on failure.
  Future<AppError?> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null;
    } catch (e) {
      return mapAuthError(e);
    }
  }

  Future<void> signOut() => _client.auth.signOut();
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
