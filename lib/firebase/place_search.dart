import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'business_location.dart';

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
}

typedef PlaceSearchFunction = Future<List<PlaceSearchResult>> Function(
    String query);

class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Explicit forward searches only. No device GPS or account details are sent.
/// The shared instance limits requests to the public Photon demo service.
class PhotonPlaceSearch {
  PhotonPlaceSearch({
    http.Client? client,
    Uri? endpoint,
    DateTime Function()? clock,
    Future<void> Function(Duration)? delay,
    this.timeout = const Duration(seconds: 12),
    bool? isWeb,
  })  : _client = client ?? http.Client(),
        _endpoint = _validateEndpoint(endpoint ?? Uri.parse(_defaultEndpoint)),
        _clock = clock ?? DateTime.now,
        _delay = delay ?? Future<void>.delayed,
        _isWeb = isWeb ?? kIsWeb;

  static final shared = PhotonPlaceSearch();
  static const _defaultEndpoint = String.fromEnvironment('PLACE_SEARCH_URL',
      defaultValue: 'https://photon.komoot.io/api/');
  static const applicationUserAgent =
      'FoodieNoms/0.1 (com.foodienoms.foodienoms; explicit shop search)';
  static const _maxBodyBytes = 1024 * 1024;
  static const _cacheLifetime = Duration(minutes: 20);
  static const _requestInterval = Duration(seconds: 1);

  final http.Client _client;
  final Uri _endpoint;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _delay;
  final bool _isWeb;
  final Duration timeout;
  final _cache = <String, _CachedPlaces>{};
  final _pending = <String, Future<List<PlaceSearchResult>>>{};
  Future<void> _queue = Future<void>.value();
  DateTime? _lastRequest;

  Future<List<PlaceSearchResult>> search(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 2 || trimmed.length > 160) {
      return Future.error(const PlaceSearchException(
          'Enter a shop name or address between 2 and 160 characters.'));
    }
    final key = trimmed.toLowerCase();
    final now = _clock();
    _cache.removeWhere((_, entry) => !now.isBefore(entry.expires));
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return Future.value(cached.results);
    }
    return _pending[key] ??= _enqueue(trimmed, key);
  }

  Future<List<PlaceSearchResult>> _enqueue(String query, String key) async {
    final previous = _queue;
    final completed = Completer<void>();
    _queue = completed.future;
    try {
      await previous;
      // Serialize requests and space their start times, including after errors.
      while (_lastRequest != null) {
        final remaining =
            _lastRequest!.add(_requestInterval).difference(_clock());
        if (remaining <= Duration.zero) {
          break;
        }
        await _delay(remaining);
      }
      _lastRequest = _clock();
      final results = await _fetch(query);
      if (_cache.length >= 30) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = _CachedPlaces(results, _clock().add(_cacheLifetime));
      return results;
    } finally {
      _pending.remove(key);
      completed.complete();
    }
  }

  Future<List<PlaceSearchResult>> _fetch(String query) async {
    final abort = Completer<void>();
    final timer = Timer(timeout, abort.complete);
    final request = http.AbortableRequest(
        'GET',
        _endpoint.replace(queryParameters: {
          'q': query,
          'limit': '8',
          'lang': 'en',
          'bbox': '$pilotWest,$pilotSouth,$pilotEast,$pilotNorth',
        }),
        abortTrigger: abort.future)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (!_isWeb) {
      request.headers['User-Agent'] = applicationUserAgent;
    }
    try {
      return await _read(request).timeout(timeout);
    } on TimeoutException {
      throw const PlaceSearchException(
          'Place search took too long. Try again or enter coordinates to set your pin.');
    } on http.RequestAbortedException {
      throw const PlaceSearchException(
          'Place search took too long. Try again or enter coordinates to set your pin.');
    } on http.ClientException {
      throw const PlaceSearchException(
          'Place search needs an internet connection. Reconnect and try again, or enter coordinates.');
    } on FormatException {
      throw const PlaceSearchException(
          'Place search returned an unreadable result. Try again or enter coordinates.');
    } on PlaceSearchException {
      rethrow;
    } catch (_) {
      throw const PlaceSearchException(
          'Place search could not finish. Try again or enter coordinates to set your pin.');
    } finally {
      timer.cancel();
      if (!abort.isCompleted) {
        abort.complete();
      }
    }
  }

  Future<List<PlaceSearchResult>> _read(http.BaseRequest request) async {
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      await response.stream.listen((_) {}).cancel();
      if (response.statusCode == 429) {
        throw const PlaceSearchException(
            'Place search is busy. Wait a moment and try again, or enter coordinates.');
      }
      throw const PlaceSearchException(
          'Place search is unavailable right now. Try again or enter coordinates to set your pin.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > _maxBodyBytes) {
        throw const PlaceSearchException(
            'Place search returned too much data. Try a more specific shop or enter coordinates.');
      }
      bytes.add(chunk);
    }
    final data = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (data is! Map ||
        data['type'] != 'FeatureCollection' ||
        data['features'] is! List) {
      throw const PlaceSearchException(
          'Place search returned an unreadable result. Try again or enter coordinates.');
    }
    final results = <PlaceSearchResult>[];
    final seen = <String>{};
    for (final feature in data['features'] as List) {
      final place = _place(feature);
      if (place == null) {
        continue;
      }
      final key =
          '${place.latitude.toStringAsFixed(6)}|${place.longitude.toStringAsFixed(6)}|${place.name.toLowerCase()}';
      if (!seen.add(key)) {
        continue;
      }
      results.add(place);
      if (results.length == 8) {
        break;
      }
    }
    return List<PlaceSearchResult>.unmodifiable(results);
  }
}

class _CachedPlaces {
  const _CachedPlaces(this.results, this.expires);
  final List<PlaceSearchResult> results;
  final DateTime expires;
}

Uri _validateEndpoint(Uri endpoint) {
  if (endpoint.scheme != 'https' ||
      endpoint.host.isEmpty ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.hasQuery ||
      endpoint.hasFragment ||
      !(endpoint.path.endsWith('/api') || endpoint.path.endsWith('/api/'))) {
    throw const PlaceSearchException(
        'Place search is not configured. Enter coordinates to set your pin.');
  }
  return endpoint;
}

PlaceSearchResult? _place(Object? feature) {
  if (feature is! Map ||
      feature['geometry'] is! Map ||
      feature['properties'] is! Map) {
    return null;
  }
  final geometry = feature['geometry'] as Map;
  final coordinates = geometry['coordinates'];
  if (geometry['type'] != 'Point' ||
      coordinates is! List ||
      coordinates.length < 2 ||
      coordinates[0] is! num ||
      coordinates[1] is! num) {
    return null;
  }
  final longitude = (coordinates[0] as num).toDouble();
  final latitude = (coordinates[1] as num).toDouble();
  if (!isPilotShopLocation(latitude, longitude)) {
    return null;
  }
  final properties = feature['properties'] as Map;
  final countrycode = _text(properties['countrycode']);
  if (countrycode != null && countrycode.toUpperCase() != 'MY') {
    return null;
  }
  final street = _join([
    _text(properties['housenumber']),
    _text(properties['street']),
  ], ' ');
  final city = _text(properties['city']);
  final district = _text(properties['district']);
  final locality = _join([
    _text(properties['postcode']),
    city ?? district,
  ], ' ');
  final rawName = _text(properties['name']) ?? street ?? locality;
  if (rawName == null) {
    return null;
  }
  final name = _shorten(rawName, 100);
  final address = _shorten(
      _join([
            street,
            locality,
            if (city != null) district,
            _text(properties['state']),
            _text(properties['country']),
          ], ', ') ??
          name,
      300);
  final osmId = properties['osm_id'];
  final osmType = _text(properties['osm_type']);
  final id = osmType != null && (osmId is int || osmId is String)
      ? 'photon:$osmType:$osmId'
      : 'photon:$latitude,$longitude:$name';
  return PlaceSearchResult(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude);
}

String? _text(Object? value) {
  if (value is! String) {
    return null;
  }
  final text = value.replaceAll(RegExp(r'[\x00-\x20\x7f]+'), ' ').trim();
  return text.isEmpty ? null : text;
}

String? _join(List<String?> parts, String separator) {
  final seen = <String>{};
  final nonempty = parts
      .whereType<String>()
      .where((part) => seen.add(part.toLowerCase()))
      .toList();
  return nonempty.isEmpty ? null : nonempty.join(separator);
}

String _shorten(String text, int limit) {
  if (text.length <= limit) {
    return text;
  }
  // Do not split a UTF-16 surrogate pair when applying the form's text limits.
  final last = text.codeUnitAt(limit - 1);
  return text.substring(
      0, last >= 0xd800 && last <= 0xdbff ? limit - 1 : limit);
}

/// Accepts an explicit latitude, longitude pair within the pilot area.
/// This is local parsing and never invokes the network search service.
LatLng? parseCoordinatePair(String input) {
  var text = input.trim();
  if (text.length > 160) {
    return null;
  }
  if (text.startsWith('(') && text.endsWith(')')) {
    text = text.substring(1, text.length - 1).trim();
  }
  final match = RegExp(
          r'^([+-]?(?:\d+(?:\.\d+)?|\.\d+))(?:\s*,\s*|\s+)([+-]?(?:\d+(?:\.\d+)?|\.\d+))$')
      .firstMatch(text);
  if (match == null) {
    return null;
  }
  final latitude = double.tryParse(match.group(1)!);
  final longitude = double.tryParse(match.group(2)!);
  if (!isPilotShopLocation(latitude, longitude)) {
    return null;
  }
  return LatLng(latitude!, longitude!);
}
