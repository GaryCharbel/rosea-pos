import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/catalog_repo.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/data/outbox_database.dart';
import 'package:rosea_pos/features/checkout/domain/pay_intent.dart';
import 'package:rosea_pos/features/checkout/pay_controller.dart';
import 'package:rosea_pos/features/checkout/pay_gateway.dart';
import 'package:rosea_pos/features/checkout/ui/checkout_screen.dart';
import 'package:rosea_pos/features/staff/staff_member.dart';
import 'package:rosea_pos/features/staff/staff_repo.dart';

/// Full-flow pair-test (Phase 5.2): drive the real checkout UI from tapping a catalog
/// item through the payment sheet to the receipt, with ONLY the server round-trip
/// faked (the PayGateway). The backend half — pay_ticket's commission/stock/idempotency
/// — is proven by the pgTAP suite in the rosea repo.
class _IdleSync extends CatalogSyncController {
  @override
  SyncStatus build() => const SyncIdle();
  @override
  Future<void> refresh() async {}
}

class _ActiveLea extends ActiveStaffController {
  @override
  StaffMember build() => const StaffMember(id: 'st1', name: 'Lea');
}

/// Captures the intent it was handed and returns a realistic receipt payload.
class _FakeGateway implements PayGateway {
  PayIntent? captured;
  @override
  Future<Map<String, dynamic>> submit(PayIntent intent) async {
    captured = intent;
    return <String, dynamic>{
      'ticket_no': 1001,
      'status': 'paid',
      'subtotal': '50.00',
      'discount_total': '0.00',
      'total': '50.00',
      'tip_total': '0',
      'salon': {'name': 'Rosea', 'currency': 'USD'},
      'lines': <dynamic>[
        {'name': "Women's Cut", 'line_type': 'service', 'performer_name': 'Lea', 'qty': 1, 'line_total': '50.00'}
      ],
      'payments': <dynamic>[
        {'method': 'cash', 'amount': '50.00'}
      ],
      'tips': <dynamic>[],
    };
  }
}

const _catalog = Catalog([
  CatalogSection(title: 'Hair', kind: CatalogKind.service, items: [
    CatalogItem(id: 'svc1', name: "Women's Cut", priceCents: 5000, kind: CatalogKind.service),
  ]),
]);

void main() {
  testWidgets('catalog tap → ticket → pay → receipt → ticket cleared', (tester) async {
    // Wide surface so the ticket panel is inline (not the narrow bottom bar).
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _FakeGateway();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogProvider.overrideWith((ref) => Stream.value(_catalog)),
        catalogSyncProvider.overrideWith(_IdleSync.new),
        activeStaffProvider.overrideWith(_ActiveLea.new),
        payGatewayProvider.overrideWithValue(gateway),
        outboxDatabaseProvider.overrideWith((ref) {
          final db = OutboxDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const MaterialApp(home: CheckoutScreen()),
    ));
    await tester.pumpAndSettle();

    // 1. ring up the service
    await tester.tap(find.text("Women's Cut").first);
    await tester.pumpAndSettle();
    expect(find.text('50.00'), findsWidgets); // ticket total

    // 2. open the payment sheet
    await tester.tap(find.widgetWithText(FilledButton, 'Payment'));
    await tester.pumpAndSettle();
    expect(find.text('Remaining'), findsOneWidget);

    // 3. tender exact cash -> settled
    await tester.tap(find.text('Cash 50.00'));
    await tester.pumpAndSettle();
    expect(find.text('Settled'), findsOneWidget);

    // 4. take payment -> fake gateway -> receipt
    await tester.tap(find.widgetWithText(FilledButton, 'Take payment'));
    await tester.pumpAndSettle();
    expect(find.text('Receipt #1001'), findsOneWidget);
    expect(gateway.captured, isNotNull);
    expect(gateway.captured!.totalCents, 5000);
    expect(gateway.captured!.openedByStaffId, 'st1');

    // 5. done -> ticket cleared
    await tester.tap(find.text('Done — new ticket'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap services or products'), findsOneWidget);
  });
}
