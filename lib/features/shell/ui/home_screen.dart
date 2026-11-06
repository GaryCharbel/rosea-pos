import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/session_controller.dart';
import '../../staff/staff_repo.dart';

/// Post-login landing. A placeholder shell for now — the checkout screens arrive
/// in Stage 1 (Phase 4). Confirms the signed-in user + role and offers sign-out.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState auth = ref.watch(sessionProvider);
    final String name = auth is Authenticated ? (auth.fullName ?? 'there') : 'there';
    final String role = auth is Authenticated ? auth.role : '';
    final active = ref.watch(activeStaffProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0A0F),
        foregroundColor: const Color(0xFFF5EDF1),
        title: const Text('Rosea POS', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Welcome, $name',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF5EDF1),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              role.isEmpty ? 'Signed in' : 'Signed in as $role — checkout arrives in Stage 1',
              style: const TextStyle(color: Color(0xFFB8A9B0)),
            ),
            const SizedBox(height: 28),
            Text(
              active == null ? 'No performer selected' : 'Serving: ${active.name}',
              style: const TextStyle(
                color: Color(0xFFF5EDF1),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/performer'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFED3D8C)),
              icon: const Icon(Icons.badge_outlined),
              label: Text(active == null ? 'Choose performer' : 'Change performer'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/checkout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF5EDF1),
                side: const BorderSide(color: Color(0xFF2E2333)),
              ),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Open checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
