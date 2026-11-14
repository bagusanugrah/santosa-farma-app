import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Santosa Farma POS smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Santosa Farma POS'),
        ),
      ),
    );

    expect(find.text('Santosa Farma POS'), findsOneWidget);
  });
}
