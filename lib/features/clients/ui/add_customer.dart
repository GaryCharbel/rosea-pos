import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../checkout/checkout_controller.dart';
import '../client.dart';
import '../client_repo.dart';

const _panel = Color(0xFF141019);
const _card = Color(0xFF1A141F);
const _field = Color(0xFF211826);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _pink = Color(0xFFED3D8C);
const _line = Color(0xFF2E2333);

/// Per-person avatar tints (initials on a colour disc, like the performer list p.6).
const List<Color> _avatarTints = <Color>[
  Color(0xFF7A3B52), // plum-pink
  Color(0xFF4A3A6E), // indigo
  Color(0xFF2E5A63), // teal
  Color(0xFF6E5A2E), // gold-brown
  Color(0xFF3A6E4A), // green
];
// A stable hash of the id — String.hashCode isn't guaranteed stable across runs or
// platforms, so a client would otherwise change avatar colour between launches.
int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

Color _avatarColor(String id) => _avatarTints[_stableHash(id) % _avatarTints.length];

/// Round initials avatar for a client.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar({super.key, required this.client, this.size = 40});
  final Client client;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _avatarColor(client.id), shape: BoxShape.circle),
      child: Text(
        client.initials,
        style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: size * 0.36),
      ),
    );
  }
}

/// The attach-a-customer row under the ticket header: an "Add customer" button
/// (p.7) or, once attached, a chip with the name + change/remove.
class AddCustomerBar extends ConsumerWidget {
  const AddCustomerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(checkoutDraftProvider.select((d) => d.client));

    if (client == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _pink.withValues(alpha: 0.55), width: 1.4),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add, size: 18, color: _pink),
                SizedBox(width: 8),
                Text('Add customer',
                    style: TextStyle(color: _pink, fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: <Widget>[
              ClientAvatar(client: client, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(client.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _ink, fontWeight: FontWeight.w700, fontSize: 14)),
                    if (client.phone != null && client.phone!.isNotEmpty)
                      Text(client.phone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _open(context, ref),
                child: const Text('Change',
                    style: TextStyle(color: _pink, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.read(checkoutDraftProvider.notifier).clearClient(),
                icon: const Icon(Icons.close, size: 18, color: _muted),
                tooltip: 'Remove customer',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final chosen = await showModalBottomSheet<Client>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      builder: (ctx) => const AddCustomerSheet(),
    );
    if (chosen != null) {
      ref.read(checkoutDraftProvider.notifier).setClient(chosen);
    }
  }
}

/// Search existing clients or quick-add a new one (p.12). Returns the chosen/created
/// [Client] via Navigator.pop.
class AddCustomerSheet extends ConsumerStatefulWidget {
  const AddCustomerSheet({super.key});

  @override
  ConsumerState<AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends ConsumerState<AddCustomerSheet> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  late Future<List<Client>> _results;
  Timer? _debounce;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _results = ref.read(clientRepoProvider).search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Debounced so a request doesn't fire on every keystroke (and the search term
  /// doesn't hit the network more than it must).
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  void _runSearch(String q) {
    if (mounted) setState(() => _results = ref.read(clientRepoProvider).search(q));
  }

  Future<void> _quickAdd() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _saveError = "Enter the client's name to add them.");
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final created =
          await ref.read(clientRepoProvider).quickAdd(name: name, phone: _phone.text);
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          // Actionable + specific to the real failure (permission vs network vs other)
          // instead of always blaming the connection.
          _saveError = mapDataError(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: <Widget>[
                    const Text('Add customer',
                        style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: _muted),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: _ink),
                  decoration: InputDecoration(
                    hintText: 'Search clients',
                    hintStyle: const TextStyle(color: _muted),
                    prefixIcon: const Icon(Icons.search, color: _muted),
                    filled: true,
                    fillColor: _field,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _pink)),
                  ),
                ),
              ),
              const Divider(height: 1, color: _line),
              Flexible(child: _resultsList()),
              const Divider(height: 1, color: _line),
              _quickAddCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultsList() {
    return FutureBuilder<List<Client>>(
      future: _results,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(color: _pink)),
          );
        }
        if (snap.hasError) {
          final err = mapDataError(snap.error!);
          return _message(
            err.message,
            // Only offer a retry when retrying could actually help (not for a
            // permission denial, where re-running the same query won't).
            action: err is AuthError ? null : ('Try again', () => _runSearch(_search.text)),
          );
        }
        final list = snap.data ?? const <Client>[];
        if (list.isEmpty) {
          return _message(
            _search.text.trim().isEmpty
                ? 'No clients yet — quick-add one below.'
                : 'No matches for "${_search.text.trim()}" — quick-add below.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: _line, indent: 64),
          itemBuilder: (context, i) {
            final c = list[i];
            return ListTile(
              leading: ClientAvatar(client: c),
              title: Text(c.name, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
              subtitle: (c.phone != null && c.phone!.isNotEmpty)
                  ? Text(c.phone!, style: const TextStyle(color: _muted))
                  : null,
              trailing: const Icon(Icons.chevron_right, color: _muted),
              onTap: () => Navigator.of(context).pop(c),
            );
          },
        );
      },
    );
  }

  Widget _quickAddCard() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.add, size: 18, color: _pink),
              SizedBox(width: 8),
              Text('Quick-add a new client',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                  child: _miniField(_name, 'Full name', TextInputType.name,
                      key: const Key('qa-name'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _miniField(_phone, '+961 …', TextInputType.phone,
                      key: const Key('qa-phone'))),
            ],
          ),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_saveError!, style: const TextStyle(color: _pink, fontSize: 12.5)),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _pink,
                disabledBackgroundColor: const Color(0xFF3A2430),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _quickAdd,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: _ink))
                  : const Text('Save & add to ticket',
                      style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniField(TextEditingController c, String hint, TextInputType type, {Key? key}) {
    return TextField(
      key: key,
      controller: c,
      keyboardType: type,
      style: const TextStyle(color: _ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: _muted),
        filled: true,
        fillColor: _field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _pink)),
      ),
    );
  }

  Widget _message(String text, {(String, VoidCallback)? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
            if (action != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: action.$2,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: _pink)),
                child: Text(action.$1,
                    style: const TextStyle(color: _pink, fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
