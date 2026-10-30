import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rosea_pos/main.dart';

void main() {
  testWidgets('shows the Rosea POS placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const RoseaPosApp());
    expect(find.text('Rosea POS'), findsOneWidget);
  });
}
