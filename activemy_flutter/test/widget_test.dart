import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Dummy smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('ActiveMY'),
        ),
      ),
    );
    expect(find.text('ActiveMY'), findsOneWidget);
  });
}

