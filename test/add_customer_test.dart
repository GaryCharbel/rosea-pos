import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/checkout_controller.dart';
import 'package:rosea_pos/features/checkout/domain/pay_intent.dart';
import 'package:rosea_pos/features/clients/client.dart';
import 'package:rosea_pos/features/clients/client_repo.dart';
import 'package:rosea_pos/features/clients/ui/add_customer.dart';
import 'package:rosea_pos/features/staff/staff_member.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory ClientRepo so the picker is driven without Supabase.
class _FakeClientRepo implements ClientRepo {
  _FakeClientRepo(this.clients);
  List<Client> clients;

  @override
  Future<List<Client>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return clients;
    return clients
        .where((c) => c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(query.trim()))
        .toList();
  }

  @override
  Future<Client> quickAdd({required String name, String? phone}) async {
    final c = Client(id: 'new-${clients.length}', name: name.trim(), phone: phone);
    clients = <Client>[...clients, c];
    return c;
  }
}

/// A repo whose calls always throw, to drive the error states.
class _ThrowingClientRepo implements ClientRepo {
  _ThrowingClientRepo(this.error);
  final Object error;
  @override
  Future<List<Client>> search(String query) async => throw error;
  @override
  Future<Client> quickAdd({required String name, String? phone}) async => throw error;
}

Widget _host({required List<Override> overrides, required Widget child}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  const rania = Client(id: 'c1', name: 'Rania Abou Jaoude', phone: '+961 3 412 889');
  const randa = Client(id: 'c2', name: 'Randa Khalil', phone: '+961 70 118 204');

  test('draft carries the client through line edits and clears it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctrl = container.read(checkoutDraftProvider.notifier);

    ctrl.setClient(rania);
    ctrl.addItem(
      const CatalogItem(id: 's1', name: "Women's Cut", priceCents: 4500, kind: CatalogKind.service),
      const StaffMember(id: 'st1', name: 'Maya'),
    );
    // Adding a line must not drop the attached client.
    expect(container.read(checkoutDraftProvider).client, rania);

    ctrl.clearClient();
    expect(container.read(checkoutDraftProvider).client, isNull);

    ctrl.setClient(rania);
    ctrl.clear(); // full reset also drops the client
    expect(container.read(checkoutDraftProvider).client, isNull);
  });

  test('PayIntent carries client_id through encode/decode (and null for walk-ins)', () {
    const withClient = PayIntent(
      clientTx: 'tx1',
      openedByStaffId: 'st1',
      totalCents: 4500,
      clientId: 'c1',
      lines: <PayLine>[],
      payments: <PayTender>[],
      tips: <PayTip>[],
    );
    expect(PayIntent.decode(withClient.encode()).clientId, 'c1');

    const walkIn = PayIntent(
      clientTx: 'tx2',
      openedByStaffId: 'st1',
      totalCents: 0,
      lines: <PayLine>[],
      payments: <PayTender>[],
      tips: <PayTip>[],
    );
    expect(walkIn.toJson().containsKey('client_id'), isFalse);
    expect(PayIntent.decode(walkIn.encode()).clientId, isNull);
  });

  testWidgets('bar opens the picker and selecting a client attaches it', (tester) async {
    await tester.pumpWidget(_host(
      overrides: [
        clientRepoProvider.overrideWithValue(_FakeClientRepo(<Client>[rania, randa])),
      ],
      child: const AddCustomerBar(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Add customer'), findsOneWidget);

    await tester.tap(find.text('Add customer'));
    await tester.pumpAndSettle();

    // Sheet lists the seeded clients.
    expect(find.text('Rania Abou Jaoude'), findsOneWidget);
    expect(find.text('Randa Khalil'), findsOneWidget);

    await tester.tap(find.text('Randa Khalil'));
    await tester.pumpAndSettle();

    // Bar now shows the attached client, and the "Add customer" CTA is gone.
    expect(find.text('Randa Khalil'), findsOneWidget);
    expect(find.text('Add customer'), findsNothing);
  });

  testWidgets('quick-add creates a client and attaches it', (tester) async {
    await tester.pumpWidget(_host(
      overrides: [
        clientRepoProvider.overrideWithValue(_FakeClientRepo(<Client>[])),
      ],
      child: const AddCustomerBar(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add customer'));
    await tester.pumpAndSettle();

    // Empty search → actionable empty state pointing at quick-add.
    expect(find.textContaining('quick-add'), findsWidgets);

    await tester.enterText(find.byKey(const Key('qa-name')), 'Françoise Mattar');
    await tester.tap(find.text('Save & add to ticket'));
    await tester.pumpAndSettle();

    expect(find.text('Françoise Mattar'), findsOneWidget);
    expect(find.text('Add customer'), findsNothing);
  });

  testWidgets('a permission error is actionable and offers no retry', (tester) async {
    await tester.pumpWidget(_host(
      overrides: [
        clientRepoProvider.overrideWithValue(
            _ThrowingClientRepo(const PostgrestException(message: 'denied', code: '42501'))),
      ],
      child: const AddCustomerSheet(),
    ));
    await tester.pumpAndSettle();
    // RLS denial → tells them to sign in as staff; retrying wouldn't help, so no retry.
    expect(find.textContaining('staff account'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a network error shows connection copy and a retry', (tester) async {
    await tester.pumpWidget(_host(
      overrides: [
        clientRepoProvider
            .overrideWithValue(_ThrowingClientRepo(Exception('SocketException: host lookup'))),
      ],
      child: const AddCustomerSheet(),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('internet connection'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('quick-add without a name shows an actionable message', (tester) async {
    await tester.pumpWidget(_host(
      overrides: [
        clientRepoProvider.overrideWithValue(_FakeClientRepo(<Client>[])),
      ],
      child: const AddCustomerBar(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add customer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save & add to ticket'));
    await tester.pumpAndSettle();
    // Sheet stays open with an actionable validation message.
    expect(find.textContaining("Enter the client's name"), findsOneWidget);
    expect(find.text('Save & add to ticket'), findsOneWidget);
  });
}
