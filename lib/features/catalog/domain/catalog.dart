import 'package:flutter/foundation.dart';

/// Whether a catalog entry is a bookable service or a retail product.
enum CatalogKind { service, product }

/// A single tappable catalog entry (a service or a product). Price is in cents.
@immutable
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.kind,
  });

  final String id;
  final String name;
  final int priceCents;
  final CatalogKind kind;

  @override
  bool operator ==(Object other) =>
      other is CatalogItem && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);
}

/// A titled group of items for the grid (a category, or an "Uncategorized" catch-all).
@immutable
class CatalogSection {
  const CatalogSection({required this.title, required this.kind, required this.items});

  final String title;
  final CatalogKind kind;
  final List<CatalogItem> items;
}

/// The whole cached catalog, already grouped for display.
@immutable
class Catalog {
  const Catalog(this.sections);

  final List<CatalogSection> sections;

  bool get isEmpty => sections.every((s) => s.items.isEmpty);
}

/// Pure grouping used by the repository (and unit-tested without a database):
/// categories (already active + sorted) become sections holding their matching items;
/// items with no category fall into a per-kind "Services"/"Products" catch-all. Empty
/// sections are dropped. [services]/[products] pair each item with its categoryId.
Catalog groupCatalog({
  required List<({String id, String name, CatalogKind kind})> categories,
  required List<({String? categoryId, CatalogItem item})> services,
  required List<({String? categoryId, CatalogItem item})> products,
}) {
  final svcByCat = <String?, List<CatalogItem>>{};
  for (final s in services) {
    (svcByCat[s.categoryId] ??= <CatalogItem>[]).add(s.item);
  }
  final prodByCat = <String?, List<CatalogItem>>{};
  for (final p in products) {
    (prodByCat[p.categoryId] ??= <CatalogItem>[]).add(p.item);
  }

  final sections = <CatalogSection>[];
  for (final c in categories) {
    final items = (c.kind == CatalogKind.product ? prodByCat[c.id] : svcByCat[c.id]) ??
        const <CatalogItem>[];
    if (items.isNotEmpty) {
      sections.add(CatalogSection(title: c.name, kind: c.kind, items: items));
    }
  }
  final looseServices = svcByCat[null] ?? const <CatalogItem>[];
  if (looseServices.isNotEmpty) {
    sections.add(CatalogSection(
        title: 'Services', kind: CatalogKind.service, items: looseServices));
  }
  final looseProducts = prodByCat[null] ?? const <CatalogItem>[];
  if (looseProducts.isNotEmpty) {
    sections.add(CatalogSection(
        title: 'Products', kind: CatalogKind.product, items: looseProducts));
  }
  return Catalog(sections);
}
