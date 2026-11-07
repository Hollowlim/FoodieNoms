import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/business_location.dart';
import 'package:foodienoms/firebase/live_location_map.dart';
import 'package:foodienoms/firebase/location_state.dart';
import 'package:foodienoms/firebase/vendor_business.dart';
import 'package:foodienoms/firebase/place_search.dart';
import 'support/offline_map_tiles.dart';

void main() {
  const saved = <String, dynamic>{
    'businessName': 'Subang Bakery',
    'address': '12 Jalan SS15, Subang Jaya',
    'configured': true,
    'latitude': 3.0567,
    'longitude': 101.5851,
  };

  test('shop pins require configured, finite pilot coordinates', () {
    expect(ShopMapPin.fromData('shop', saved)?.name, 'Subang Bakery');
    expect(
        ShopMapPin.fromData('shop', {...saved, 'configured': false}), isNull);
    expect(ShopMapPin.fromData('shop', {...saved, 'latitude': null}), isNull);
    expect(
        ShopMapPin.fromData('shop', {...saved, 'latitude': '3.0567'}), isNull);
    expect(ShopMapPin.fromData('shop', {...saved, 'longitude': double.nan}),
        isNull);
    expect(isPilotShopLocation(3.0567, 101.5851), isTrue);
    expect(isPilotShopLocation(1.3521, 103.8198), isFalse);
  });

  Future<void> pumpForm(WidgetTester tester, Map<String, dynamic> initial,
      SaveVendorBusiness onSave,
      {PlaceSearchFunction? searchPlaces}) async {
    tester.view.physicalSize = const Size(430, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(offlineMapTiles(MaterialApp(
        home: Scaffold(
            body: VendorBusinessForm(
                initialData: initial,
                onSave: onSave,
                searchPlaces: searchPlaces)))));
    await tester.pumpAndSettle();
  }

  testWidgets('map preview is not saved until vendor selects a shop pin',
      (tester) async {
    Map<String, dynamic>? value;
    await pumpForm(tester, {
      'businessName': 'Subang Bakery',
      'address': '12 Jalan SS15, Subang Jaya',
      'configured': false,
    }, (
        {required businessName,
        required address,
        required latitude,
        required longitude}) async {
      value = {'latitude': latitude, 'longitude': longitude};
    });
    expect(find.bySemanticsLabel('Selected shop location'), findsNothing);
    await tester.tap(find.text('Save business profile'));
    await tester.pumpAndSettle();
    expect(value, isNull);
    expect(find.text('Select your shop pin before saving.'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Selected shop location'), findsOneWidget);
    expect(value, isNull);
    await tester.tap(find.text('Save business profile'));
    await tester.pumpAndSettle();
    expect(value?['latitude'], closeTo(3.0567, 0.001));
    expect(value?['longitude'], closeTo(101.5851, 0.001));
    expect(find.text('Business profile and shop pin saved.'), findsOneWidget);
  });

  testWidgets('saved shop is prefilled and out-of-area coordinates cannot save',
      (tester) async {
    var saves = 0;
    await pumpForm(tester, saved, (
        {required businessName,
        required address,
        required latitude,
        required longitude}) async {
      saves++;
      expect(businessName, 'Subang Bakery');
      expect(latitude, 3.06);
      expect(longitude, 101.59);
    });
    await tester.tap(find.text('Coordinates'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Selected shop location'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('business-latitude')))
            .controller!
            .text,
        '3.056700');
    await tester.enterText(
        find.byKey(const ValueKey('business-latitude')), '1.35');
    await tester.tap(find.text('Save business profile'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.bySemanticsLabel('Selected shop location'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('business-latitude')), '3.06');
    await tester.enterText(
        find.byKey(const ValueKey('business-longitude')), '101.59');
    await tester.tap(find.text('Save business profile'));
    await tester.pumpAndSettle();
    expect(saves, 1);
  });

  const result = PlaceSearchResult(
      id: 'bakery',
      name: 'SS15 Bakery',
      address: '8 Jalan SS15, Subang Jaya',
      latitude: 3.075,
      longitude: 101.59);
  Future<void> enterSearch(WidgetTester tester, String query) async {
    await tester.enterText(
        find.byKey(const ValueKey('location-search-query')), query);
    await tester.tap(find.byKey(const ValueKey('location-search-submit')));
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.byKey(const ValueKey('save-business-profile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'place search runs only explicitly and selecting a result saves its real pickup point',
      (tester) async {
    final calls = <String>[];
    Map<String, dynamic>? value;
    await pumpForm(tester, {...saved, 'configured': false}, (
        {required businessName,
        required address,
        required latitude,
        required longitude}) async {
      value = {
        'businessName': businessName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude
      };
    }, searchPlaces: (query) async {
      calls.add(query);
      return [result];
    });
    expect(calls, isEmpty);
    await tester.enterText(
        find.byKey(const ValueKey('location-search-query')), 'Bakery SS15');
    await tester.pump(const Duration(seconds: 1));
    expect(calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('location-search-submit')));
    await tester.pumpAndSettle();
    expect(calls, ['Bakery SS15']);
    await tester.tap(find.byKey(const ValueKey('location-result-bakery')));
    await tester.pumpAndSettle();
    expect(value, isNull);
    expect(find.bySemanticsLabel('Selected shop location'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('business-address')))
            .controller!
            .text,
        result.address);
    await tapSave(tester);
    expect(value, {
      'businessName': 'Subang Bakery',
      'address': result.address,
      'latitude': 3.075,
      'longitude': 101.59
    });
  });

  testWidgets(
      'editing a query discards a delayed response and clears the previous pin',
      (tester) async {
    final pending = Completer<List<PlaceSearchResult>>();
    var saves = 0;
    await pumpForm(tester, saved, (
        {required businessName,
        required address,
        required latitude,
        required longitude}) async {
      saves++;
    }, searchPlaces: (_) => pending.future);
    await enterSearch(tester, 'First search');
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('save-business-profile')))
            .onPressed,
        isNull);
    await tester.enterText(find.byKey(const ValueKey('location-search-query')),
        'A different shop');
    pending.complete([result]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location-result-bakery')), findsNothing);
    expect(find.bySemanticsLabel('Selected shop location'), findsNothing);
    await tapSave(tester);
    expect(saves, 0);
  });

  testWidgets(
      'switching to coordinates invalidates a pending search and applies a pasted pair explicitly',
      (tester) async {
    final pending = Completer<List<PlaceSearchResult>>();
    Map<String, double>? value;
    await pumpForm(tester, {...saved, 'configured': false}, (
        {required businessName,
        required address,
        required latitude,
        required longitude}) async {
      value = {'latitude': latitude, 'longitude': longitude};
    }, searchPlaces: (_) => pending.future);
    await enterSearch(tester, 'Old search');
    await tester.tap(find.text('Coordinates'));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('business-coordinate-pair')), '3.06, 101.59');
    expect(find.bySemanticsLabel('Selected shop location'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('business-apply-coordinates')));
    await tester.pump();
    pending.complete([result]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location-result-bakery')), findsNothing);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('business-latitude')))
            .controller!
            .text,
        '3.060000');
    expect(value, isNull);
    await tapSave(tester);
    expect(value, {'latitude': 3.06, 'longitude': 101.59});
  });

  testWidgets('search failure offers a usable coordinate fallback',
      (tester) async {
    var saves = 0;
    await pumpForm(tester, {...saved, 'configured': false}, (
            {required businessName,
            required address,
            required latitude,
            required longitude}) async {
      saves++;
    },
        searchPlaces: (_) async => throw const PlaceSearchException(
            'Search is offline. Enter coordinates instead.'));
    await enterSearch(tester, 'Bakery');
    await tester.pumpAndSettle();
    expect(find.text('Search is offline. Enter coordinates instead.'),
        findsOneWidget);
    await tester.tap(find.text('Coordinates'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('business-coordinate-pair')),
        '3.075, 101.59');
    await tester.tap(find.byKey(const ValueKey('business-apply-coordinates')));
    await tester.pumpAndSettle();
    await tapSave(tester);
    expect(saves, 1);
  });

  testWidgets(
      'outside search results cannot create a pin and late results after disposal are ignored',
      (tester) async {
    var saves = 0;
    final pending = Completer<List<PlaceSearchResult>>();
    var calls = 0;
    await pumpForm(tester, {...saved, 'configured': false}, (
        {required businessName,
        required address,
        required latitude,
        required longitude}) async {
      saves++;
    }, searchPlaces: (_) {
      calls++;
      return calls == 1
          ? Future.value([
              const PlaceSearchResult(
                  id: 'kl',
                  name: 'Kuala Lumpur',
                  address: 'Kuala Lumpur',
                  latitude: 3.139,
                  longitude: 101.687)
            ])
          : pending.future;
    });
    await enterSearch(tester, 'Kuala Lumpur');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location-result-kl')), findsNothing);
    expect(find.textContaining('No matches inside our Subang Jaya pilot area'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Selected shop location'), findsNothing);
    await tapSave(tester);
    expect(saves, 0);
    await tester
        .ensureVisible(find.byKey(const ValueKey('location-search-query')));
    await enterSearch(tester, 'Delayed shop');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete([result]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dragging the shop marker changes actual coordinates without saving',
      (tester) async {
    var saves = 0;
    await pumpForm(tester, saved, (
        {required businessName,
        required address,
        required latitude,
        required longitude}) async {
      saves++;
    });
    final pin = find.byKey(const ValueKey('business-shop-pin'));
    final map =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    final before = map.camera.latLngToScreenOffset(map.camera.center);
    final expected =
        map.camera.screenOffsetToLatLng(before + const Offset(36, 20));
    await tester.drag(pin, const Offset(36, 20));
    await tester.pumpAndSettle();
    expect(saves, 0);
    // Capturing a pin drag must not capture gestures on the rest of the map.
    final afterPinDrag = map.camera.center.longitude;
    await tester.dragFrom(
        tester.getTopLeft(find.byType(FlutterMap)) + const Offset(70, 240),
        const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(map.camera.center.longitude, isNot(closeTo(afterPinDrag, 0.000001)));
    await tester.tap(find.text('Coordinates'));
    await tester.pumpAndSettle();
    final latitude = double.parse(tester
        .widget<TextFormField>(find.byKey(const ValueKey('business-latitude')))
        .controller!
        .text);
    final longitude = double.parse(tester
        .widget<TextFormField>(find.byKey(const ValueKey('business-longitude')))
        .controller!
        .text);
    expect(latitude, closeTo(expected.latitude, 0.000001));
    expect(longitude, closeTo(expected.longitude, 0.000001));
    expect(longitude, greaterThan(saved['longitude'] as double));
  });

  testWidgets('customer sees tappable shop pins without enabling GPS',
      (tester) async {
    final location = PilotLocation();
    addTearDown(location.dispose);
    final first = ShopMapPin.fromData('first', saved)!;
    const second = ShopMapPin(
        id: 'second',
        name: 'USJ Cafe',
        address: 'USJ, Subang Jaya',
        latitude: 3.065,
        longitude: 101.60);
    ShopMapPin? tapped, focused;
    late StateSetter update;
    await tester.pumpWidget(offlineMapTiles(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return LiveLocationMap(
          location: location,
          shops: [first, second],
          focusShop: focused,
          onShopTap: (value) => tapped = value);
    })))));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Shop: Subang Bakery'), findsOneWidget);
    expect(find.bySemanticsLabel('Your current location'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('shop-pin-first')));
    await tester.pumpAndSettle();
    expect(tapped?.id, 'first');
    update(() => focused = second);
    await tester.pumpAndSettle();
    final controller =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    expect(
        controller.camera.center.latitude, closeTo(second.latitude, 0.00001));
    expect(
        controller.camera.center.longitude, closeTo(second.longitude, 0.00001));
    expect(location.tracking, isFalse);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
