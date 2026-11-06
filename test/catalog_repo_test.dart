import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/catalog_repo.dart';
import 'package:rosea_pos/features/catalog/data/catalog_database.dart';
import 'package:rosea_pos/features/catalog/data/catalog_source.dart';

class _FakeSource implements CatalogSource {
  _FakeSource(this.snapshot);
  CatalogSnapshot snapshot;
  @override
  Future<CatalogSnapshot> fetch() async => snapshot;
}

CatalogSnapshot _snap({
  required List<Map<String, dynamic>> categories,
  required List<Map<String, dynamic>> services,
  required List<Map<String, dynamic>> products,
}) =>
    CatalogSnapshot(categories: categories, services: services, products: products);

void main() {
  late CatalogDatabase db;
  late _FakeSource source;
  late CatalogRepository repo;

  setUp(() {
    db = CatalogDatabase.forTesting(NativeDatabase.memory());
    source = _FakeSource(_snap(categories: [], services: [], products: []));
    repo = CatalogRepository(db, source);
  });

  tearDown(() async => db.close());

  test('sync caches rows and watch groups them with price in cents', () async {
    source.snapshot = _snap(
      categories: [
        {'id': 'c1', 'name': 'Hair', 'kind': 'service', 'sort_order': 0, 'active': true},
      ],
      services: [
        {'id': 's1', 'category_id': 'c1', 'name': 'Cut', 'price': '50.00', 'active': true, 'sort_order': 0},
      ],
      products: [],
    );
    await repo.sync();

    final catalog = await repo.watch().first;
    expect(catalog.sections.single.title, 'Hair');
    expect(catalog.sections.single.items.single.name, 'Cut');
    expect(catalog.sections.single.items.single.priceCents, 5000);
  });

  test('soft-deleted (inactive) rows are hidden from the grid', () async {
    source.snapshot = _snap(
      categories: [
        {'id': 'c1', 'name': 'Hair', 'kind': 'service', 'sort_order': 0, 'active': true},
      ],
      services: [
        {'id': 's1', 'category_id': 'c1', 'name': 'Active', 'price': '10.00', 'active': true, 'sort_order': 0},
        {'id': 's2', 'category_id': 'c1', 'name': 'Retired', 'price': '10.00', 'active': false, 'sort_order': 1},
      ],
      products: [],
    );
    await repo.sync();

    final catalog = await repo.watch().first;
    final names = catalog.sections.single.items.map((i) => i.name).toList();
    expect(names, ['Active']);
  });

  test('hard-deleted rows (absent from a later fetch) are reconciled out', () async {
    source.snapshot = _snap(
      categories: [
        {'id': 'c1', 'name': 'Hair', 'kind': 'service', 'sort_order': 0, 'active': true},
      ],
      services: [
        {'id': 's1', 'category_id': 'c1', 'name': 'Cut', 'price': '50.00', 'active': true, 'sort_order': 0},
        {'id': 's2', 'category_id': 'c1', 'name': 'Shave', 'price': '20.00', 'active': true, 'sort_order': 1},
      ],
      products: [],
    );
    await repo.sync();
    expect((await repo.watch().first).sections.single.items.length, 2);

    // second fetch no longer returns s2 (hard-deleted server-side)
    source.snapshot = _snap(
      categories: [
        {'id': 'c1', 'name': 'Hair', 'kind': 'service', 'sort_order': 0, 'active': true},
      ],
      services: [
        {'id': 's1', 'category_id': 'c1', 'name': 'Cut', 'price': '50.00', 'active': true, 'sort_order': 0},
      ],
      products: [],
    );
    await repo.sync();

    final after = await repo.watch().first;
    expect(after.sections.single.items.map((i) => i.name).toList(), ['Cut']);
  });
}
