import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'location_state.dart';

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
  const LiveLocationMap({super.key, required this.location});
  final PilotLocation location;
  @override
  State<LiveLocationMap> createState() => _LiveLocationMapState();
}

class _LiveLocationMapState extends State<LiveLocationMap>
    with WidgetsBindingObserver {
  static const pilotCenter = LatLng(3.0567, 101.5851);
  final controller = MapController();
  bool ready = false, follow = true, tileError = false;
  LatLng? lastPoint;
  TileProvider? tiles;
  LatLng get point => widget.location.position == null
      ? pilotCenter
      : LatLng(widget.location.position!.latitude,
          widget.location.position!.longitude);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.location.addListener(_locationChanged);
    widget.location.attachMap();
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
    if (manualReset) {
      follow = true;
    }
    if (ready && follow && (point != lastPoint || manualReset)) {
      controller.move(point, widget.location.usingGps ? 16 : 13);
      lastPoint = point;
    }
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
      controller.move(point, 16);
      setState(() {});
    } else {
      await widget.location.useDeviceLocation();
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

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 330,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            FlutterMap(
                mapController: controller,
                options: MapOptions(
                    initialCenter: point,
                    initialZoom: widget.location.usingGps ? 16 : 13,
                    minZoom: 3,
                    maxZoom: 19,
                    onMapReady: () {
                      ready = true;
                      lastPoint = point;
                    },
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture && follow) setState(() => follow = false);
                    }),
                children: [
                  TileLayer(
                      urlTemplate: const String.fromEnvironment('MAP_TILE_URL',
                          defaultValue:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                      userAgentPackageName: 'com.foodienoms.foodienoms',
                      tileProvider: tiles,
                      panBuffer: 0,
                      maxNativeZoom: 19,
                      errorTileCallback: (_, __, ___) => _tileFailed()),
                  if (widget.location.position != null)
                    MarkerLayer(markers: [
                      Marker(
                          point: point,
                          width: 36,
                          height: 36,
                          child: Semantics(
                              label: widget.location.usingGps
                                  ? 'Your current location'
                                  : 'Your last known location',
                              child: Container(
                                  decoration: const BoxDecoration(
                                      color: Color(0x332478FF),
                                      shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF2478FF),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white,
                                              width: 3))))))
                    ]),
                ]),
            Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18)),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child: Text(
                                widget.location.usingGps
                                    ? follow
                                        ? 'Following your location'
                                        : 'Location shown · drag to explore'
                                    : widget.location.position == null
                                        ? 'Subang Jaya · manual view'
                                        : 'Last known location',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)))))),
            Positioned(
                right: 10,
                top: 50,
                child: Column(children: [
                  _MapButton(
                      tooltip: 'Zoom in',
                      icon: Icons.add,
                      onTap: () => controller.move(controller.camera.center,
                          (controller.camera.zoom + 1).clamp(3, 19))),
                  const SizedBox(height: 6),
                  _MapButton(
                      tooltip: 'Zoom out',
                      icon: Icons.remove,
                      onTap: () => controller.move(controller.camera.center,
                          (controller.camera.zoom - 1).clamp(3, 19))),
                  const SizedBox(height: 6),
                  _MapButton(
                      tooltip: 'Show my location',
                      icon: Icons.my_location,
                      onTap: widget.location.busy ? null : _locate),
                ])),
            if (tileError)
              const Positioned(
                  left: 8,
                  right: 8,
                  bottom: 38,
                  child: ColoredBox(
                      color: Color(0xEEFFFFFF),
                      child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                              'Some map tiles could not load. Check your internet connection.',
                              style: TextStyle(fontSize: 11))))),
            if (widget.location.message != null &&
                !widget.location.usingGps &&
                !widget.location.busy)
              Positioned(
                  left: 8,
                  right: 8,
                  bottom: 38,
                  child: ColoredBox(
                      color: const Color(0xEEFFFFFF),
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(widget.location.message!,
                              style: const TextStyle(fontSize: 11))))),
            Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                    color: Colors.white,
                    child: InkWell(
                        onTap: () async {
                          try {
                            await launchUrl(
                                Uri.parse(
                                    'https://www.openstreetmap.org/copyright'),
                                mode: LaunchMode.externalApplication);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'OpenStreetMap attribution: openstreetmap.org/copyright')));
                            }
                          }
                        },
                        child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            child: Text('© OpenStreetMap contributors',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF205F45))))))),
          ])));
}

class _MapButton extends StatelessWidget {
  const _MapButton(
      {required this.tooltip, required this.icon, required this.onTap});
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
          tooltip: tooltip, onPressed: onTap, icon: Icon(icon, size: 21)));
}
