import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/vendor_ui.dart';

Map<String, dynamic> food({bool ended = false}) => {
      'title': 'Nasi Lemak Ayam Crispy',
      'category': 'Meals',
      'priceCents': 890,
      'active': true,
      'stock': 8,
      'address': 'SS15, Subang Jaya',
      'pickupStart': DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch,
      'pickupEnd': DateTime.now()
          .add(Duration(hours: ended ? -1 : 2))
          .millisecondsSinceEpoch,
    };
Widget page(Future<void> Function() remove,
        {bool ended = false, bool busy = false}) =>
    MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: VendorListingCard(
                    listing: food(ended: ended),
                    photo: const ColoredBox(color: Colors.green),
                    onEdit: () {},
                    onToggle: () {},
                    onAdjust: (_) {},
                    onRemove: remove,
                    busy: busy))));
Finder action() => find.byKey(const ValueKey('remove-listing-action'));
Finder confirm() => find.byKey(const ValueKey('remove-listing-confirm'));
Future<void> open(WidgetTester t) async {
  await t.ensureVisible(action());
  await t.tap(action());
  await t.pumpAndSettle();
}

void main() {
  test(
      'removed records are distinct and excluded even while the server timestamp is pending',
      () {
    expect(vendorListingRemoved(food()), isFalse);
    for (final removedAt in [DateTime.now(), null]) {
      final item = {...food(), 'active': false, 'removedAt': removedAt};
      expect(vendorListingRemoved(item), isTrue);
      expect(vendorListingStatus(item), 'Removed');
    }
  });
  for (final ended in [false, true]) {
    testWidgets(
        'remove is available on ${ended ? 'expired' : 'active'} listings and confirmation can be cancelled',
        (t) async {
      var calls = 0;
      await t.pumpWidget(page(() async {
        calls++;
      }, ended: ended));
      await open(t);
      expect(find.text('Remove this listing?'), findsOneWidget);
      expect(find.textContaining('Existing reservations stay in Pickups'),
          findsOneWidget);
      expect(calls, 0);
      await t.tap(find.text('Keep listing'));
      await t.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Nasi Lemak Ayam Crispy'), findsOneWidget);
    });
  }
  testWidgets(
      'confirmation calls removal once and prevents duplicate taps while saving',
      (t) async {
    var calls = 0;
    final pending = Completer<void>();
    await t.pumpWidget(page(() {
      calls++;
      return pending.future;
    }));
    await open(t);
    await t.tap(confirm());
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
    expect(t.widget<TextButton>(action()).onPressed, isNull);
    expect(find.text('Removing…'), findsOneWidget);
    pending.complete();
    await t.pumpAndSettle();
    expect(
        find.text(
            'Listing removed. Existing reservations are kept in Pickups.'),
        findsOneWidget);
  });
  testWidgets(
      'failed removal shows an error and keeps the listing usable for retry',
      (t) async {
    var calls = 0;
    await t.pumpWidget(page(() async {
      calls++;
      throw StateError('Unable to remove while offline. Retry.');
    }));
    await open(t);
    await t.tap(confirm());
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(
        find.textContaining('Unable to remove while offline'), findsOneWidget);
    expect(find.text('Nasi Lemak Ayam Crispy'), findsOneWidget);
    expect(t.widget<TextButton>(action()).onPressed, isNotNull);
    expect(
        find.text(
            'Listing removed. Existing reservations are kept in Pickups.'),
        findsNothing);
  });
  testWidgets('other pending listing actions disable the removal button',
      (t) async {
    await t.pumpWidget(page(() async {}, busy: true));
    expect(t.widget<TextButton>(action()).onPressed, isNull);
  });
  testWidgets(
      'remove controls and confirmation fit a small phone with larger text',
      (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
        child: page(() async {}, ended: true)));
    await open(t);
    expect(t.takeException(), isNull);
    await t.tap(find.text('Keep listing'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
