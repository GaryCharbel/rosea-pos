import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/staff/staff_member.dart';
import 'package:rosea_pos/features/staff/staff_repo.dart';

void main() {
  const StaffMember lea = StaffMember(id: '1', name: 'Lea');
  const StaffMember maya = StaffMember(id: '2', name: 'Maya');

  test('active performer is dropped when they leave the active set', () async {
    // staff_public is driven by a StateProvider so the test can "deactivate" Lea.
    final source = StateProvider<List<StaffMember>>((_) => <StaffMember>[lea, maya]);
    final container = ProviderContainer(
      overrides: <Override>[
        staffPublicProvider.overrideWith((ref) async => ref.watch(source)),
      ],
    );
    addTearDown(container.dispose);

    // Keep both providers alive so the controller's reconcile listener runs.
    container.listen(activeStaffProvider, (_, __) {});
    await container.read(staffPublicProvider.future);

    container.read(activeStaffProvider.notifier).select(lea);
    expect(container.read(activeStaffProvider), lea);

    // Lea is deactivated in the backoffice -> she falls out of staff_public.
    container.read(source.notifier).state = <StaffMember>[maya];
    await container.read(staffPublicProvider.future);
    await Future<void>.microtask(() {}); // flush the listener

    expect(container.read(activeStaffProvider), isNull,
        reason: 'an inactive performer must not stay selected');
  });

  test('active performer survives a refresh that still includes them', () async {
    final source = StateProvider<List<StaffMember>>((_) => <StaffMember>[lea, maya]);
    final container = ProviderContainer(
      overrides: <Override>[
        staffPublicProvider.overrideWith((ref) async => ref.watch(source)),
      ],
    );
    addTearDown(container.dispose);

    container.listen(activeStaffProvider, (_, __) {});
    await container.read(staffPublicProvider.future);
    container.read(activeStaffProvider.notifier).select(lea);

    // A refresh that still lists Lea (order changed) must not clear the selection.
    container.read(source.notifier).state = <StaffMember>[maya, lea];
    await container.read(staffPublicProvider.future);
    await Future<void>.microtask(() {});

    expect(container.read(activeStaffProvider), lea);
  });
}
