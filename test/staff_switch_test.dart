import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/staff/staff_member.dart';
import 'package:rosea_pos/features/staff/staff_repo.dart';
import 'package:rosea_pos/features/staff/ui/staff_switch_screen.dart';

void main() {
  const StaffMember lea = StaffMember(id: '1', name: 'Lea', title: 'Senior Stylist');
  const StaffMember maya = StaffMember(id: '2', name: 'Maya');

  testWidgets('picker lists active staff and selects one on tap', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          staffPublicProvider.overrideWith((_) async => <StaffMember>[lea, maya]),
        ],
        child: const MaterialApp(home: StaffSwitchScreen()),
      ),
    );
    await tester.pumpAndSettle(); // resolve the FutureProvider

    expect(find.text('Lea'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing); // nothing selected yet

    await tester.tap(find.text('Lea'));
    await tester.pumpAndSettle();

    // Lea is now the active performer -> her tile shows the selected check.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
