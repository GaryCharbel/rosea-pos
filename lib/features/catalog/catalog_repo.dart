import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/money/money.dart';
import 'data/catalog_database.dart';
import 'data/catalog_source.dart';
import 'domain/catalog.dart';

/// Read-through catalog cache. The grid always renders from the local Drift copy
/// (survives a WiFi blip); [sync] refreshes that copy from the server and reconciles
/// soft-deletes (inactive) and hard-deletes (rows the server no longer returns).
class CatalogRepository {
  CatalogRepository(this._db, this._source);

  final CatalogDatabase _db;
  final CatalogSource _source;

  /// Emits the grouped catalog now, then again on any local change.
  Stream<Catalog> watch() async* {
    yield await _load();
    yield* _db.tableUpdates().asyncMap((_) => _load());
  }

  /// One fetch per table (no N+1), then a single transaction that upserts every row
  /// and removes any cached id the server didn't return.
  Future<void> sync() async {
    final snap = await _source.fetch();
    await _db.transaction(() async {
      await _reconcileCategories(snap.categories);
      await _reconcileServices(snap.services);
      await _reconcileProducts(snap.products);
    });
  }

  Future<void> _reconcileCategories(List<Map<String, dynamic>> rows) async {
    final ids = <String>[];
    for (final r in rows) {
      final id = r['id'] as String;
      ids.add(id);
      await _db.into(_db.categories).insertOnConflictUpdate(
            CategoriesCompanion.insert(
              id: id,
              name: r['name'] as String,
              kind: r['kind'] as String,
              sortOrder: Value((r['sort_order'] as num?)?.toInt() ?? 0),
              active: Value(r['active'] as bool? ?? true),
            ),
          );
    }
    if (ids.isEmpty) {
      await _db.delete(_db.categories).go();
    } else {
      await (_db.delete(_db.categories)..where((c) => c.id.isNotIn(ids))).go();
    }
  }

  Future<void> _reconcileServices(List<Map<String, dynamic>> rows) async {
    final ids = <String>[];
    for (final r in rows) {
      final id = r['id'] as String;
      ids.add(id);
      await _db.into(_db.services).insertOnConflictUpdate(
            ServicesCompanion.insert(
              id: id,
              categoryId: Value(r['category_id'] as String?),
              name: r['name'] as String,
              priceCents: centsFromServer(r['price']),
              sortOrder: Value((r['sort_order'] as num?)?.toInt() ?? 0),
              active: Value(r['active'] as bool? ?? true),
            ),
          );
    }
    if (ids.isEmpty) {
      await _db.delete(_db.services).go();
    } else {
      await (_db.delete(_db.services)..where((s) => s.id.isNotIn(ids))).go();
    }
  }

  Future<void> _reconcileProducts(List<Map<String, dynamic>> rows) async {
    final ids = <String>[];
    for (final r in rows) {
      final id = r['id'] as String;
      ids.add(id);
      await _db.into(_db.products).insertOnConflictUpdate(
            ProductsCompanion.insert(
              id: id,
              categoryId: Value(r['category_id'] as String?),
              name: r['name'] as String,
              priceCents: centsFromServer(r['price']),
              sortOrder: Value((r['sort_order'] as num?)?.toInt() ?? 0),
              active: Value(r['active'] as bool? ?? true),
            ),
          );
    }
    if (ids.isEmpty) {
      await _db.delete(_db.products).go();
    } else {
      await (_db.delete(_db.products)..where((p) => p.id.isNotIn(ids))).go();
    }
  }

  /// Build the display model from the cache: active categories (ordered), each with
  /// its active items; uncategorized items fall into a per-kind catch-all section.
  Future<Catalog> _load() async {
    final cats = await (_db.select(_db.categories)
          ..where((c) => c.active.equals(true))
          ..orderBy([
            (c) => OrderingTerm(expression: c.sortOrder),
            (c) => OrderingTerm(expression: c.name),
          ]))
        .get();
    final services = await (_db.select(_db.services)
          ..where((s) => s.active.equals(true))
          ..orderBy([
            (s) => OrderingTerm(expression: s.sortOrder),
            (s) => OrderingTerm(expression: s.name),
          ]))
        .get();
    final products = await (_db.select(_db.products)
          ..where((p) => p.active.equals(true))
          ..orderBy([
            (p) => OrderingTerm(expression: p.sortOrder),
            (p) => OrderingTerm(expression: p.name),
          ]))
        .get();

    return groupCatalog(
      categories: <({String id, String name, CatalogKind kind})>[
        for (final c in cats)
          (
            id: c.id,
            name: c.name,
            kind: c.kind == 'product' ? CatalogKind.product : CatalogKind.service,
          ),
      ],
      services: <({String? categoryId, CatalogItem item})>[
        for (final s in services)
          (
            categoryId: s.categoryId,
            item: CatalogItem(
                id: s.id, name: s.name, priceCents: s.priceCents, kind: CatalogKind.service),
          ),
      ],
      products: <({String? categoryId, CatalogItem item})>[
        for (final p in products)
          (
            categoryId: p.categoryId,
            item: CatalogItem(
                id: p.id, name: p.name, priceCents: p.priceCents, kind: CatalogKind.product),
          ),
      ],
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final catalogDatabaseProvider = Provider<CatalogDatabase>((ref) {
  final db = CatalogDatabase();
  ref.onDispose(db.close);
  return db;
});

final catalogSourceProvider = Provider<CatalogSource>((ref) {
  return SupabaseCatalogSource(Supabase.instance.client);
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(
    ref.watch(catalogDatabaseProvider),
    ref.watch(catalogSourceProvider),
  );
});

/// The cached catalog, grouped for the grid. Always available (read-through).
final catalogProvider = StreamProvider<Catalog>((ref) {
  return ref.watch(catalogRepositoryProvider).watch();
});

/// Background sync state. The grid stays usable (from cache) regardless of this.
sealed class SyncStatus {
  const SyncStatus();
}

class SyncIdle extends SyncStatus {
  const SyncIdle();
}

class SyncInProgress extends SyncStatus {
  const SyncInProgress();
}

class SyncFailed extends SyncStatus {
  const SyncFailed(this.message);
  final String message;
}

/// Kicks off a catalog refresh on first read and exposes [refresh] for a retry.
class CatalogSyncController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    Future<void>.microtask(refresh);
    return const SyncInProgress();
  }

  Future<void> refresh() async {
    state = const SyncInProgress();
    try {
      await ref.read(catalogRepositoryProvider).sync();
      state = const SyncIdle();
    } catch (_) {
      // Keep showing the cached catalog; tell the user what happened + what to do.
      state = const SyncFailed(
        "Couldn't refresh the menu — showing the last saved copy. "
        'Check your connection and tap retry.',
      );
    }
  }
}

final catalogSyncProvider =
    NotifierProvider<CatalogSyncController, SyncStatus>(CatalogSyncController.new);
