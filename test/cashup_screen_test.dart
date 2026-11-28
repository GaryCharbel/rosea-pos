import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/auth/session_controller.dart';
import 'package:rosea_pos/features/reports/cashup_repo.dart';
import 'package:rosea_pos/features/reports/domain/cashup.dart';
import 'package:rosea_pos/features/reports/ui/cashup_screen.dart';

class _OwnerSession extends SessionController {
  @override
  SessionState build() => const Authenticated(userId: 'u1', role: 'owner');
}

class _StaffSession extends SessionController {
  @override
  SessionState build() => const Authenticated(userId: 'u2', role: 'staff', staffId: 's1');
}

final _cashUp = const CashUp(
  commissionByStaff: [StaffCommission(staffName: 'Lea', amountCents: 5000)],
  takingsByMethod: {'cash': 5000},
  tipTotalCents: 1000,
);

void main() {
  testWidgets('owner sees takings + commission', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_OwnerSession.new),
        cashUpProvider.overrideWith((ref) async => _cashUp),
      ],
      child: const MaterialApp(home: CashUpScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('GROSS TAKINGS'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Lea'), findsOneWidget);
    expect(find.text('Total commission'), findsOneWidget);
  });

  testWidgets('shows the Tips KPI and a takings bar across methods', (tester) async {
    const multi = CashUp(
      commissionByStaff: [StaffCommission(staffName: 'Lea', amountCents: 5000)],
      takingsByMethod: {'cash': 6000, 'card': 4000},
      tipTotalCents: 1500,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_OwnerSession.new),
        cashUpProvider.overrideWith((ref) async => multi),
      ],
      child: const MaterialApp(home: CashUpScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TIPS'), findsOneWidget); // the Tips KPI card
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    // The takings bar sizes itself against the sum of the shown methods — no crash.
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-owner is gated out', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionProvider.overrideWith(_StaffSession.new)],
      child: const MaterialApp(home: CashUpScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('for the salon owner'), findsOneWidget);
  });
}
