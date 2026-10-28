import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/customer_preview.dart';

void main() {
  testWidgets(
      'empty customer catalogue has browsable examples without ordering',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: CustomerPreview())));
    await tester.scrollUntilVisible(find.text('Bakery Surprise Bag'), 180);
    await tester.tap(find.text('Bakery Surprise Bag'));
    await tester.pumpAndSettle();
    expect(find.text('Food preview'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('It cannot be reserved.'), 200);
    expect(find.textContaining('It cannot be reserved.'), findsOneWidget);
    expect(find.textContaining('Reserve ·'), findsNothing);
    await tester.scrollUntilVisible(find.text('Back to Explore'), 180);
    await tester.tap(find.text('Back to Explore'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerPreview), findsOneWidget);
  });
  testWidgets('preview respects customer search and category selection',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: CustomerPreview(category: 'Meals', search: 'lunch'))));
    await tester.scrollUntilVisible(find.text('Cafe Lunch Box'), 180);
    expect(find.text('Cafe Lunch Box'), findsOneWidget);
    expect(find.text('Bakery Surprise Bag'), findsNothing);
  });
}
