import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/staff/staff_member.dart';

void main() {
  group('StaffMember', () {
    test('fromMap maps id / name / title / active', () {
      final s = StaffMember.fromMap(
        <String, dynamic>{'id': 'x', 'name': 'Lea', 'title': 'Senior', 'active': true},
      );
      expect(s.id, 'x');
      expect(s.name, 'Lea');
      expect(s.title, 'Senior');
      expect(s.active, isTrue);
    });

    test('active defaults to true and title is optional', () {
      final s = StaffMember.fromMap(<String, dynamic>{'id': 'x', 'name': 'Lea'});
      expect(s.active, isTrue);
      expect(s.title, isNull);
    });

    test('equality is by id', () {
      expect(const StaffMember(id: '1', name: 'A'), const StaffMember(id: '1', name: 'B'));
      expect(const StaffMember(id: '1', name: 'A'), isNot(const StaffMember(id: '2', name: 'A')));
    });
  });
}
