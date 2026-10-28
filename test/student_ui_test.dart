import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/student_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'support/offline_map_tiles.dart';

void main() {
  test('denied GPS permission keeps manual browsing available', () async {
    final previous = GeolocatorPlatform.instance;
    final fake = _DeniedLocation();
    GeolocatorPlatform.instance = fake;
    addTearDown(() => GeolocatorPlatform.instance = previous);
    final location = PilotLocation();
    addTearDown(location.dispose);
    await location.useDeviceLocation();
    expect(location.usingGps, isFalse);
    expect(location.busy, isFalse);
    expect(location.message, contains('not granted'));
    expect(fake.permissionRequests, 1);
    location.useManual();
    expect(location.area, 'Subang Jaya, Selangor');
  });

  testWidgets('Figma-style home shows location selection and accepts search',
      (tester) async {
    final location = PilotLocation();
    addTearDown(location.dispose);
    String query = '';
    await tester.pumpWidget(offlineMapTiles(MaterialApp(
        home: Scaffold(
            body: StudentDiscoverHeader(
                location: location, onSearch: (value) => query = value)))));
    expect(find.text('Rescue delicious food.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bakery');
    expect(query, 'bakery');
    await tester.tap(find.text('Subang Jaya, Selangor'));
    await tester.pumpAndSettle();
    expect(find.text('Find food near you'), findsOneWidget);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse Subang Jaya Manually'));
    await tester.pumpAndSettle();
    expect(find.text('Rescue delicious food.'), findsOneWidget);
    expect(location.usingGps, isFalse);
  });
  testWidgets(
      'profile uses actual account data and its location/settings actions work',
      (tester) async {
    bool openedLocation = false, openedSettings = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StudentProfilePanel(
                name: 'Alex Student',
                email: 'alex@example.com',
                onPersonalInfo: () {},
                onReviews: () {},
                onNotifications: () {},
                onLocation: () => openedLocation = true,
                onSettings: () => openedSettings = true,
                onLogout: () {}))));
    expect(find.text('Alex Student'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);
    expect(find.text('Estimated savings'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Privacy & location'), 180);
    await tester.tap(find.text('Privacy & location'));
    expect(openedLocation, isTrue);
    await tester.scrollUntilVisible(find.text('Account settings'), 180);
    await tester.tap(find.text('Account settings'));
    expect(openedSettings, isTrue);
  });
  testWidgets('profile remains scrollable on narrow screens with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
            child: Scaffold(
                body: StudentProfilePanel(
                    name: 'A student with a long name',
                    email: 'student@example.com',
                    onPersonalInfo: () {},
                    onReviews: () {},
                    onNotifications: () {},
                    onLocation: () {},
                    onSettings: () {},
                    onLogout: () {})))));
    await tester.scrollUntilVisible(find.text('Log out'), 160);
    expect(tester.takeException(), isNull);
  });
}

class _DeniedLocation extends GeolocatorPlatform {
  int permissionRequests = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return LocationPermission.denied;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      throw StateError('Position must not be requested without permission.');
}
