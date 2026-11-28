import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client.dart';

/// Reads/creates salon clients for the front-desk "Add customer" picker. Abstracted
/// behind an interface so the UI is testable with a fake (the real round-trip is
/// gated by the `client_staff_all` RLS policy — staff can search + quick-add).
abstract interface class ClientRepo {
  /// Up to 20 matches by name or phone, ordered by name. An empty query returns the
  /// first 20 clients by name.
  Future<List<Client>> search(String query);

  /// Create a walk-in client and return it (phone optional).
  Future<Client> quickAdd({required String name, String? phone});
}

class SupabaseClientRepo implements ClientRepo {
  SupabaseClientRepo(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Client>> search(String query) async {
    // The term travels in the POST body of the search_clients RPC (not the GET query
    // string), so client PII never lands in a request URL. The server owns the
    // name/phone matching, LIKE-wildcard escaping, RLS, the id/name/phone projection
    // and the 20-row cap.
    final res = await _client.rpc<dynamic>(
      'search_clients',
      params: <String, dynamic>{'term': query.trim()},
    );
    final rows = (res as List<dynamic>?) ?? const <dynamic>[];
    return rows
        .map((e) => Client.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<Client> quickAdd({required String name, String? phone}) async {
    final trimmedPhone = phone?.trim();
    try {
      final row = await _client
          .from('client')
          .insert(<String, dynamic>{
            'name': name.trim(),
            if (trimmedPhone != null && trimmedPhone.isNotEmpty) 'phone': trimmedPhone,
          })
          .select('id, name, phone')
          .single();
      return Client.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      // 23505 = the normalized phone already exists — a retry after a lost response, or
      // a genuine duplicate. Return the existing client instead of failing, so a
      // quick-add with a phone is idempotent. (Phone-less walk-ins have no unique key,
      // so they can't collide and this branch doesn't apply.)
      if (e.code == '23505' && trimmedPhone != null && trimmedPhone.isNotEmpty) {
        final existing = await search(trimmedPhone);
        if (existing.isNotEmpty) return existing.first;
      }
      rethrow;
    }
  }
}

final clientRepoProvider =
    Provider<ClientRepo>((ref) => SupabaseClientRepo(Supabase.instance.client));
