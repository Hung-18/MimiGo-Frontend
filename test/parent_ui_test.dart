import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/po/parent_ui.dart';

void main() {
  testWidgets('PinDots shows only the count of typed digits', (t) async {
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: PinDots(filled: 3))),
    );
    expect(find.byType(Container), findsNWidgets(6));
    final dots = t
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration).color != Colors.transparent)
        .toList();
    expect(dots, [true, true, true, false, false, false]);
  });
}
