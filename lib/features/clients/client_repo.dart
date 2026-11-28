import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client.dart';

/// Reads/creates salon clients for the front-desk "Add customer" picker. Abstracted
/// behind an interface so the UI is testable with a fake (the real round-trip is
/// gated by the `client_staff_all` RLS policy — staff can search + quick-add).
abstract interface class ClientRepo {
  /// Up to 20 matches by name or phone, ordered by name. An empty query returns the
  /// first 20 clients by name; a query that is only punctuation returns no matches.
  Future<List<Client>> search(String query);

  /// Create a walk-in client and return it (phone optional).
  Future<Client> quickAdd({required String name, String? phone});
}

/// Strips characters that carry meaning in the PostgREST filter grammar / LIKE so a
/// search term can't alter the query: `,()"` break `or(...)`, and `%_*\` are wildcards.
/// Pure + top-level so the sanitisation is unit-testable without a Supabase client.
String sanitizeClientSearch(String query) =>
    query.replaceAll(RegExp(r'[,()%_*\\"]'), '').trim();

class SupabaseClientRepo implements ClientRepo {
  SupabaseClientRepo(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Client>> search(String query) async {
    final typed = query.trim();
    final q = sanitizeClientSearch(query);
    // The user typed something, but it was only punctuation/wildcards — treat that as
    // "no matches" rather than widening to the full recent list (which would surface
    // every client for a term like `(` or `%`).
    if (typed.isNotEmpty && q.isEmpty) return const <Client>[];
    // NOTE: PostgREST filters travel in the GET query string, so the term (name/phone)
    // appears in the request URL. Acceptable over TLS for a single salon for now; the
    // privacy-clean fix is a `search_clients()` RPC (term in the POST body) in the
    // rosea repo — tracked as a follow-up so this doesn't block the stack.
    final base = _client.from('client').select('id, name, phone');
    final rows = q.isEmpty
        ? await base.order('name').limit(20)
        : await base.or('name.ilike.%$q%,phone.ilike.%$q%').order('name').limit(20);
    return rows.map((e) => Client.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<Client> quickAdd({required String name, String? phone}) async {
    // NOTE: not idempotent — if the insert succeeds but the response is lost and the
    // cashier retries, a duplicate client is created. The UI guards against a double
    // tap; a durable fix (a client_tx key or a name+phone unique constraint) is a
    // rosea-repo follow-up.
    final trimmedPhone = phone?.trim();
    final row = await _client
        .from('client')
        .insert(<String, dynamic>{
          'name': name.trim(),
          if (trimmedPhone != null && trimmedPhone.isNotEmpty) 'phone': trimmedPhone,
        })
        .select('id, name, phone')
        .single();
    return Client.fromMap(Map<String, dynamic>.from(row));
  }
}

final clientRepoProvider =
    Provider<ClientRepo>((ref) => SupabaseClientRepo(Supabase.instance.client));
