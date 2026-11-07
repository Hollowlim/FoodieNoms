import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:foodienoms/firebase/customer_map_panel.dart';
import 'package:foodienoms/firebase/live_location_map.dart';
import 'package:foodienoms/firebase/location_state.dart';
import 'support/offline_map_tiles.dart';

void main() {
  const bakery = ShopMapPin(
      id: 'bakery',
      name: 'Subang Bakery',
      address: '12 Jalan SS15/4, Subang Jaya',
      latitude: 3.0567,
      longitude: 101.5851);
  const cafe = ShopMapPin(
      id: 'cafe',
      name: 'Campus Cafe',
      address: 'USJ 2, Subang Jaya',
      latitude: 3.065,
      longitude: 101.60);

  late PilotLocation location;
  setUp(() => location = PilotLocation());
  tearDown(() => location.dispose());

  Future<void> pumpPanel(WidgetTester tester,
      {List<ShopMapPin> shops = const [bakery, cafe],
      ValueChanged<ShopMapPin>? onTap,
      VoidCallback? onChange,
      String? error,
      ShopMapPin? focus,
      Size size = const Size(393, 852)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(offlineMapTiles(MaterialApp(
        home: Scaffold(
            body: CustomerMapPanel(
                location: location,
                shops: shops,
                focusShop: focus,
                onShopTap: onTap ?? (_) {},
                onChangeLocation: onChange ?? () {},
                error: error)))));
    await tester.pumpAndSettle();
  }

  Finder scrollable() => find
      .descendant(
          of: find.byKey(const ValueKey('customer-map-scroll')),
          matching: find.byType(Scrollable))
      .first;

  testWidgets(
      'search filters map and cards and passes the actual selected shop',
      (tester) async {
    ShopMapPin? tapped;
    var changes = 0;
    await pumpPanel(tester,
        onTap: (value) => tapped = value, onChange: () => changes++);
    await tester.tap(find.text('Change'));
    expect(changes, 1);
    await tester.tap(find.byKey(const ValueKey('shop-pin-bakery')));
    expect(identical(tapped, bakery), isTrue);

    await tester.enterText(
        find.byKey(const ValueKey('pickup-spot-search')), 'uSj');
    await tester.pumpAndSettle();
    final map = tester.widget<LiveLocationMap>(find.byType(LiveLocationMap));
    expect(map.shops.map((shop) => shop.id), ['cafe']);
    final card = find.byKey(const ValueKey('pickup-spot-cafe'));
    await tester.scrollUntilVisible(card, 200, scrollable: scrollable());
    await tester.tap(card);
    expect(identical(tapped, cafe), isTrue);
    await tester.scrollUntilVisible(
        find.byTooltip('Clear pickup spot search'), -200,
        scrollable: scrollable());
    await tester.tap(find.byTooltip('Clear pickup spot search'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<LiveLocationMap>(find.byType(LiveLocationMap))
            .shops
            .length,
        2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and failed shop loads do not invent map pins',
      (tester) async {
    await pumpPanel(tester, shops: const []);
    expect(tester.widget<LiveLocationMap>(find.byType(LiveLocationMap)).shops,
        isEmpty);
    expect(find.byType(MarkerLayer), findsNothing);
    await tester.scrollUntilVisible(
        find.text('Pickup spots are coming soon'), 200,
        scrollable: scrollable());
    expect(find.text('Pickup spots are coming soon'), findsOneWidget);

    await pumpPanel(tester,
        shops: const [],
        error: 'Check your internet connection and try again.');
    await tester.scrollUntilVisible(
        find.text('Pickup spots could not load'), 200,
        scrollable: scrollable());
    expect(find.text('Pickup spots could not load'), findsOneWidget);
    expect(find.text('Check your internet connection and try again.'),
        findsOneWidget);
    expect(find.byType(MarkerLayer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no search match can be cleared to reveal real shops again',
      (tester) async {
    await pumpPanel(tester);
    await tester.enterText(
        find.byKey(const ValueKey('pickup-spot-search')), 'not a shop');
    await tester.pumpAndSettle();
    expect(tester.widget<LiveLocationMap>(find.byType(LiveLocationMap)).shops,
        isEmpty);
    await tester.scrollUntilVisible(find.text('No matching pickup spots'), 200,
        scrollable: scrollable());
    final clearSearch = find.widgetWithText(TextButton, 'Clear search');
    await tester.scrollUntilVisible(clearSearch, 160, scrollable: scrollable());
    await tester.pumpAndSettle();
    expect(clearSearch.hitTestable(), findsOneWidget);
    await tester.tap(clearSearch);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pickup-spot-bakery')), 200,
        scrollable: scrollable());
    expect(find.byKey(const ValueKey('pickup-spot-bakery')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'narrow phone supports long shop details and outside-area browsing',
      (tester) async {
    location.position = Position(
        latitude: 1.3521,
        longitude: 103.8198,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1);
    const longShop = ShopMapPin(
        id: 'long',
        name: 'The Neighbourhood Bakery and Fresh Surplus Pickup Kitchen',
        address:
            'Unit 12A, First Floor, Jalan SS15/4A, 47500 Subang Jaya, Selangor',
        latitude: 3.0567,
        longitude: 101.5851);
    await pumpPanel(tester,
        shops: const [longShop], focus: longShop, size: const Size(320, 760));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Browse here'), 180,
        scrollable: scrollable());
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Browse here'));
    await tester.pumpAndSettle();
    expect(location.outsideServiceArea, isFalse);
    expect(location.position, isNull);
    final card = find.byKey(const ValueKey('pickup-spot-long'));
    await tester.scrollUntilVisible(card, 180, scrollable: scrollable());
    expect(card, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
