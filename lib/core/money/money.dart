/// Money is handled internally as integer **cents** so a sale can never drift on
/// floating-point error. The backend stores `numeric(12,2)`; the Supabase client may
/// return it as a String (preserving precision) or a num. These helpers convert both
/// ways by string surgery (no float math), and are unit-tested so we can't mispay 100x.
library;

/// Parse a server money value (`numeric` as String/num, e.g. `"50.00"` or `50.5`)
/// into integer cents. Null/empty -> 0. Extra fractional digits are truncated to 2dp.
int centsFromServer(Object? value) {
  if (value == null) return 0;
  final raw = value.toString().trim();
  if (raw.isEmpty) return 0;

  final negative = raw.startsWith('-');
  final body = negative ? raw.substring(1) : raw;
  final dot = body.indexOf('.');

  final wholePart = dot == -1 ? body : body.substring(0, dot);
  final fracPart = dot == -1 ? '' : body.substring(dot + 1);

  final whole = wholePart.isEmpty ? 0 : int.parse(wholePart);
  // pad/truncate the fraction to exactly two digits
  final frac2 = '${fracPart}00'.substring(0, 2);
  final frac = int.parse(frac2);

  final cents = whole * 100 + frac;
  return negative ? -cents : cents;
}

/// cents -> a `numeric`-compatible decimal string (`5000 -> "50.00"`), for RPC sends.
String centsToDecimalString(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final s = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  return negative ? '-$s' : s;
}

/// cents -> a display string, optionally prefixed with a currency code (`"USD 50.00"`).
String formatCents(int cents, {String currency = ''}) {
  final decimal = centsToDecimalString(cents);
  return currency.isEmpty ? decimal : '$currency $decimal';
}
