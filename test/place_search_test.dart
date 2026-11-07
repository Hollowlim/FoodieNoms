import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:foodienoms/firebase/business_location.dart';
import 'package:foodienoms/firebase/place_search.dart';

Map<String, Object?> feature({
  String? name = 'Sample Bakery',
  Object? latitude = 3.075,
  Object? longitude = 101.59,
  Map<String, Object?> properties = const {},
}) =>
    {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'properties': {
        'osm_id': 42,
        'osm_type': 'N',
        if (name != null) 'name': name,
        'housenumber': '8',
        'street': 'Jalan SS15',
        'postcode': '47500',
        'city': 'Subang Jaya',
        'state': 'Selangor',
        'country': 'Malaysia',
        'countrycode': 'MY',
        ...properties,
      },
    };

http.Response places([List<Object?>? features]) => http.Response(
    jsonEncode({
      'type': 'FeatureCollection',
      'features': features ?? [feature()],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'});

class SearchClock {
  DateTime now = DateTime.utc(2026, 11, 6);
  final waits = <Duration>[];

  Future<void> delay(Duration duration) async {
    waits.add(duration);
    now = now.add(duration);
  }

  PhotonPlaceSearch service(http.Client client,
          {bool isWeb = false,
          Duration timeout = const Duration(seconds: 12)}) =>
      PhotonPlaceSearch(
          client: client,
          clock: () => now,
          delay: delay,
          timeout: timeout,
          isWeb: isWeb);
}

Matcher searchError(String message) => isA<PlaceSearchException>()
    .having((error) => error.message, 'friendly message', contains(message));

void main() {
  test('explicit queries send entered text and pilot bounds without GPS data',
      () async {
    final requests = <http.Request>[];
    final clock = SearchClock();
    final service = clock.service(MockClient((request) async {
      requests.add(request);
      return places();
    }));
    expect(requests, isEmpty);
    final results = await service.search('  Bakery near SS15  ');
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.url.scheme, 'https');
    expect(request.url.host, 'photon.komoot.io');
    expect(request.url.path, '/api/');
    expect(request.url.queryParameters, {
      'q': 'Bakery near SS15',
      'limit': '8',
      'lang': 'en',
      'bbox': '$pilotWest,$pilotSouth,$pilotEast,$pilotNorth',
    });
    expect(request.headers['user-agent'], contains('FoodieNoms'));
    expect(request.body, isEmpty);
    expect(results.single.id, 'photon:N:42');
    expect(results.single.name, 'Sample Bakery');
    expect(results.single.address,
        '8 Jalan SS15, 47500 Subang Jaya, Selangor, Malaysia');
    expect(results.single.latitude, 3.075);
    expect(results.single.longitude, 101.59);
    expect(service.timeout, const Duration(seconds: 12));
  });

  test('browser searches omit the forbidden User-Agent header', () async {
    final requests = <http.Request>[];
    final service = SearchClock().service(MockClient((request) async {
      requests.add(request);
      return places();
    }), isWeb: true);
    expect(await service.search('Bakery'), hasLength(1));
    expect(requests.single.headers.containsKey('user-agent'), isFalse);
  });

  test('invalid query lengths never make a network request', () async {
    var requests = 0;
    final service = SearchClock().service(MockClient((_) async {
      requests++;
      return places();
    }));
    for (final query in ['', ' ', 'x', List.filled(161, 'a').join()]) {
      await expectLater(
          service.search(query), throwsA(searchError('between 2 and 160')));
    }
    expect(requests, 0);
    await service.search('SS');
    await service.search(List.filled(160, 'a').join());
    expect(requests, 2);
  });

  test('filters malformed points, reversed coordinates and outside places',
      () async {
    final service = SearchClock().service(MockClient((_) async => places([
          null,
          'bad entry',
          <String, Object>{},
          feature(latitude: '3.075'),
          feature(longitude: null),
          feature(latitude: 3.139, longitude: 101.687),
          feature(latitude: 101.59, longitude: 3.075),
          feature(latitude: pilotSouth - .001),
          feature(longitude: pilotWest - .001),
          feature(properties: {'countrycode': 'SG'}),
          {
            ...feature(),
            'geometry': {'type': 'LineString', 'coordinates': []}
          },
          {...feature(), 'properties': null},
          feature(properties: {'osm_id': 99, 'countrycode': 'my'}),
        ])));
    final results = await service.search('Bakery');
    expect(results.map((result) => result.id), ['photon:N:99']);
  });

  test('deduplicates rounded points and names and returns at most eight',
      () async {
    final service = SearchClock().service(MockClient((_) async => places([
          feature(),
          feature(
              name: ' sample bakery ',
              latitude: 3.07500001,
              longitude: 101.59000001,
              properties: {'osm_id': 43}),
          for (var index = 1; index < 12; index++)
            feature(name: 'Bakery $index', properties: {'osm_id': index}),
        ])));
    final results = await service.search('Bakery');
    expect(results, hasLength(8));
    expect(results[1].id, 'photon:N:1');
    expect(results.last.id, 'photon:N:7');
    expect(() => results.clear(), throwsUnsupportedError);
  });

  test('formats fallback names and bounded addresses without inventing a place',
      () async {
    final service = SearchClock().service(MockClient((_) async => places([
          feature(name: null, properties: {'osm_id': null, 'osm_type': null}),
          feature(name: 'A long address', properties: {
            'street': List.filled(400, 'a').join(),
            'osm_id': 77,
          }),
          {
            'geometry': {
              'type': 'Point',
              'coordinates': [101.59, 3.075]
            },
            'properties': {'name': 'Named place'},
          },
          {
            'geometry': {
              'type': 'Point',
              'coordinates': [101.59, 3.075]
            },
            'properties': <String, Object>{},
          },
        ])));
    final results = await service.search('Shop');
    expect(results, hasLength(3));
    expect(results.first.name, '8 Jalan SS15');
    expect(results.first.id, startsWith('photon:3.075,101.59:'));
    expect(results[1].address.length, lessThanOrEqualTo(300));
    expect(results.last.name, 'Named place');
    expect(results.last.address, 'Named place');
  });

  test('pilot boundary points and empty search results are valid', () async {
    final service = SearchClock().service(MockClient(
        (request) async => request.url.queryParameters['q'] == 'Missing shop'
            ? places([])
            : places([
                feature(latitude: pilotSouth, longitude: pilotWest),
                feature(
                    latitude: pilotNorth,
                    longitude: pilotEast,
                    properties: {'osm_id': 43}),
              ])));
    expect(await service.search('Bakery'), hasLength(2));
    expect(await service.search('Missing shop'), isEmpty);
  });

  test('identical in-flight and cached queries make one request until expiry',
      () async {
    final pending = Completer<http.Response>();
    final clock = SearchClock();
    var requests = 0;
    final service = clock.service(MockClient((_) async {
      requests++;
      return requests == 1 ? pending.future : places();
    }));
    final first = service.search('Bakery');
    final second = service.search(' bakery ');
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    pending.complete(places());
    await Future.wait([first, second]);
    await service.search('BAKERY');
    expect(requests, 1);
    clock.now = clock.now.add(const Duration(minutes: 20));
    await service.search('Bakery');
    expect(requests, 2);
  });

  test('cache is bounded to thirty queries and preserves recent hits',
      () async {
    final clock = SearchClock();
    var requests = 0;
    final service = clock.service(MockClient((_) async {
      requests++;
      return places();
    }));
    for (var index = 0; index < 30; index++) {
      await service.search('Shop $index');
    }
    await service.search('Shop 0');
    await service.search('Shop 30');
    expect(requests, 31);
    await service.search('Shop 0');
    expect(requests, 31);
    await service.search('Shop 1');
    expect(requests, 32);
  });

  test('different concurrent queries are spaced by at least one second',
      () async {
    final clock = SearchClock();
    final starts = <DateTime>[];
    final service = clock.service(MockClient((_) async {
      starts.add(clock.now);
      return places();
    }));
    await Future.wait([
      service.search('Bakery'),
      service.search('Cafe'),
      service.search('Street'),
    ]);
    expect(starts, hasLength(3));
    expect(starts[1].difference(starts[0]), const Duration(seconds: 1));
    expect(starts[2].difference(starts[1]), const Duration(seconds: 1));
  });

  test('HTTP failures and offline errors are friendly and not cached',
      () async {
    for (final status in [429, 500, 404]) {
      var requests = 0;
      final service = SearchClock().service(MockClient((_) async {
        requests++;
        return requests == 1
            ? http.Response('Private server detail', status)
            : places();
      }));
      await expectLater(service.search('Bakery'),
          throwsA(searchError(status == 429 ? 'busy' : 'unavailable')));
      expect(await service.search('Bakery'), hasLength(1));
      expect(requests, 2);
    }
    final offline = SearchClock().service(MockClient((_) async {
      throw http.ClientException('Private URL and query');
    }));
    await expectLater(
        offline.search('Bakery'), throwsA(searchError('internet connection')));
  });

  test('malformed and excessive responses are rejected', () async {
    for (final body in [
      '<html>error</html>',
      '[]',
      '{"features": []}',
      '{"type":"FeatureCollection","features":{}}',
    ]) {
      final service = SearchClock()
          .service(MockClient((_) async => http.Response(body, 200)));
      await expectLater(
          service.search('Bakery'), throwsA(searchError('unreadable result')));
    }
    final excessive = SearchClock().service(MockClient((_) async =>
        http.Response(List.filled(1024 * 1024 + 1, 'a').join(), 200)));
    await expectLater(
        excessive.search('Bakery'), throwsA(searchError('too much data')));
  });

  test('timeout leaves the manual coordinate fallback available', () async {
    final pending = Completer<http.Response>();
    final service = SearchClock().service(MockClient((_) => pending.future),
        timeout: const Duration(milliseconds: 1));
    await expectLater(
        service.search('Bakery'), throwsA(searchError('took too long')));
    pending.complete(places());
    expect(parseCoordinatePair('3.075,101.59'), isNotNull);
  });

  test('endpoint requires HTTPS Photon forward search without credentials', () {
    for (final endpoint in [
      'http://photon.example/api/',
      'https://user:password@photon.example/api/',
      'https://photon.example/reverse/',
      'https://photon.example/api/?q=hidden',
      'https://photon.example/api/#hidden',
    ]) {
      expect(
          () => PhotonPlaceSearch(
              client: MockClient((_) async => places()),
              endpoint: Uri.parse(endpoint)),
          throwsA(searchError('not configured')));
    }
  });

  test('coordinate pairs parse locally without network requests', () {
    var requests = 0;
    SearchClock().service(MockClient((_) async {
      requests++;
      return places();
    }));
    for (final input in [
      '3.075,101.59',
      ' 3.075 , 101.59 ',
      '3.075 101.59',
      '(3.075, 101.59)',
      ' ( +3.075  +101.59 ) ',
    ]) {
      final point = parseCoordinatePair(input);
      expect(point, isNotNull, reason: input);
      expect(point!.latitude, 3.075);
      expect(point.longitude, 101.59);
    }
    expect(parseCoordinatePair('$pilotSouth,$pilotWest'), isNotNull);
    expect(parseCoordinatePair('$pilotNorth $pilotEast'), isNotNull);
    expect(requests, 0);
  });

  test('coordinate parser rejects partial, reversed and out-of-area input', () {
    for (final input in [
      '',
      '3.075',
      '(3.075, 101.59',
      '3.075, 101.59)',
      '((3.075,101.59))',
      'latitude: 3.075, longitude: 101.59',
      '3.075,101.59 extra',
      '3.075,101.59,3.08',
      '3.075,,101.59',
      '3.075;101.59',
      '3.075.0 101.59',
      '3.075e0,101.59',
      'NaN,101.59',
      'Infinity,101.59',
      '101.59,3.075',
      '3.139,101.687',
      '${pilotNorth + .001},101.59',
      '3.075,${pilotEast + .001}',
      '3,075 101,59',
    ]) {
      expect(parseCoordinatePair(input), isNull, reason: input);
    }
  });
}
