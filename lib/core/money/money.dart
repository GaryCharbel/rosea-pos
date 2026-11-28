/// Money is handled internally as integer **cents** so a sale can never drift on
/// floating-point error. The backend stores `numeric(12,2)`; the Supabase client may
/// return it as a String (preserving precision) or a num. These helpers convert both
/// ways by string surgery (no float math), and are unit-tested so we can't mispay 100x.
library;

import 'package:flutter/services.dart';

/// Input formatters for a money TextField: rejects any edit that isn't a clean decimal
/// (one dot, <=2 fraction digits), so `centsFromServer` never sees "1.2.3" and throws.
List<TextInputFormatter> moneyInputFormatters() => <TextInputFormatter>[
      TextInputFormatter.withFunction((oldValue, newValue) {
        final t = newValue.text;
        if (t.isEmpty) return newValue;
        // At most 9 whole digits (up to 9,999,999.99) + <=2 fraction digits, one dot.
        // The whole-digit cap keeps `centsFromServer` from ever seeing a value that would
        // overflow a 64-bit int, so no keystroke can throw inside a dialog's build().
        return RegExp(r'^\d{0,9}(\.\d{0,2})?$').hasMatch(t) ? newValue : oldValue;
      }),
    ];

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

  // tryParse (not parse) so a pathological or over-long value can never throw here —
  // this helper must be total: callers run it inside widget build() on every keystroke.
  final whole = wholePart.isEmpty ? 0 : (int.tryParse(wholePart) ?? 0);
  // pad/truncate the fraction to exactly two digits
  final frac2 = '${fracPart}00'.substring(0, 2);
  final frac = int.tryParse(frac2) ?? 0;

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
