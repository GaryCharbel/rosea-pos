import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client.dart';

/// Reads/creates salon clients for the front-desk "Add customer" picker. Abstracted
/// behind an interface so the UI is testable with a fake (the real round-trip is
/// gated by the `client_staff_all` RLS policy — staff can search + quick-add).
abstract interface class ClientRepo {
  /// Up to 20 matches by name or phone. An empty query returns the most recent names.
  Future<List<Client>> search(String query);

  /// Create a walk-in client and return it (phone optional).
  Future<Client> quickAdd({required String name, String? phone});
}

class SupabaseClientRepo implements ClientRepo {
  SupabaseClientRepo(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Client>> search(String query) async {
    // Strip characters that have meaning in the PostgREST filter grammar / LIKE so a
    // search term can't alter the query (`,()` break `or(...)`, `%_*\` are wildcards).
    final q = query.trim().replaceAll(RegExp(r'[,()%_*\\]'), '');
    final base = _client.from('client').select('id, name, phone');
    final rows = q.isEmpty
        ? await base.order('name').limit(20)
        : await base.or('name.ilike.%$q%,phone.ilike.%$q%').order('name').limit(20);
    return rows.map((e) => Client.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<Client> quickAdd({required String name, String? phone}) async {
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
