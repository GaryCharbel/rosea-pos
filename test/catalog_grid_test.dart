import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/catalog_repo.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/catalog/ui/catalog_grid_screen.dart';

/// Keeps the screen's sync controller from touching the real repo/Drift/Supabase.
class _IdleSync extends CatalogSyncController {
  @override
  SyncStatus build() => const SyncIdle();
  @override
  Future<void> refresh() async {}
}

void main() {
  const catalog = Catalog([
    CatalogSection(title: 'Hair', kind: CatalogKind.service, items: [
      CatalogItem(id: 's1', name: 'Women\'s Cut', priceCents: 5000, kind: CatalogKind.service),
      CatalogItem(id: 's2', name: 'Blow Dry', priceCents: 3000, kind: CatalogKind.service),
    ]),
  ]);

  testWidgets('renders cached catalog and reports the tapped item', (tester) async {
    CatalogItem? tapped;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogProvider.overrideWith((ref) => Stream.value(catalog)),
          catalogSyncProvider.overrideWith(_IdleSync.new),
        ],
        child: MaterialApp(
          home: CatalogGridScreen(onItemTap: (_, item) => tapped = item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HAIR'), findsOneWidget); // section titles render uppercased
    expect(find.text("Women's Cut"), findsOneWidget);
    expect(find.text('50.00'), findsOneWidget); // price formatted from cents

    await tester.tap(find.text("Women's Cut"));
    await tester.pump();
    expect(tapped?.id, 's1');
  });

  testWidgets('shows the actionable empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogProvider.overrideWith((ref) => Stream.value(const Catalog([]))),
          catalogSyncProvider.overrideWith(_IdleSync.new),
        ],
        child: const MaterialApp(home: CatalogGridScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No services or products yet'), findsOneWidget);
  });
}
