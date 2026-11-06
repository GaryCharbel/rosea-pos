/// A staff member as seen by the POS — sourced from the cashier-safe `staff_public`
/// view (id / name / title / active). Rates and commission are NEVER exposed here.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    this.title,
    this.active = true,
  });

  final String id;
  final String name;
  final String? title;
  final bool active;

  factory StaffMember.fromMap(Map<String, dynamic> m) => StaffMember(
        id: m['id'] as String,
        name: m['name'] as String,
        title: m['title'] as String?,
        active: (m['active'] as bool?) ?? true,
      );

  @override
  bool operator ==(Object other) => other is StaffMember && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
