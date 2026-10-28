import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:foodienoms/firebase/live_location_map.dart';
import 'package:foodienoms/firebase/location_state.dart';
import 'support/offline_map_tiles.dart';

Position fix(double latitude, double longitude) => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1);

class DeviceLocation extends GeolocatorPlatform {
  final updates = StreamController<Position>.broadcast();
  int subscriptions = 0;
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      fix(3.0567, 101.5851);
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    subscriptions++;
    return updates.stream;
  }
}

void main() {
  late DeviceLocation gps;
  late GeolocatorPlatform previous;
  late PilotLocation location;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    gps = DeviceLocation();
    GeolocatorPlatform.instance = gps;
    location = PilotLocation();
  });
  tearDown(() async {
    location.dispose();
    await gps.updates.close();
    GeolocatorPlatform.instance = previous;
  });

  test('GPS streams only on visible foreground maps and stops on manual mode',
      () async {
    await location.useDeviceLocation();
    expect(location.usingGps, isTrue);
    expect(location.tracking, isFalse);
    location.attachMap();
    expect(location.tracking, isTrue);
    expect(gps.subscriptions, 1);
    gps.updates.add(fix(3.057, 101.586));
    await Future<void>.delayed(Duration.zero);
    expect(location.position!.latitude, 3.057);
    location.setForeground(false);
    expect(location.tracking, isFalse);
    location.setForeground(true);
    expect(location.tracking, isTrue);
    location.detachMap();
    expect(location.tracking, isFalse);
    location.attachMap();
    location.useManual();
    expect(location.tracking, isFalse);
    expect(location.position, isNull);
    expect(location.area, 'Subang Jaya, Selangor');
  });
  test('GPS failure leaves manual browsing available without any stream',
      () async {
    gps.enabled = false;
    location.attachMap();
    await location.useDeviceLocation();
    expect(location.message, contains('off'));
    expect(location.busy, isFalse);
    expect(location.tracking, isFalse);
    expect(gps.subscriptions, 0);
  });
  testWidgets(
      'map shows live marker, follows GPS and can re-center after dragging',
      (tester) async {
    await tester.pumpWidget(offlineMapTiles(MaterialApp(
        home: Scaffold(body: LiveLocationMap(location: location)))));
    await tester.pumpAndSettle();
    expect(find.text('Subang Jaya · manual view'), findsOneWidget);
    expect(find.byType(MarkerLayer), findsNothing);
    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Your current location'), findsOneWidget);
    final mapController =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    expect(mapController.camera.center.latitude, closeTo(3.0567, 0.00001));
    gps.updates.add(fix(3.058, 101.589));
    await tester.pumpAndSettle();
    expect(mapController.camera.center.latitude, closeTo(3.058, 0.00001));
    await tester.drag(find.byType(FlutterMap), const Offset(65, 30));
    await tester.pumpAndSettle();
    expect(find.text('Location shown · drag to explore'), findsOneWidget);
    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();
    expect(mapController.camera.center.latitude, closeTo(3.058, 0.00001));
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    location.useManual();
    await tester.pumpAndSettle();
    expect(mapController.camera.center.latitude, closeTo(3.0567, 0.00001));
    expect(find.byType(MarkerLayer), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(location.tracking, isFalse);
  });
}
