import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../catalog_repo.dart';
import '../domain/catalog.dart';

const _bg = Color(0xFF0C0A0F);
const _card = Color(0xFF1A141F);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);

/// The checkout surface for Phase 4.1: the cached catalog grid. Ring-up (adding a
/// tapped item to a ticket) arrives in Phase 4.2 — for now a tap is acknowledged.
class CatalogGridScreen extends ConsumerWidget {
  const CatalogGridScreen({super.key, this.onItemTap});

  /// Hook for Phase 4.2 (add the item to the open ticket). Defaults to a toast.
  final void Function(BuildContext context, CatalogItem item)? onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final sync = ref.watch(catalogSyncProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: sync is SyncInProgress
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2, color: _pink, backgroundColor: _bg),
              )
            : null,
      ),
      body: Column(
        children: <Widget>[
          if (sync is SyncFailed) _SyncBanner(message: sync.message, onRetry: () {
            ref.read(catalogSyncProvider.notifier).refresh();
          }),
          Expanded(
            child: catalog.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _pink),
              ),
              error: (Object e, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "Couldn't open the local catalog. Restart the app; if it persists, reinstall.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                ),
              ),
              data: (Catalog c) => c.isEmpty
                  ? const _EmptyCatalog()
                  : _CatalogList(
                      catalog: c,
                      onTap: (item) => (onItemTap ?? _defaultTap)(context, item),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _defaultTap(BuildContext context, CatalogItem item) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: _card,
        content: Text('${item.name} — ring-up arrives in the next step',
            style: const TextStyle(color: _ink)),
      ));
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A1420),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: <Widget>[
            const Icon(Icons.wifi_off, color: _pink, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: _ink, fontSize: 13)),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(color: _pink, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No services or products yet. Add them in the backoffice, then pull to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.catalog, required this.onTap});
  final Catalog catalog;
  final void Function(CatalogItem) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: catalog.sections.length,
      itemBuilder: (BuildContext context, int i) {
        final section = catalog.sections[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
              child: Text(
                section.title.toUpperCase(),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final item in section.items) _ItemCard(item: item, onTap: () => onTap(item)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final CatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      elevation: 3,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 168,
          height: 108,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Text(
                formatCents(item.priceCents),
                style: const TextStyle(color: _pink, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
