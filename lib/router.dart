import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/session_controller.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/shell/ui/home_screen.dart';

/// App router. Redirects between `/login` and the shell based on the session, and
/// re-runs the redirect whenever the session changes (via [refreshListenable]).
final routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    ],
    redirect: (_, GoRouterState state) {
      final SessionState auth = ref.read(sessionProvider);
      if (auth is SessionLoading) return null; // wait for the session to resolve
      final bool signedIn = auth is Authenticated;
      final bool atLogin = state.matchedLocation == '/login';
      if (!signedIn) return atLogin ? null : '/login';
      if (atLogin) return '/';
      return null;
    },
  );
});
