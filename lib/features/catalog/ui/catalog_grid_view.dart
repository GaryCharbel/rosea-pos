import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../catalog_repo.dart';
import '../domain/catalog.dart';

const _bg = Color(0xFF0C0A0F);
const _rail = Color(0xFF141019);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _line = Color(0xFF2E2333);
// Offline/stale banner — amber (p.7), distinct from the pink accent.
const _amberBg = Color(0xFF2A2212);
const _amber = Color(0xFFE7A93B);

/// Below this grid-area width we switch the category selector from a vertical
/// icon rail (desktop/tablet) to a horizontal chip strip (phone) — matching the
/// delivered mockups (p.7 vs p.4).
const double _railBreakpoint = 560;

/// Per-category tile tints (Rosea dark-pink family — not Lightspeed blue). Indexed by
/// the category's position so each category reads as its own colour block.
const List<Color> _tints = <Color>[
  Color(0xFF3A2430), // pink-plum
  Color(0xFF342A42), // indigo-plum
  Color(0xFF3A3326), // gold-brown
  Color(0xFF26323A), // slate-teal
  Color(0xFF3A2A2A), // warm clay
  Color(0xFF2E2333), // neutral plum
];
Color _tintFor(int i) => _tints[i % _tints.length];

IconData _iconFor(CatalogKind kind) =>
    kind == CatalogKind.product ? Icons.shopping_bag_outlined : Icons.content_cut;

/// The currently-selected category section id (null → first section).
final selectedSectionIdProvider = StateProvider<String?>((ref) => null);

/// Checkout catalog area: a category selector (vertical rail on wide screens, a
/// horizontal chip strip on narrow ones) + the tinted item grid for the selected
/// category. Renders from the read-through cache; shows background-sync progress +
/// an actionable "offline — showing last saved copy / Retry" banner at the bottom.
class CatalogGridView extends ConsumerWidget {
  const CatalogGridView({super.key, required this.onItemTap});

  final void Function(BuildContext context, CatalogItem item) onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final sync = ref.watch(catalogSyncProvider);

    return Column(
      children: <Widget>[
        if (sync is SyncInProgress)
          const LinearProgressIndicator(minHeight: 2, color: _pink, backgroundColor: _bg),
        Expanded(
          child: catalog.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _pink)),
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
            data: (Catalog c) =>
                c.isEmpty ? const _EmptyCatalog() : _RailAndGrid(catalog: c, onItemTap: onItemTap),
          ),
        ),
        // Offline/stale banner sits at the bottom of the grid area (p.7).
        if (sync is SyncFailed)
          _SyncBanner(
            message: sync.message,
            onRetry: () => ref.read(catalogSyncProvider.notifier).refresh(),
          ),
      ],
    );
  }
}

class _RailAndGrid extends ConsumerWidget {
  const _RailAndGrid({required this.catalog, required this.onItemTap});
  final Catalog catalog;
  final void Function(BuildContext, CatalogItem) onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = catalog.sections;
    final selectedId = ref.watch(selectedSectionIdProvider);
    final int index =
        sections.indexWhere((s) => s.id == selectedId).clamp(-1, sections.length - 1);
    final int current = index == -1 ? 0 : index;
    final section = sections[current];
    void select(String id) => ref.read(selectedSectionIdProvider.notifier).state = id;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _railBreakpoint;
        final grid = _ItemGrid(section: section, tint: _tintFor(current), onTap: (i) => onItemTap(context, i));

        if (wide) {
          // Vertical icon rail + titled grid (desktop/tablet — p.7).
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 104,
                child: _CategoryRail(sections: sections, selectedIndex: current, onSelect: select),
              ),
              const VerticalDivider(width: 1, color: _line),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _GridHeader(section: section),
                    Expanded(child: grid),
                  ],
                ),
              ),
            ],
          );
        }
        // Horizontal chip strip + grid (phone — p.4).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CategoryChips(sections: sections, selectedIndex: current, onSelect: select),
            const Divider(height: 1, color: _line),
            Expanded(child: grid),
          ],
        );
      },
    );
  }
}

/// Wide-screen header above the grid: "Hair · 8 items" (p.7).
class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.section});
  final CatalogSection section;

  @override
  Widget build(BuildContext context) {
    final n = section.items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(
            child: Text(
              section.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 22),
            ),
          ),
          const SizedBox(width: 12),
          Text('$n ${n == 1 ? 'item' : 'items'}',
              style: const TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.sections, required this.selectedIndex, required this.onSelect});
  final List<CatalogSection> sections;
  final int selectedIndex;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _rail,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sections.length,
        itemBuilder: (context, i) {
          final s = sections[i];
          final selected = i == selectedIndex;
          return InkWell(
            onTap: () => onSelect(s.id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? _tintFor(i) : Colors.transparent,
                border: Border(
                  left: BorderSide(color: selected ? _pink : Colors.transparent, width: 3),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Icon(_iconFor(s.kind), size: 22, color: selected ? _pink : _muted),
                  const SizedBox(height: 6),
                  Text(
                    s.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _ink : _muted,
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Narrow-screen horizontal category selector (p.4). Scrolls internally — never
/// causes the page itself to scroll horizontally.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.sections, required this.selectedIndex, required this.onSelect});
  final List<CatalogSection> sections;
  final int selectedIndex;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _rail,
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = sections[i];
          final selected = i == selectedIndex;
          return InkWell(
            onTap: () => onSelect(s.id),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _tintFor(i) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? _pink : _line, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(_iconFor(s.kind), size: 16, color: selected ? _pink : _muted),
                  const SizedBox(width: 7),
                  Text(
                    s.title,
                    style: TextStyle(
                      color: selected ? _ink : _muted,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.section, required this.tint, required this.onTap});
  final CatalogSection section;
  final Color tint;
  final void Function(CatalogItem) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 104,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: section.items.length,
      itemBuilder: (context, i) => _ItemTile(item: section.items[i], tint: tint, onTap: onTap),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.tint, required this.onTap});
  final CatalogItem item;
  final Color tint;
  final void Function(CatalogItem) onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.name}, ${formatCents(item.priceCents)}',
      child: Material(
        color: tint,
        elevation: 2,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onTap(item),
          borderRadius: BorderRadius.circular(14),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    item.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    formatCents(item.priceCents),
                    // Pink price to match the reference tiles (p.4 / p.7).
                    style: const TextStyle(color: _pink, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _amberBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: <Widget>[
              const Icon(Icons.wifi_off, color: _amber, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: const TextStyle(color: _ink, fontSize: 13))),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry',
                    style: TextStyle(color: _amber, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
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
