import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'business_location.dart';
import 'location_state.dart';
import 'map_chrome.dart';

export 'business_location.dart' show ShopMapPin;

/// Offline tile injection for previews/tests; production uses the approved OSM provider.
class MapTileProviderScope extends InheritedWidget {
  const MapTileProviderScope(
      {super.key, required this.provider, required super.child});
  final TileProvider provider;
  static TileProvider? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MapTileProviderScope>()
      ?.provider;
  @override
  bool updateShouldNotify(MapTileProviderScope oldWidget) =>
      provider != oldWidget.provider;
}

class LiveLocationMap extends StatefulWidget {
  const LiveLocationMap(
      {super.key,
      required this.location,
      this.shops = const [],
      this.onShopTap,
      this.focusShop,
      this.height = 390});
  final PilotLocation location;
  final List<ShopMapPin> shops;
  final ValueChanged<ShopMapPin>? onShopTap;
  final ShopMapPin? focusShop;
  final double height;
  @override
  State<LiveLocationMap> createState() => _LiveLocationMapState();
}

class _LiveLocationMapState extends State<LiveLocationMap>
    with WidgetsBindingObserver {
  static const pilotCenter = LatLng(3.0567, 101.5851);
  static final serviceBounds = LatLngBounds(
      const LatLng(pilotSouth, pilotWest), const LatLng(pilotNorth, pilotEast));
  static final serviceFit = CameraFit.bounds(
      bounds: serviceBounds, padding: const EdgeInsets.all(24));
  final controller = MapController();
  bool ready = false, follow = true, tileError = false;
  bool wasOutside = false;
  double minimumZoom = 10;
  LatLng? lastPoint;
  TileProvider? tiles;
  LatLng get point => !widget.location.inServiceArea
      ? pilotCenter
      : LatLng(widget.location.position!.latitude,
          widget.location.position!.longitude);
  ShopMapPin? get focusedShop {
    final shop = widget.focusShop;
    return shop != null && isPilotShopLocation(shop.latitude, shop.longitude)
        ? shop
        : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.location.addListener(_locationChanged);
    widget.location.attachMap();
    wasOutside = widget.location.outsideServiceArea;
    if (focusedShop != null) follow = false;
  }

  @override
  void didUpdateWidget(covariant LiveLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      oldWidget.location.removeListener(_locationChanged);
      oldWidget.location.detachMap();
      widget.location.addListener(_locationChanged);
      widget.location.attachMap();
    }
    final shop = focusedShop;
    if (shop != null &&
        (oldWidget.focusShop?.id != shop.id ||
            oldWidget.focusShop?.latitude != shop.latitude ||
            oldWidget.focusShop?.longitude != shop.longitude)) {
      follow = false;
      if (ready) {
        controller.move(LatLng(shop.latitude, shop.longitude), 16);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    tiles ??= MapTileProviderScope.of(context) ??
        NetworkTileProvider(
            cachingProvider: kIsWeb
                ? null
                : BuiltInMapCachingProvider.getOrCreateInstance(
                    maxCacheSize: 50 * 1024 * 1024));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      widget.location.setForeground(state == AppLifecycleState.resumed);
  void _locationChanged() {
    if (!mounted) return;
    final manualReset =
        widget.location.position == null && !widget.location.busy;
    final outside = widget.location.outsideServiceArea;
    final crossedBoundary = outside != wasOutside;
    if (manualReset) {
      follow = true;
    }
    if (ready) {
      if (outside && crossedBoundary) {
        controller.fitCamera(serviceFit);
      } else if (!outside &&
          follow &&
          (point != lastPoint || manualReset || crossedBoundary)) {
        controller.move(point, widget.location.usingGps ? 16 : 13);
      }
    }
    lastPoint = outside ? null : point;
    wasOutside = outside;
    setState(() {});
  }

  void _tileFailed() {
    if (tileError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => tileError = true);
    });
  }

  Future<void> _locate() async {
    follow = true;
    if (widget.location.usingGps) {
      if (widget.location.outsideServiceArea) {
        controller.fitCamera(serviceFit);
      } else {
        controller.move(point, 16);
      }
      setState(() {});
    } else {
      await widget.location.useDeviceLocation();
      if (mounted &&
          !widget.location.usingGps &&
          !widget.location.outsideServiceArea &&
          widget.location.message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.location.message!)));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.location.removeListener(_locationChanged);
    widget.location.detachMap();
    controller.dispose();
    super.dispose();
  }

  String get status => widget.location.busy
      ? 'Finding your location…'
      : widget.location.outsideServiceArea
          ? 'Outside service area'
          : widget.location.usingGps
              ? follow
                  ? 'Following your location'
                  : 'Location shown · drag to explore'
              : widget.location.position == null
                  ? 'Subang Jaya · manual view'
                  : 'Last known location';

  Marker shopMarker(ShopMapPin shop) {
    final selected = focusedShop?.id == shop.id;
    return Marker(
        point: LatLng(shop.latitude, shop.longitude),
        width: selected ? 122 : 58,
        height: selected ? 91 : 58,
        alignment: Alignment.topCenter,
        child: Semantics(
            label: 'Shop: ${shop.name}',
            button: true,
            child: Tooltip(
                message: shop.name,
                excludeFromSemantics: true,
                child: GestureDetector(
                    key: ValueKey('shop-pin-${shop.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onShopTap?.call(shop),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            Container(
                                constraints: const BoxConstraints(
                                    maxWidth: 110, maxHeight: 28),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF153F2F),
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Color(0x24204734),
                                          blurRadius: 10,
                                          offset: Offset(0, 3)),
                                    ]),
                                child: Text(shop.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700))),
                            const SizedBox(height: 4),
                          ],
                          ShopPinMarker(selected: selected),
                        ])))));
  }

  void viewServiceArea() {
    controller.fitCamera(serviceFit);
    setState(() => follow = false);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, constraints) {
        // Fit the pilot to the actual viewport, keeping zoom-out local.
        minimumZoom = serviceFit
            .fit(MapCamera(
                crs: const Epsg3857(),
                center: pilotCenter,
                zoom: 13,
                rotation: 0,
                nonRotatedSize:
                    Size(constraints.maxWidth, constraints.maxHeight)))
            .zoom;
        final shop = focusedShop;
        return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(children: [
              FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                      initialCenter: shop == null
                          ? point
                          : LatLng(shop.latitude, shop.longitude),
                      initialZoom: widget.location.inServiceArea || shop != null
                          ? 16
                          : 13,
                      initialCameraFit:
                          widget.location.outsideServiceArea && shop == null
                              ? serviceFit
                              : null,
                      cameraConstraint:
                          CameraConstraint.containCenter(bounds: serviceBounds),
                      interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                      minZoom: minimumZoom,
                      maxZoom: 19,
                      onMapReady: () {
                        ready = true;
                        lastPoint = point;
                      },
                      onPositionChanged: (_, hasGesture) {
                        if (hasGesture && follow) {
                          setState(() => follow = false);
                        }
                      }),
                  children: [
                    CleanMapTiles(
                        child: TileLayer(
                            urlTemplate: const String.fromEnvironment(
                                'MAP_TILE_URL',
                                defaultValue:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                            userAgentPackageName: 'com.foodienoms.foodienoms',
                            tileProvider: tiles,
                            panBuffer: 0,
                            maxNativeZoom: 19,
                            errorTileCallback: (_, __, ___) => _tileFailed())),
                    PolygonLayer(polygons: [
                      Polygon(
                          points: const [
                            LatLng(pilotSouth, pilotWest),
                            LatLng(pilotNorth, pilotWest),
                            LatLng(pilotNorth, pilotEast),
                            LatLng(pilotSouth, pilotEast),
                          ],
                          color: const Color(0x04205F45),
                          borderColor: const Color(0x702A8861),
                          borderStrokeWidth: 1.4,
                          pattern:
                              StrokePattern.dashed(segments: const [7, 6])),
                    ]),
                    if (widget.shops.isNotEmpty)
                      MarkerLayer(markers: [
                        for (final pin in widget.shops)
                          if (isPilotShopLocation(pin.latitude, pin.longitude))
                            shopMarker(pin),
                      ]),
                    if (widget.location.inServiceArea)
                      MarkerLayer(markers: [
                        Marker(
                            point: point,
                            width: 38,
                            height: 38,
                            child: Semantics(
                                label: widget.location.usingGps
                                    ? 'Your current location'
                                    : 'Your last known location',
                                child: Container(
                                    decoration: const BoxDecoration(
                                        color: Color(0x1F347EF5),
                                        shape: BoxShape.circle),
                                    padding: const EdgeInsets.all(9),
                                    child: Container(
                                        decoration: BoxDecoration(
                                            color: const Color(0xFF347EF5),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 3),
                                            boxShadow: const [
                                          BoxShadow(
                                              color: Color(0x30347EF5),
                                              blurRadius: 5),
                                        ])))))
                      ]),
                  ]),
              Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x0F133D2B),
                                    blurRadius: 14,
                                    offset: Offset(0, 3)),
                              ]),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: widget.location.outsideServiceArea
                                        ? const Color(0xFFC98B28)
                                        : widget.location.usingGps
                                            ? const Color(0xFF347EF5)
                                            : const Color(0xFF2A8861),
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 7),
                            Flexible(
                                child: Text(status,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Color(0xFF344C3F),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600))),
                          ])))),
              Positioned(
                  right: 12,
                  bottom: 40,
                  child: MapControlStack(
                      onZoomIn: () => controller.move(controller.camera.center,
                          (controller.camera.zoom + 1).clamp(minimumZoom, 19)),
                      onZoomOut: () => controller.move(controller.camera.center,
                          (controller.camera.zoom - 1).clamp(minimumZoom, 19)),
                      onLocate: _locate,
                      locating: widget.location.busy)),
              if (tileError)
                Positioned(
                    left: 12,
                    right: 72,
                    bottom: 60,
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: const Color(0xF5FFFFFF),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          Icon(Icons.cloud_off_outlined,
                              size: 16, color: Color(0xFF718478)),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  'Some map tiles are unavailable. Check your connection.',
                                  style: TextStyle(
                                      color: Color(0xFF50685A), fontSize: 11))),
                        ]))),
              Positioned(
                  left: 12,
                  bottom: 29,
                  child: Tooltip(
                      message: 'View service area',
                      child: Material(
                          color: const Color(0xF2FFFFFF),
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                              onTap: viewServiceArea,
                              child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 6),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.crop_free_rounded,
                                            color: Color(0xFF668474), size: 12),
                                        SizedBox(width: 5),
                                        Text('Subang Jaya service area',
                                            style: TextStyle(
                                                fontSize: 9.5,
                                                color: Color(0xFF668474))),
                                      ])))))),
              const Positioned(bottom: 0, right: 0, child: MapAttribution()),
            ]));
      }));
}
