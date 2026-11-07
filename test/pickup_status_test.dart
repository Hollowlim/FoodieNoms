import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:foodienoms/firebase/pickup_ui.dart';
import 'package:foodienoms/firebase/student_experience.dart';

const now = 1800000000000;
Map<String, dynamic> order(String status, {bool short = true, int? end}) => {
      'status': status,
      'code': 'FN-0123456789ABCDEF0123',
      if (short) 'pickupCode': '0007',
      'title': 'Tofu lunch',
      'vendorName': 'Subang Cafe',
      'quantity': 1,
      'totalCents': 800,
      'address': 'SS15, Subang Jaya',
      'pickupStart': now - 60000,
      'pickupEnd': end ?? now + 3600000,
    };
void main() {
  test(
      'ready is an open pickup; terminal statuses remain in their own history tab',
      () {
    for (final state in ['reserved', 'ready']) {
      expect(isOpenReservation(order(state)), isTrue);
      expect(reservationMatchesTab(order(state), 'reserved'), isTrue);
    }
    for (final state in ['collected', 'cancelled', 'noshow']) {
      expect(isOpenReservation(order(state)), isFalse);
      expect(reservationMatchesTab(order(state), 'reserved'), isFalse);
      expect(reservationMatchesTab(order(state), state), isTrue);
    }
    expect(reservationStatusLabel('ready'), 'Ready for pickup');
    expect(reservationStatusLabel('noshow'), 'Not collected');
  });
  test('grace cutoff belongs to collection; no-show starts only after it', () {
    final data = order('reserved', end: now);
    expect(canMarkReservationReady(data, now + 900000), isTrue);
    expect(canMarkReservationNoShow(data, now + 900000), isFalse);
    expect(canMarkReservationReady(data, now + 900001), isFalse);
    expect(canMarkReservationNoShow(data, now + 900001), isTrue);
    expect(canMarkReservationNoShow(order('ready', end: now), now + 900001),
        isTrue);
    expect(canMarkReservationNoShow(order('collected', end: now), now + 900001),
        isFalse);
  });
  test(
      'short code preserves leading zeroes and falls back on legacy references',
      () {
    expect(shortPickupCode(order('reserved')), '0007');
    expect(shortPickupCode(order('reserved', short: false)), isNull);
    for (final code in ['7', '12345', 7, 'ABCD']) {
      expect(
          shortPickupCode({...order('reserved'), 'pickupCode': code}), isNull);
    }
    expect(
        pickupCodeFromQr('FN-0123456789ABCDEF0123'), 'FN-0123456789ABCDEF0123');
  });
  testWidgets(
      'short code and existing QR are both visible for reserved and ready pickups',
      (t) async {
    for (final status in ['reserved', 'ready']) {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: PickupPass(order: order(status), nowMs: now)))));
      expect(find.text('0007'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('FN-0123456789ABCDEF0123'), findsOneWidget);
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Pickup QR code for FN-0123456789ABCDEF0123'),
          findsOneWidget);
      expect(find.text(status == 'ready' ? 'Ready for pickup' : 'Reserved'),
          findsOneWidget);
    }
  });
  testWidgets('closed pickups hide their usable short code and QR', (t) async {
    for (final status in ['collected', 'cancelled', 'noshow']) {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: PickupPass(order: order(status), nowMs: now)))));
      expect(find.text('0007'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text(reservationStatusLabel(status)), findsOneWidget);
    }
  });
  testWidgets(
      'expired open pickups hide codes before the vendor marks not collected',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PickupPass(
                    order: order('ready', end: now - 900001), nowMs: now)))));
    expect(find.text('0007'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Pickup window ended'), findsOneWidget);
    expect(hasUsablePickupPass(order('ready', end: now), now + 900000), isTrue);
    expect(
        hasUsablePickupPass(order('ready', end: now), now + 900001), isFalse);
  });
  testWidgets(
      'vendor can mark reserved food ready then collect; ready hides the repeat action',
      (t) async {
    var marked = 0, collected = 0;
    Widget panel(String status) => MaterialApp(
        home: Scaffold(
            body: VendorPickupActions(
                order: order(status),
                nowMs: now,
                onReady: () => marked++,
                onNoShow: () {},
                onCollect: () => collected++)));
    await t.pumpWidget(panel('reserved'));
    await t.tap(find.text('Mark ready'));
    await t.tap(find.text('Mark collected'));
    expect(marked, 1);
    expect(collected, 1);
    await t.pumpWidget(panel('ready'));
    expect(find.text('Mark ready'), findsNothing);
    expect(find.text('Mark collected'), findsOneWidget);
  });
  testWidgets(
      'expired pickup offers not-collected after grace and closed orders have no vendor controls',
      (t) async {
    var missed = false;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VendorPickupActions(
                order: order('ready', end: now - 900001),
                nowMs: now,
                onReady: () {},
                onCollect: () {},
                onNoShow: () => missed = true))));
    expect(find.text('Mark collected'), findsNothing);
    expect(find.text('Mark ready'), findsNothing);
    await t.tap(find.text('Not collected'));
    expect(missed, isTrue);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VendorPickupActions(
                order: order('noshow', end: now - 900001),
                nowMs: now,
                onReady: () {},
                onCollect: () {},
                onNoShow: () {}))));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
  testWidgets(
      'pending requests and unapproved vendors cannot trigger pickup actions',
      (t) async {
    for (final approved in [true, false]) {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: VendorPickupActions(
                  order: order('reserved'),
                  nowMs: now,
                  busy: approved,
                  approved: approved,
                  onReady: () {},
                  onCollect: () {},
                  onNoShow: () {}))));
      expect(t.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
      expect(
          t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    }
  });
  testWidgets('not-collected history tab is reachable on a small phone',
      (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var selected = 'reserved';
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => OrderStatusTabs(
                    selected: selected,
                    onSelected: (value) =>
                        setState(() => selected = value))))));
    await t.ensureVisible(find.text('Not collected'));
    await t.pumpAndSettle();
    await t.tap(find.text('Not collected'));
    await t.pumpAndSettle();
    expect(selected, 'noshow');
    expect(t.takeException(), isNull);
  });
}
