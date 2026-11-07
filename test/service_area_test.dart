import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:foodienoms/firebase/business_location.dart';
import 'package:foodienoms/firebase/student_ui.dart';

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

class RangeGps extends GeolocatorPlatform {
  Position value = fix(1.3521, 103.8198);
  Completer<bool>? serviceResult;
  Completer<Position>? positionResult;
  final fixRequested = Completer<void>();
  @override
  Future<bool> isLocationServiceEnabled() async =>
      serviceResult == null ? true : serviceResult!.future;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    if (!fixRequested.isCompleted) fixRequested.complete();
    return positionResult == null ? value : positionResult!.future;
  }
}

void main() {
  late GeolocatorPlatform previous;
  late RangeGps gps;
  late PilotLocation location;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    gps = RangeGps();
    GeolocatorPlatform.instance = gps;
    location = PilotLocation();
  });
  tearDown(() {
    location.dispose();
    GeolocatorPlatform.instance = previous;
  });
  test(
      'service boundary includes corners and excludes just-outside/invalid coordinates',
      () {
    expect(isPilotShopLocation(pilotSouth, pilotWest), true);
    expect(isPilotShopLocation(pilotNorth, pilotEast), true);
    expect(isPilotShopLocation(pilotSouth - .00001, pilotWest), false);
    expect(isPilotShopLocation(pilotNorth, pilotEast + .00001), false);
    expect(isPilotShopLocation(double.nan, pilotWest), false);
    expect(isPilotShopLocation(pilotSouth, double.infinity), false);
    expect(isPilotShopLocation(3.139, 101.687), false);
  });
  test(
      'outside fix preserves actual device position and manual browsing clears the warning',
      () async {
    await location.useDeviceLocation();
    expect(location.outsideServiceArea, true);
    expect(location.inServiceArea, false);
    expect(location.area, 'Outside service area');
    expect(location.position!.latitude, 1.3521);
    expect(location.usingGps, true);
    expect(location.tracking, false);
    location.useManual();
    expect(location.outsideServiceArea, false);
    expect(location.position, null);
    expect(location.area, 'Subang Jaya, Selangor');
  });
  test('an inside fix is labelled as the Subang Jaya service area', () async {
    gps.value = fix(3.0567, 101.5851);
    await location.useDeviceLocation();
    expect(location.inServiceArea, true);
    expect(location.outsideServiceArea, false);
    expect(location.area, 'Subang Jaya, Selangor');
  });
  test('a late service-off response cannot overwrite a manual browsing reset',
      () async {
    gps.serviceResult = Completer<bool>();
    final request = location.useDeviceLocation();
    location.useManual();
    gps.serviceResult!.complete(false);
    await request;
    expect(location.message, 'Browsing the Subang Jaya pilot area.');
    expect(location.busy, false);
    expect(location.position, null);
  });
  test('a late location timeout cannot overwrite a manual browsing reset',
      () async {
    gps.positionResult = Completer<Position>();
    final request = location.useDeviceLocation();
    await gps.fixRequested.future;
    location.useManual();
    gps.positionResult!.completeError(TimeoutException('delayed GPS'));
    await request;
    expect(location.message, 'Browsing the Subang Jaya pilot area.');
    expect(location.busy, false);
    expect(location.position, null);
  });
  testWidgets('outside notice lets clients switch to manual Subang browsing',
      (tester) async {
    await location.useDeviceLocation();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ServiceAreaNotice(location: location))));
    expect(find.text('Outside service area'), findsOneWidget);
    await tester.tap(find.text('Browse Subang Jaya'));
    await tester.pump();
    expect(find.text('Outside service area'), findsNothing);
    expect(location.usingGps, false);
    expect(location.area, 'Subang Jaya, Selangor');
  });
}
