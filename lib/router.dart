import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/session_controller.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/shell/ui/home_screen.dart';
import 'features/shell/ui/splash_screen.dart';
import 'features/staff/ui/staff_switch_screen.dart';

/// App router. Redirects between `/login` and the shell based on the session, and
/// re-runs the redirect whenever the session changes (via [refreshListenable]).
final routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    routes: <RouteBase>[
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/performer', builder: (_, __) => const StaffSwitchScreen()),
    ],
    redirect: (_, GoRouterState state) {
      final SessionState auth = ref.read(sessionProvider);
      final String loc = state.matchedLocation;
      if (auth is SessionLoading) return loc == '/splash' ? null : '/splash';
      final bool signedIn = auth is Authenticated;
      if (!signedIn) return loc == '/login' ? null : '/login';
      // Signed in: leave the splash/login routes for the shell.
      return (loc == '/splash' || loc == '/login') ? '/' : null;
    },
  );
});
