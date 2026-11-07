import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/checkout_controller.dart';
import 'package:rosea_pos/features/staff/staff_member.dart';

const _cut = CatalogItem(id: 'svc1', name: 'Cut', priceCents: 5000, kind: CatalogKind.service);
const _shampoo =
    CatalogItem(id: 'prd1', name: 'Shampoo', priceCents: 2000, kind: CatalogKind.product);
const _lea = StaffMember(id: 'st1', name: 'Lea');
const _maya = StaffMember(id: 'st2', name: 'Maya');

void main() {
  late ProviderContainer c;
  CheckoutDraftController ctrl() => c.read(checkoutDraftProvider.notifier);
  int total() => c.read(checkoutDraftProvider).totalCents;

  setUp(() => c = ProviderContainer());
  tearDown(() => c.dispose());

  test('adding the same item + performer bumps qty; a different performer makes a new line', () {
    ctrl().addItem(_cut, _lea);
    ctrl().addItem(_cut, _lea); // same -> qty 2
    expect(c.read(checkoutDraftProvider).lines.single.qty, 2);

    ctrl().addItem(_cut, _maya); // different performer -> new line
    final lines = c.read(checkoutDraftProvider).lines;
    expect(lines.length, 2);
    expect(lines[1].performerName, 'Maya');
    expect(total(), 5000 * 3);
  });

  test('setQty of 0 removes the line; decrement past 1 removes it', () {
    ctrl().addItem(_cut, _lea);
    final id = c.read(checkoutDraftProvider).lines.single.id;
    ctrl().setQty(id, 0);
    expect(c.read(checkoutDraftProvider).isEmpty, isTrue);

    ctrl().addItem(_shampoo, _lea);
    final id2 = c.read(checkoutDraftProvider).lines.single.id;
    ctrl().decrement(id2);
    expect(c.read(checkoutDraftProvider).isEmpty, isTrue);
  });

  test('line discount is clamped into [0, gross], and re-clamped when qty drops', () {
    ctrl().addItem(_cut, _lea); // unit 5000, qty 1, gross 5000
    final id = c.read(checkoutDraftProvider).lines.single.id;

    ctrl().setLineDiscountCents(id, 999999); // clamp to gross
    expect(c.read(checkoutDraftProvider).lines.single.lineDiscountCents, 5000);
    expect(total(), 0);

    ctrl().increment(id); // qty 2, gross 10000 — discount stays 5000
    expect(total(), 5000);

    ctrl().setLineDiscountCents(id, 8000); // qty 2 gross 10000 -> allowed
    ctrl().setQty(id, 1); // gross back to 5000 -> discount re-clamped to 5000
    expect(c.read(checkoutDraftProvider).lines.single.lineDiscountCents, 5000);

    ctrl().setLineDiscountCents(id, -50); // negative -> 0
    expect(c.read(checkoutDraftProvider).lines.single.lineDiscountCents, 0);
  });

  test('reassigning a line performer keeps everything else', () {
    ctrl().addItem(_cut, _lea);
    final id = c.read(checkoutDraftProvider).lines.single.id;
    ctrl().setLinePerformer(id, _maya);
    final line = c.read(checkoutDraftProvider).lines.single;
    expect(line.performerStaffId, 'st2');
    expect(line.performerName, 'Maya');
    expect(line.qty, 1);
  });

  test('clear empties the draft', () {
    ctrl().addItem(_cut, _lea);
    ctrl().addItem(_shampoo, _maya);
    ctrl().clear();
    expect(c.read(checkoutDraftProvider).isEmpty, isTrue);
  });
}
