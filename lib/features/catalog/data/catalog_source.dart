import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw catalog rows fetched from the server, before they are cached. Each list is a
/// list of column maps straight from PostgREST.
class CatalogSnapshot {
  const CatalogSnapshot({
    required this.categories,
    required this.services,
    required this.products,
  });

  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> products;
}

/// Fetches the catalog from the backend. An interface so tests can supply a fake
/// without touching Supabase.
abstract interface class CatalogSource {
  Future<CatalogSnapshot> fetch();
}

/// Reads the active + inactive catalog in three round-trips (one per table — no N+1).
/// Inactive rows are fetched too so the cache can reconcile soft-deletes; the grid
/// filters them out. Rates/commission columns are never selected.
class SupabaseCatalogSource implements CatalogSource {
  SupabaseCatalogSource(this._client);

  final SupabaseClient _client;

  @override
  Future<CatalogSnapshot> fetch() async {
    final categories = await _client
        .from('category')
        .select('id, name, kind, sort_order, active');
    final services = await _client
        .from('service')
        .select('id, category_id, name, price, active, sort_order');
    final products = await _client
        .from('product')
        .select('id, category_id, name, price, active, sort_order');

    return CatalogSnapshot(
      categories: List<Map<String, dynamic>>.from(categories),
      services: List<Map<String, dynamic>>.from(services),
      products: List<Map<String, dynamic>>.from(products),
    );
  }
}
