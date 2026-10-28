import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class PilotLocation extends ChangeNotifier {
  bool _closed = false, _gpsEnabled = false, _foreground = true;
  int _maps = 0, _request = 0, _streamVersion = 0;
  StreamSubscription<Position>? _updates;
  Position? position;
  bool busy = false;
  String? message;
  String get area => usingGps ? 'Current location' : 'Subang Jaya, Selangor';
  bool get usingGps => _gpsEnabled && position != null;
  bool get tracking => _updates != null;

  void attachMap() {
    _maps++;
    _startUpdates();
  }

  void detachMap() {
    if (_maps > 0) _maps--;
    if (_maps == 0) _stopUpdates();
  }

  void setForeground(bool value) {
    _foreground = value;
    if (value) {
      _startUpdates();
    } else {
      _stopUpdates();
    }
  }

  void _stopUpdates() {
    _streamVersion++;
    final previous = _updates;
    _updates = null;
    if (previous != null) unawaited(previous.cancel());
  }

  LocationSettings get _settings =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? AppleSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
              pauseLocationUpdatesAutomatically: true,
              allowBackgroundLocationUpdates: false)
          : const LocationSettings(
              accuracy: LocationAccuracy.high, distanceFilter: 5);
  void _startUpdates() {
    if (_closed ||
        !_gpsEnabled ||
        !_foreground ||
        _maps == 0 ||
        _updates != null) {
      return;
    }
    final version = ++_streamVersion;
    _updates = Geolocator.getPositionStream(locationSettings: _settings).listen(
        (value) {
      if (_closed || version != _streamVersion) return;
      position = value;
      message = null;
      notifyListeners();
    }, onError: (Object _) {
      if (_closed || version != _streamVersion) return;
      _stopUpdates();
      _gpsEnabled = false;
      message = 'Live location paused. Tap Use My Location to retry.';
      notifyListeners();
    }, onDone: () {
      if (_closed || version != _streamVersion) return;
      _updates = null;
      _gpsEnabled = false;
      message = 'Location updates stopped. Tap Use My Location to retry.';
      notifyListeners();
    });
  }

  void useManual() {
    _request++;
    _stopUpdates();
    _gpsEnabled = false;
    busy = false;
    position = null;
    message = 'Browsing the Subang Jaya pilot area.';
    if (!_closed) notifyListeners();
  }

  Future<void> useDeviceLocation() async {
    if (busy || _closed) return;
    final request = ++_request;
    _stopUpdates();
    _gpsEnabled = false;
    busy = true;
    position = null;
    message = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        message =
            'Location services are off. Turn them on or browse Subang Jaya manually.';
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (_closed || request != _request) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        message =
            'Location access was not granted. You can still browse Subang Jaya manually or change access in device settings.';
        return;
      }
      final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20)));
      if (_closed || request != _request) return;
      position = current;
      _gpsEnabled = true;
      _startUpdates();
      message =
          'Your location is shown on the map. FoodieNoms listings currently cover the Subang Jaya pilot.';
    } on TimeoutException {
      message = 'Location took too long. Try again or browse manually.';
    } catch (_) {
      message =
          'Unable to get your location. You can continue browsing manually.';
    } finally {
      if (!_closed && request == _request) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _request++;
    _stopUpdates();
    super.dispose();
  }
}
