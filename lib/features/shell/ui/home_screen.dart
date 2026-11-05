import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session_controller.dart';

/// Post-login landing. A placeholder shell for now — the checkout screens arrive
/// in Stage 1 (Phase 4). Confirms the signed-in user + role and offers sign-out.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState auth = ref.watch(sessionProvider);
    final String name = auth is Authenticated ? (auth.fullName ?? 'there') : 'there';
    final String role = auth is Authenticated ? auth.role : '';

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
          ],
        ),
      ),
    );
  }
}
