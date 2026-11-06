import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';

CatalogItem _svc(String id, String name, int cents) =>
    CatalogItem(id: id, name: name, priceCents: cents, kind: CatalogKind.service);
CatalogItem _prod(String id, String name, int cents) =>
    CatalogItem(id: id, name: name, priceCents: cents, kind: CatalogKind.product);

void main() {
  group('groupCatalog', () {
    test('groups items under their category, by kind', () {
      final catalog = groupCatalog(
        categories: [
          (id: 'c1', name: 'Hair', kind: CatalogKind.service),
          (id: 'c2', name: 'Retail', kind: CatalogKind.product),
        ],
        services: [(categoryId: 'c1', item: _svc('s1', 'Cut', 5000))],
        products: [(categoryId: 'c2', item: _prod('p1', 'Shampoo', 2000))],
      );

      expect(catalog.sections.map((s) => s.title), ['Hair', 'Retail']);
      expect(catalog.sections[0].items.single.name, 'Cut');
      expect(catalog.sections[0].kind, CatalogKind.service);
      expect(catalog.sections[1].items.single.name, 'Shampoo');
      expect(catalog.sections[1].kind, CatalogKind.product);
    });

    test('drops empty categories and keeps category order', () {
      final catalog = groupCatalog(
        categories: [
          (id: 'c1', name: 'Empty', kind: CatalogKind.service),
          (id: 'c2', name: 'Hair', kind: CatalogKind.service),
        ],
        services: [(categoryId: 'c2', item: _svc('s1', 'Cut', 5000))],
        products: const [],
      );
      expect(catalog.sections.map((s) => s.title), ['Hair']);
    });

    test('uncategorized items fall into per-kind catch-alls, after categories', () {
      final catalog = groupCatalog(
        categories: [(id: 'c1', name: 'Hair', kind: CatalogKind.service)],
        services: [
          (categoryId: 'c1', item: _svc('s1', 'Cut', 5000)),
          (categoryId: null, item: _svc('s2', 'Loose Service', 3000)),
        ],
        products: [(categoryId: null, item: _prod('p1', 'Loose Product', 1000))],
      );
      expect(catalog.sections.map((s) => s.title), ['Hair', 'Services', 'Products']);
      expect(catalog.sections[1].items.single.name, 'Loose Service');
      expect(catalog.sections[2].items.single.name, 'Loose Product');
    });

    test('empty everything -> isEmpty', () {
      final catalog = groupCatalog(categories: const [], services: const [], products: const []);
      expect(catalog.isEmpty, isTrue);
    });

    test('a product-kind category never pulls in services (and vice versa)', () {
      // same category id reused across kinds should not cross-contaminate
      final catalog = groupCatalog(
        categories: [(id: 'c1', name: 'Retail', kind: CatalogKind.product)],
        services: [(categoryId: 'c1', item: _svc('s1', 'Cut', 5000))],
        products: [(categoryId: 'c1', item: _prod('p1', 'Shampoo', 2000))],
      );
      // 'Retail' is a product category -> only the product shows under it; the service
      // (categoryId c1 but service kind) is not rendered under a product category.
      expect(catalog.sections.map((s) => s.title), ['Retail']);
      expect(catalog.sections.single.items.single.name, 'Shampoo');
    });
  });
}
