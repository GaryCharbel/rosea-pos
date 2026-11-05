import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'staff_member.dart';

/// Active staff for the performer picker, read from the cashier-safe `staff_public`
/// view (id/name/title/active — never rates). Inactive staff are filtered out, so
/// they can't be selected. (The Drift read-through cache arrives in Phase 4.)
final staffPublicProvider = FutureProvider<List<StaffMember>>((ref) async {
  final List<Map<String, dynamic>> rows = await Supabase.instance.client
      .from('staff_public')
      .select('id, name, title, active')
      .eq('active', true)
      .order('name');
  return rows.map(StaffMember.fromMap).toList();
});

/// The performer credited on new ticket lines. Per-line overrides happen at ring-up
/// (Phase 4); this is the default chosen from the picker.
class ActiveStaffController extends Notifier<StaffMember?> {
  @override
  StaffMember? build() => null;

  void select(StaffMember staff) => state = staff;

  void clear() => state = null;
}

final activeStaffProvider =
    NotifierProvider<ActiveStaffController, StaffMember?>(ActiveStaffController.new);
