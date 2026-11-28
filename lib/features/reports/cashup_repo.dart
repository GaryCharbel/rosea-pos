import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'domain/cashup.dart';

typedef CashUpRange = ({DateTime from, DateTime to});

/// Reads the owner cash-up for a date range via the owner-gated `cashup` RPC — the
/// server does the aggregation (takings, tips, ticket count/avg, per-staff rate +
/// services + commission, netting voids) and returns integer cents. A non-owner caller
/// is refused by the RPC (42501), surfaced as an actionable error by the screen.
class CashUpRepo {
  CashUpRepo(this._client);

  final SupabaseClient _client;

  Future<CashUp> fetch(CashUpRange range) async {
    final res = await _client.rpc<dynamic>('cashup', params: <String, dynamic>{
      'p_from': range.from.toUtc().toIso8601String(),
      'p_to': range.to.toUtc().toIso8601String(),
    });
    return CashUp.fromRpc(Map<String, dynamic>.from(res as Map));
  }
}

/// The current day [00:00, next 00:00) in the DEVICE's local timezone. For an on-site
/// single-salon POS that is the salon's day (the till is reconciled where the device
/// is). Honouring salon_settings.timezone for a different-tz device is a later concern
/// (would need a tz library); kept device-local deliberately for Stage 1.
CashUpRange todayRange() {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  return (from: from, to: from.add(const Duration(days: 1)));
}

final cashUpRepoProvider = Provider<CashUpRepo>((ref) {
  return CashUpRepo(Supabase.instance.client);
});

final cashUpRangeProvider = StateProvider<CashUpRange>((ref) => todayRange());

final cashUpProvider = FutureProvider<CashUp>((ref) {
  final range = ref.watch(cashUpRangeProvider);
  return ref.watch(cashUpRepoProvider).fetch(range);
});
