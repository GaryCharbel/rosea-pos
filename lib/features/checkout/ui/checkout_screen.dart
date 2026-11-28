import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../auth/session_controller.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/ui/catalog_grid_view.dart';
import '../../staff/staff_repo.dart';
import '../checkout_controller.dart';
import 'ticket_panel.dart';

const _bg = Color(0xFF0C0A0F);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _line = Color(0xFF2E2333);

/// The checkout surface: the catalog grid plus the ticket panel. Wide screens
/// (desktop/tablet) show them side by side; narrow screens show the grid with a
/// bottom bar that opens the ticket as a sheet.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  static const double _wideBreakpoint = 820;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeStaffProvider);
    final session = ref.watch(sessionProvider);
    final isOwner = session is Authenticated && session.isOwner;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: <Widget>[
          // The sales screen is home; everything else lives here as options.
          TextButton.icon(
            onPressed: () => context.push('/performer'),
            icon: const Icon(Icons.badge_outlined, size: 18, color: _pink),
            label: Text(
              active == null ? 'Choose performer' : active.name,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _ink),
            color: const Color(0xFF1A141F),
            onSelected: (v) {
              switch (v) {
                case 'cashup':
                  context.push('/cashup');
                case 'signout':
                  ref.read(sessionProvider.notifier).signOut();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              if (isOwner)
                const PopupMenuItem<String>(
                  value: 'cashup',
                  child: Text('Cash-up & commission', style: TextStyle(color: _ink)),
                ),
              const PopupMenuItem<String>(
                value: 'signout',
                child: Text('Sign out', style: TextStyle(color: _ink)),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final grid = CatalogGridView(
            onItemTap: (ctx, item) => _addToTicket(ctx, ref, item),
          );
          if (constraints.maxWidth >= _wideBreakpoint) {
            return Row(
              children: <Widget>[
                Expanded(child: grid),
                const VerticalDivider(width: 1, color: _line),
                const SizedBox(width: 380, child: TicketPanel()),
              ],
            );
          }
          return Column(
            children: <Widget>[
              Expanded(child: grid),
              const _TicketBottomBar(),
            ],
          );
        },
      ),
    );
  }

  void _addToTicket(BuildContext context, WidgetRef ref, CatalogItem item) {
    final performer = ref.read(activeStaffProvider);
    if (performer == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF1A141F),
          content: const Text('Choose a performer before ringing up.',
              style: TextStyle(color: _ink)),
          action: SnackBarAction(
            label: 'Choose',
            textColor: _pink,
            onPressed: () => context.push('/performer'),
          ),
        ));
      return;
    }
    ref.read(checkoutDraftProvider.notifier).addItem(item, performer);
  }
}

/// Narrow-screen summary bar; tapping opens the ticket panel as a full-height sheet.
class _TicketBottomBar extends ConsumerWidget {
  const _TicketBottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(checkoutDraftProvider);
    return Material(
      color: const Color(0xFF141019),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: draft.isEmpty ? null : () => _openTicket(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: <Widget>[
                const Icon(Icons.receipt_long, color: _pink),
                const SizedBox(width: 10),
                Text(
                  draft.isEmpty
                      ? 'No items yet'
                      : '${draft.lineCount} ${draft.lineCount == 1 ? 'line' : 'lines'}',
                  style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(formatCents(draft.totalCents),
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 18)),
                if (!draft.isEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_up, color: _muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTicket(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: TicketPanel(onClose: () => Navigator.of(ctx).pop()),
        ),
      ),
    );
  }
}
