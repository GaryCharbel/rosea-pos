import 'package:supabase_flutter/supabase_flutter.dart';

import '../../env.dart';

/// Initializes the Supabase client for the app.
///
/// PKCE is the default auth flow. The app authenticates with the anon key + the
/// signed-in user's JWT and is gated by RLS — the `service_role` key never ships
/// here (Golden Rule #10). Call once in `main()` after [Env.assertConfigured].
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // The anon key is now called the "publishable key" in supabase_flutter; the
    // value from the dashboard is the same. (Env field keeps the familiar name.)
    publishableKey: Env.supabaseAnonKey,
  );
}
