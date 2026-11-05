import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../staff_member.dart';
import '../staff_repo.dart';

/// Pick the active performer from the (active-only) `staff_public` list. No PIN in
/// Stage 1 — the signed-in account is the writer of record; this just sets who gets
/// credited on new lines. The chosen performer defaults onto subsequent lines.
class StaffSwitchScreen extends ConsumerWidget {
  const StaffSwitchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StaffMember>> staff = ref.watch(staffPublicProvider);
    final StaffMember? active = ref.watch(activeStaffProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0A0F),
        foregroundColor: const Color(0xFFF5EDF1),
        title: const Text("Who's serving?", style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: staff.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFED3D8C)),
        ),
        error: (Object e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Couldn't load the team. Check your connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB8A9B0)),
            ),
          ),
        ),
        data: (List<StaffMember> list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No active staff yet. Add them in the backoffice first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB8A9B0)),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int i) {
              final StaffMember s = list[i];
              final bool selected = s == active;
              return Material(
                color: selected ? const Color(0xFF2A1420) : const Color(0xFF1A141F),
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: selected
                        ? const BorderSide(color: Color(0xFFED3D8C), width: 1.5)
                        : BorderSide.none,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFED3D8C),
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  title: Text(
                    s.name,
                    style: const TextStyle(
                      color: Color(0xFFF5EDF1),
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: s.title == null
                      ? null
                      : Text(s.title!, style: const TextStyle(color: Color(0xFFB8A9B0))),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: Color(0xFFED3D8C))
                      : null,
                  onTap: () {
                    ref.read(activeStaffProvider.notifier).select(s);
                    Navigator.of(context).maybePop();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
