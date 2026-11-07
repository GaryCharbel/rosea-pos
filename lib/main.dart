import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase/supabase_init.dart';
import 'env.dart';
import 'features/checkout/pay_controller.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured(); // fail fast with an actionable message if config is missing
  await initSupabase();

  final container = ProviderContainer();
  // Boot recovery: if a sale was stranded by a previous app kill and a session is
  // restored, retry it now (idempotent via its client_tx). Logged-out boots skip it;
  // the retry happens when staff sign back in and reach checkout.
  if (Supabase.instance.client.auth.currentSession != null) {
    unawaited(container.read(payControllerProvider.notifier).flushPending());
  }

  runApp(UncontrolledProviderScope(container: container, child: const RoseaPosApp()));
}

/// Root of the Rosea POS. Dark, high-contrast (never flat/washed-out). Routing +
/// the login/shell redirect live in [routerProvider].
class RoseaPosApp extends ConsumerWidget {
  const RoseaPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Rosea POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0A0F),
      ),
      routerConfig: router,
    );
  }
}
