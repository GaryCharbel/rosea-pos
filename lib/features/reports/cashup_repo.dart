import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/money/money.dart';
import 'domain/cashup.dart';

typedef CashUpRange = ({DateTime from, DateTime to});

/// Reads the owner cash-up + commission for a date range. RLS lets the owner read all
/// payment/tip/commission_entry rows; the SUMs net voids/reversals. One query per table
/// (no N+1). Never selects rate columns.
class CashUpRepo {
  CashUpRepo(this._client);

  final SupabaseClient _client;

  Future<CashUp> fetch(CashUpRange range) async {
    final fromIso = range.from.toUtc().toIso8601String();
    final toIso = range.to.toUtc().toIso8601String();

    final commission = await _client
        .from('commission_entry')
        .select('amount, staff:staff_id(name)')
        .gte('earned_at', fromIso)
        .lt('earned_at', toIso);
    final payments = await _client
        .from('payment')
        .select('method, amount')
        .gte('created_at', fromIso)
        .lt('created_at', toIso);
    final tips = await _client
        .from('tip')
        .select('amount')
        .gte('created_at', fromIso)
        .lt('created_at', toIso);

    return buildCashUp(
      commission: <({String staffName, int amountCents})>[
        for (final r in commission)
          (staffName: _staffName(r), amountCents: centsFromServer(r['amount'])),
      ],
      payments: <({String method, int amountCents})>[
        for (final r in payments)
          (method: (r['method'] as String?) ?? 'other', amountCents: centsFromServer(r['amount'])),
      ],
      tipCents: <int>[for (final r in tips) centsFromServer(r['amount'])],
    );
  }

  String _staffName(Map<String, dynamic> row) {
    final staff = row['staff'];
    if (staff is Map && staff['name'] is String) return staff['name'] as String;
    return 'Unknown';
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
