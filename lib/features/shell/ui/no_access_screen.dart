import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session_controller.dart';

/// Shown when a signed-in account isn't a salon owner or staff member. The POS is
/// a staff tool; a client account (e.g. a booking-site login) has no place here.
/// Actionable copy + sign-out so they can switch to the right account (Rule #7).
class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A0F),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline, color: Color(0xFFED3D8C), size: 48),
              const SizedBox(height: 20),
              const Text(
                'This account can’t use the POS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF5EDF1),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The point of sale is for salon owners and staff. Sign out and '
                'sign in with a staff account, or ask the owner to grant you access.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB8A9B0)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFED3D8C)),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
