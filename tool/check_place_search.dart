// Explicit network smoke check; not part of the offline app test suite.
// Run: flutter test tool/check_place_search.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/place_search.dart';
import 'package:foodienoms/firebase/business_location.dart';

class _LiveHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Photon finds a real public Subang landmark within the pilot area',
      () async {
    final results = await HttpOverrides.runWithHttpOverrides(
        () => PhotonPlaceSearch().search('Sunway Pyramid'), _LiveHttp());
    expect(results, isNotEmpty);
    expect(
        results.any(
            (place) => place.name.toLowerCase().contains('sunway pyramid')),
        isTrue);
    expect(
        results.every(
            (place) => isPilotShopLocation(place.latitude, place.longitude)),
        isTrue);
    // ignore: avoid_print
    print('PLACE_SEARCH_SMOKE passed: ${results.length} in-area results.');
  });
}
