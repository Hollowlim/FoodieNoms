import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:foodienoms/firebase/live_location_map.dart';

/// Only tests use this: no requests to an external map provider.
class OfflineMapTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/foodienoms_logo.png');
}

Widget offlineMapTiles(Widget child) =>
    MapTileProviderScope(provider: OfflineMapTiles(), child: child);
