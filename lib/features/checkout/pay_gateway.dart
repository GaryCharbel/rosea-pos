import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../catalog/domain/catalog.dart';
import '../../core/money/money.dart';
import 'domain/pay_intent.dart';

/// Persists the ticket + lines and calls pay_ticket. Abstracted so the orchestration
/// (PayController) is testable with a fake; the real round-trip is exercised against a
/// live Supabase in the testing phase.
abstract interface class PayGateway {
  /// Returns the `_pay_ticket_result` payload. Throws PostgrestException on a server
  /// rejection (P-code) and transport errors otherwise.
  Future<Map<String, dynamic>> submit(PayIntent intent);
}

class SupabasePayGateway implements PayGateway {
  SupabasePayGateway(this._client);

  final SupabaseClient _client;
  final Uuid _uuid = const Uuid();

  // Fixed namespace for deriving deterministic, idempotent line ids from the client_tx.
  static const String _ns = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  @override
  Future<Map<String, dynamic>> submit(PayIntent intent) async {
    // The ticket id IS the client_tx, so creating it is idempotent: a retry finds the
    // same row rather than opening a duplicate ticket.
    final String ticketId = intent.clientTx;

    final existing = await _client
        .from('ticket')
        .select('status')
        .eq('id', ticketId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('ticket').insert(<String, dynamic>{
        'id': ticketId,
        'status': 'open',
        'opened_by': intent.openedByStaffId,
      });
      await _insertLines(ticketId, intent);
    } else if (existing['status'] == 'open') {
      // Created on a prior attempt that didn't reach pay — make sure lines are present
      // (deterministic ids make this a safe no-op if they already are).
      await _insertLines(ticketId, intent);
    }
    // If it is already 'paid'/'void', skip straight to pay_ticket: it replays the
    // result for a matching client_tx (and raises the right P-code otherwise).

    final result = await _client.rpc<dynamic>('pay_ticket', params: <String, dynamic>{
      'p_ticket_id': ticketId,
      'p_payments': intent.rpcPayments(),
      'p_tips': intent.rpcTips(),
      'p_client_tx': intent.clientTx,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> _insertLines(String ticketId, PayIntent intent) async {
    if (intent.lines.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < intent.lines.length; i++) {
      final l = intent.lines[i];
      final isService = l.kind == CatalogKind.service;
      rows.add(<String, dynamic>{
        'id': _uuid.v5(_ns, '${intent.clientTx}-line-$i'), // deterministic -> idempotent
        'ticket_id': ticketId,
        'line_type': isService ? 'service' : 'product',
        'service_id': isService ? l.refId : null,
        'product_id': isService ? null : l.refId,
        'name_snapshot': l.name,
        'unit_price': centsToDecimalString(l.unitPriceCents),
        'qty': l.qty,
        'line_discount': centsToDecimalString(l.lineDiscountCents),
        'performer_staff_id': l.performerStaffId,
      });
    }
    await _client.from('ticket_line').upsert(rows, onConflict: 'id', ignoreDuplicates: true);
  }
}
