import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/student_experience.dart';
import 'package:foodienoms/firebase/customer_preview.dart';

Map<String, dynamic> pickup(DateTime start, DateTime end) => {
      'pickupStart': start.millisecondsSinceEpoch,
      'pickupEnd': end.millisecondsSinceEpoch,
    };
void main() {
  test('pickup labels handle today, tomorrow, midnight and year boundaries',
      () {
    final now = DateTime(2026, 12, 31, 12);
    expect(
        friendlyPickupWindow(
            pickup(DateTime(2026, 12, 31, 17), DateTime(2026, 12, 31, 19)),
            now: now),
        'Today, 5:00 PM – 7:00 PM');
    expect(
        friendlyPickupWindow(
            pickup(DateTime(2027, 1, 1, 0), DateTime(2027, 1, 1, 12)),
            now: now),
        'Tomorrow, 12:00 AM – 12:00 PM');
    expect(
        friendlyPickupWindow(
            pickup(DateTime(2026, 12, 31, 23), DateTime(2027, 1, 1, 1)),
            now: now),
        'Today, 11:00 PM – Tomorrow, 1:00 AM');
    expect(
        friendlyPickupWindow(
            pickup(DateTime(2027, 1, 3, 10), DateTime(2027, 1, 3, 11)),
            now: now),
        '3 Jan 2027, 10:00 AM – 11:00 AM');
  });
  test('reservation allowance tracks held items without going below zero', () {
    expect(remainingReservationAllowance(0), 5);
    expect(remainingReservationAllowance(2), 3);
    expect(remainingReservationAllowance(5), 0);
    expect(remainingReservationAllowance(7), 0);
  });
  testWidgets('directions encode the exact address and report launch failure',
      (tester) async {
    Uri? launched;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DirectionsButton(
                address: '12 A&B Street, Subang Jaya',
                openUri: (uri) async {
                  launched = uri;
                  return false;
                }))));
    await tester.tap(find.text('Open directions'));
    await tester.pumpAndSettle();
    expect(launched!.scheme, 'https');
    expect(launched!.queryParameters['daddr'], '12 A&B Street, Subang Jaya');
    expect(find.text('Unable to open Maps. Use the pickup address above.'),
        findsOneWidget);
  });
  testWidgets('directions use the saved pickup coordinates when provided',
      (tester) async {
    Uri? launched;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DirectionsButton(
                address: '12 Jalan SS15, Subang Jaya',
                latitude: 3.075,
                longitude: 101.59,
                openUri: (uri) async {
                  launched = uri;
                  return true;
                }))));
    await tester.tap(find.text('Open directions'));
    expect(launched!.queryParameters['daddr'], '3.075,101.59');
  });
  testWidgets('order tabs switch between all three statuses on a narrow screen',
      (tester) async {
    var selected = 'reserved';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => OrderStatusTabs(
                    selected: selected,
                    onSelected: (value) =>
                        setState(() => selected = value))))));
    await tester.tap(find.text('Collected'));
    await tester.pumpAndSettle();
    expect(selected, 'collected');
    await tester.ensureVisible(find.text('Cancelled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(selected, 'cancelled');
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(selected, 'reserved');
  });
  testWidgets('empty orders offer an action to browse food', (tester) async {
    var browsed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StudentEmptyState(
                title: 'No orders yet',
                message: 'Find your first deal.',
                actionLabel: 'Browse food',
                onAction: () => browsed = true))));
    await tester.tap(find.text('Browse food'));
    expect(browsed, isTrue);
  });
  testWidgets('empty catalogue filters offer a clear action', (tester) async {
    var cleared = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CustomerPreview(
                search: 'no-such-food',
                onClearFilters: () => cleared = true))));
    await tester.tap(find.text('Clear filters'));
    expect(cleared, isTrue);
    expect(
        find.text('No preview examples match. Try another search or category.'),
        findsOneWidget);
  });
}
