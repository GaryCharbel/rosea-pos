/// Runtime configuration, injected via `--dart-define-from-file=env/<name>.json`.
///
/// Never hard-code the URL/key here and never commit real values
/// (Golden Rule #10). Copy `env/test.json` to `env/local.json`, fill it in,
/// and pass it with `--dart-define-from-file`.
class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Fail fast with an actionable message if config is missing.
  static void assertConfigured() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Rosea POS is not configured — missing ${missing.join(', ')}. '
        'Copy env/test.json to env/local.json, fill in your Supabase URL + anon key, '
        'and run with: --dart-define-from-file=env/local.json. See README.',
      );
    }
  }
}
