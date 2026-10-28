import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/main.dart';

void main() {
  testWidgets('student reserves a meal and vendor collects it once',
      (tester) async {
    await tester.pumpWidget(const FoodieNomsApp());
    await tester.scrollUntilVisible(find.text('Bakery Surprise Bag'), 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last);
    await tester.tap(find.text('Bakery Surprise Bag'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reserve · RM 8.00'), 300,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last);
    await tester.tap(find.text('Reserve · RM 8.00'));
    await tester.pumpAndSettle();
    expect(find.text('Pickup reserved!'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Pickups'));
    await tester.pumpAndSettle();
    expect(find.text('FN-10001'), findsOneWidget);
    expect(find.text('RESERVED'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vendor demo').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Pickup code (e.g. FN-10001)'), 300,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last);
    await tester.enterText(find.byType(TextField).last, 'FN-10001');
    await tester.ensureVisible(find.text('Verify collection'));
    await tester.tap(find.text('Verify collection'));
    await tester.pumpAndSettle();
    expect(find.text('Pickup confirmed.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify collection'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid or already-used pickup code.'), findsOneWidget);
  });

  testWidgets('search and category filters combine', (tester) async {
    await tester.pumpWidget(const FoodieNomsApp());
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'no matching meal');
    await tester.pumpAndSettle();
    expect(find.text('No meals match yet. Try another search or category.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Meals'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cafe Lunch Box'), 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last);
    expect(find.text('Cafe Lunch Box'), findsOneWidget);
    expect(find.text('Bakery Surprise Bag'), findsNothing);
  });
}
