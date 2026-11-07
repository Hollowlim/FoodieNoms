import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'business_location.dart';
import 'live_location_map.dart';
import 'location_state.dart';
import 'management_ui.dart';
import 'map_chrome.dart';
import 'place_search.dart';
import 'service.dart';

typedef SaveVendorBusiness = Future<void> Function(
    {required String businessName,
    required String address,
    required double latitude,
    required double longitude});

class VendorBusinessScreen extends StatefulWidget {
  const VendorBusinessScreen(
      {super.key, required this.service, this.searchPlaces});
  final FoodieService service;
  final PlaceSearchFunction? searchPlaces;

  @override
  State<VendorBusinessScreen> createState() => _VendorBusinessScreenState();
}

class _VendorBusinessScreenState extends State<VendorBusinessScreen> {
  late Future<Map<String, dynamic>> initial = load();

  Future<Map<String, dynamic>> load() async {
    final uid = widget.service.auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in as a vendor first.');
    final result = await Future.wait([
      widget.service.db
          .collection('vendorBusinesses')
          .doc(uid)
          .get(const GetOptions(source: Source.server)),
      widget.service.db
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server)),
    ]);
    if (result[1].data()?['role'] != 'vendor') {
      throw StateError('Only vendor accounts have a business profile.');
    }
    return {
      'businessName': result[1].data()?['name'] ?? '',
      ...?result[0].data(),
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: managementCream,
      appBar: AppBar(
          title: const Text('Business profile'),
          backgroundColor: managementGreen,
          foregroundColor: Colors.white),
      body: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
              future: initial,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(firebaseMessage(snapshot.error!)),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: () =>
                                    setState(() => initial = load()),
                                child: const Text('Try again')),
                          ])));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return VendorBusinessForm(
                    initialData: snapshot.data!,
                    searchPlaces: widget.searchPlaces,
                    onSave: widget.service.saveVendorBusiness,
                    onSaved: () => Navigator.pop(context, true));
              })));
}

/// The editor stores only the shop point explicitly selected by the vendor.
class VendorBusinessForm extends StatefulWidget {
  const VendorBusinessForm(
      {super.key,
      required this.initialData,
      required this.onSave,
      this.onSaved,
      this.searchPlaces});
  final Map<String, dynamic> initialData;
  final SaveVendorBusiness onSave;
  final VoidCallback? onSaved;
  final PlaceSearchFunction? searchPlaces;

  @override
  State<VendorBusinessForm> createState() => _VendorBusinessFormState();
}

class _VendorBusinessFormState extends State<VendorBusinessForm>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final address = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  final searchQuery = TextEditingController();
  final coordinatePair = TextEditingController();
  final gps = PilotLocation();
  LatLng? selected;
  bool busy = false, locating = false, foreground = true, searching = false;
  bool coordinateMode = false;
  int operation = 0;
  List<PlaceSearchResult> results = const [];
  String? error, locationMessage, searchMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    name.text = widget.initialData['businessName'] as String? ?? '';
    address.text = widget.initialData['address'] as String? ?? '';
    final lat = (widget.initialData['latitude'] as num?)?.toDouble();
    final lng = (widget.initialData['longitude'] as num?)?.toDouble();
    if (widget.initialData['configured'] == true &&
        isPilotShopLocation(lat, lng)) {
      selected = LatLng(lat!, lng!);
      latitude.text = lat.toStringAsFixed(6);
      longitude.text = lng.toStringAsFixed(6);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    gps.setForeground(foreground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    name.dispose();
    address.dispose();
    latitude.dispose();
    longitude.dispose();
    searchQuery.dispose();
    coordinatePair.dispose();
    operation++;
    gps.dispose();
    super.dispose();
  }

  void select(LatLng point) {
    invalidateRequest();
    if (!isPilotShopLocation(point.latitude, point.longitude)) {
      setState(() =>
          locationMessage = 'Choose a shop inside the Subang Jaya pilot area.');
      return;
    }
    latitude.text = point.latitude.toStringAsFixed(6);
    longitude.text = point.longitude.toStringAsFixed(6);
    coordinatesChanged();
  }

  void coordinatesChanged([String? _]) {
    invalidateRequest();
    final lat = double.tryParse(latitude.text.trim());
    final lng = double.tryParse(longitude.text.trim());
    setState(() {
      selected = isPilotShopLocation(lat, lng) ? LatLng(lat!, lng!) : null;
      if (selected != null) error = null;
      locationMessage = selected == null
          ? 'Choose a shop inside the Subang Jaya pilot map area.'
          : null;
    });
  }

  void invalidateRequest() {
    operation++;
    searching = false;
    locating = false;
    results = const [];
    searchMessage = null;
  }

  void queryChanged(String _) {
    setState(() {
      invalidateRequest();
      // A new search must be selected explicitly before it becomes a pickup pin.
      selected = null;
      latitude.clear();
      longitude.clear();
      locationMessage = null;
    });
  }

  Future<void> search() async {
    if (busy || locating || searching) return;
    final query = searchQuery.text.trim();
    if (query.length < 2) {
      setState(
          () => searchMessage = 'Enter a shop, street or landmark to search.');
      return;
    }
    final token = ++operation;
    setState(() {
      searching = true;
      results = const [];
      searchMessage = null;
    });
    try {
      final found =
          await (widget.searchPlaces ?? PhotonPlaceSearch.shared.search)(query);
      if (!mounted || token != operation || coordinateMode) return;
      final within = found
          .where(
              (place) => isPilotShopLocation(place.latitude, place.longitude))
          .take(8)
          .toList();
      setState(() {
        results = within;
        searchMessage = within.isEmpty
            ? 'No matches inside our Subang Jaya pilot area. Try a nearby street or enter coordinates.'
            : null;
      });
    } catch (error) {
      if (!mounted || token != operation) return;
      setState(() => searchMessage = error is PlaceSearchException
          ? error.message
          : 'Place search is unavailable. Try again or enter coordinates.');
    } finally {
      if (mounted && token == operation) setState(() => searching = false);
    }
  }

  void choosePlace(PlaceSearchResult place) {
    if (!isPilotShopLocation(place.latitude, place.longitude)) return;
    address.text = place.address;
    if (name.text.trim().isEmpty) {
      name.text =
          place.name.length <= 100 ? place.name : place.name.substring(0, 100);
    }
    searchQuery.text = place.name;
    select(LatLng(place.latitude, place.longitude));
  }

  void switchMode(bool coordinates) {
    setState(() {
      invalidateRequest();
      coordinateMode = coordinates;
    });
  }

  void applyPair() {
    final point = parseCoordinatePair(coordinatePair.text);
    if (point == null) {
      setState(() => locationMessage =
          'Paste latitude, longitude inside our Subang Jaya pilot area.');
      return;
    }
    select(point);
  }

  Future<void> useLocation() async {
    if (!foreground || locating || busy) return;
    setState(() {
      invalidateRequest();
      locating = true;
      locationMessage = null;
    });
    final token = operation;
    // No map is attached to this helper: this is one foreground fix, no stream.
    await gps.useDeviceLocation();
    if (!mounted || token != operation) return;
    final position = gps.position;
    if (foreground && position != null) {
      if (isPilotShopLocation(position.latitude, position.longitude)) {
        select(LatLng(position.latitude, position.longitude));
      } else {
        locationMessage =
            'Your current location is outside the pilot area. Tap your shop on the Subang Jaya map instead.';
      }
    } else {
      locationMessage = foreground
          ? gps.message ?? 'Unable to locate you. Select the shop on the map.'
          : 'Return to the app and try Use my current location again.';
    }
    setState(() => locating = false);
  }

  Future<void> save() async {
    if (busy || locating || searching) return;
    if (!form.currentState!.validate()) return;
    final lat = double.tryParse(latitude.text.trim());
    final lng = double.tryParse(longitude.text.trim());
    if (selected == null || !isPilotShopLocation(lat, lng)) {
      setState(() => error = 'Select your shop pin before saving.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave(
          businessName: name.text.trim(),
          address: address.text.trim(),
          latitude: lat!,
          longitude: lng!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Business profile and shop pin saved.')));
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() => error = firebaseMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget coordinateField({required bool isLatitude}) => TextFormField(
      key: ValueKey(isLatitude ? 'business-latitude' : 'business-longitude'),
      controller: isLatitude ? latitude : longitude,
      enabled: !busy && !locating,
      onChanged: coordinatesChanged,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration:
          InputDecoration(labelText: isLatitude ? 'Latitude' : 'Longitude'),
      validator: (value) {
        final number = double.tryParse(value?.trim() ?? '');
        final lower = isLatitude ? pilotSouth : pilotWest;
        final upper = isLatitude ? pilotNorth : pilotEast;
        return number == null ||
                !number.isFinite ||
                number < lower ||
                number > upper
            ? 'Select a shop ${isLatitude ? 'latitude' : 'longitude'} within the Subang Jaya pilot.'
            : null;
      });

  Widget searchPanel() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            key: const ValueKey('location-search-query'),
            controller: searchQuery,
            enabled: !busy && !locating,
            onChanged: queryChanged,
            onSubmitted: (_) => search(),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search location',
                hintText: 'Search shop, street or landmark')),
        const SizedBox(height: 10),
        SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
                key: const ValueKey('location-search-submit'),
                onPressed: busy || locating || searching ? null : search,
                icon: searching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(searching ? 'Searching…' : 'Search'))),
        const SizedBox(height: 6),
        const Text(
            'Search by Photon · © OpenStreetMap. Your search is sent only when you tap Search.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
        if (searchMessage != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(searchMessage!,
                  key: const ValueKey('location-search-message'),
                  style: const TextStyle(color: managementGreen))),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Select your pickup location',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final place in results)
            Card(
                elevation: 0,
                color: Colors.white,
                child: ListTile(
                    key: ValueKey('location-result-${place.id}'),
                    leading: const Icon(Icons.place_outlined,
                        color: managementGreen),
                    title: Text(place.name),
                    subtitle: Text(place.address,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing:
                        const Icon(Icons.add_location_alt_outlined, size: 20),
                    onTap: busy ? null : () => choosePlace(place))),
        ],
      ]);

  Widget coordinatePanel() => Column(children: [
        TextField(
            key: const ValueKey('business-coordinate-pair'),
            controller: coordinatePair,
            enabled: !busy && !locating,
            decoration: const InputDecoration(
                labelText: 'Paste coordinates',
                hintText: '3.0567, 101.5851',
                prefixIcon: Icon(Icons.content_paste)),
            onSubmitted: (_) => applyPair()),
        const SizedBox(height: 8),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                key: const ValueKey('business-apply-coordinates'),
                onPressed: busy || locating ? null : applyPair,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Apply coordinates'))),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: coordinateField(isLatitude: true)),
          const SizedBox(width: 12),
          Expanded(child: coordinateField(isLatitude: false)),
        ]),
        const SizedBox(height: 6),
        const Text(
            'Use a pickup point inside the Subang Jaya / USJ pilot area.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]);

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Your shop, on the map',
                style: TextStyle(
                    color: managementInk,
                    fontSize: 25,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
                'Give customers a clear pickup address and an accurate shop pin. Your details appear after you save and receive admin approval.'),
            const SizedBox(height: 20),
            TextFormField(
                key: const ValueKey('business-name'),
                controller: name,
                enabled: !busy,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                decoration: const InputDecoration(
                    labelText: 'Shop name',
                    prefixIcon: Icon(Icons.storefront_outlined)),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your shop name.'
                    : null),
            const SizedBox(height: 12),
            TextFormField(
                key: const ValueKey('business-address'),
                controller: address,
                enabled: !busy,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 300,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Full pickup address',
                    hintText: 'Unit, street, postcode, Subang Jaya'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the full shop pickup address.'
                    : null),
            const SizedBox(height: 18),
            const Text('Pickup location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Search location'),
                      icon: Icon(Icons.search)),
                  ButtonSegment(
                      value: true,
                      label: Text('Coordinates'),
                      icon: Icon(Icons.pin_drop_outlined)),
                ],
                selected: {
                  coordinateMode
                },
                onSelectionChanged:
                    busy ? null : (values) => switchMode(values.first)),
            const SizedBox(height: 16),
            if (coordinateMode) coordinatePanel() else searchPanel(),
            const SizedBox(height: 18),
            IgnorePointer(
                ignoring: busy || locating,
                child: BusinessMapPicker(
                    selected: selected,
                    onSelected: select,
                    onInteraction: () => setState(invalidateRequest))),
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: busy || locating ? null : useLocation,
                icon: locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(locating
                    ? 'Finding current location…'
                    : 'Use my current location')),
            const Text(
                'Use your current location only when you are at the shop. Tap the map or drag the pin to adjust it.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            if (locationMessage != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(locationMessage!,
                      style: const TextStyle(color: Colors.deepOrange))),
            const SizedBox(height: 16),
            ManagementCard(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.storefront_outlined, color: managementGreen),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(selected == null
                          ? 'No shop pin selected. The map center is a preview.'
                          : 'Selected pickup point: ${selected!.latitude.toStringAsFixed(6)}, ${selected!.longitude.toStringAsFixed(6)}\nReview the address above, then save your business profile.')),
                ])),
            const SizedBox(height: 16),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
                key: const ValueKey('save-business-profile'),
                onPressed: busy || locating || searching ? null : save,
                icon: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(busy ? 'Saving…' : 'Save business profile')),
            const SizedBox(height: 18),
          ])));
}

class BusinessMapPicker extends StatefulWidget {
  const BusinessMapPicker(
      {super.key,
      required this.selected,
      required this.onSelected,
      this.onInteraction});
  final LatLng? selected;
  final ValueChanged<LatLng> onSelected;
  final VoidCallback? onInteraction;

  @override
  State<BusinessMapPicker> createState() => _BusinessMapPickerState();
}

class _BusinessMapPickerState extends State<BusinessMapPicker> {
  final controller = MapController();
  TileProvider? tiles;
  bool ready = false, failed = false;
  Offset dragOffset = Offset.zero;
  Offset? dragOrigin;
  Offset? pointerOrigin;
  int? dragPointer;
  double minimumZoom = 10;
  static const center = LatLng(3.0567, 101.5851);
  static final bounds = LatLngBounds(
      const LatLng(pilotSouth, pilotWest), const LatLng(pilotNorth, pilotEast));
  static final fit =
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24));

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
  void didUpdateWidget(covariant BusinessMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.selected;
    if (ready && next != null && next != oldWidget.selected) {
      controller.move(
          next, controller.camera.zoom < 15 ? 15 : controller.camera.zoom);
    }
  }

  void tileFailed() {
    if (failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !failed) setState(() => failed = true);
    });
  }

  void finishDrag() {
    final origin = dragOrigin;
    if (origin == null) return;
    // Project the moved pin tip through the current map camera; no fake/clamped point.
    final point = controller.camera.screenOffsetToLatLng(origin + dragOffset);
    setState(() {
      dragOrigin = null;
      dragOffset = Offset.zero;
      pointerOrigin = null;
      dragPointer = null;
    });
    widget.onSelected(point);
  }

  void zoom(double delta) {
    if (!ready) return;
    controller.move(controller.camera.center,
        (controller.camera.zoom + delta).clamp(minimumZoom, 19));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 310,
      child: LayoutBuilder(builder: (context, constraints) {
        minimumZoom = fit
            .fit(MapCamera(
                crs: const Epsg3857(),
                center: center,
                zoom: 13,
                rotation: 0,
                nonRotatedSize:
                    Size(constraints.maxWidth, constraints.maxHeight)))
            .zoom;
        return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(children: [
              FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                      initialCenter: widget.selected ?? center,
                      initialZoom: widget.selected == null ? 13 : 16,
                      cameraConstraint:
                          CameraConstraint.containCenter(bounds: bounds),
                      interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                      minZoom: minimumZoom,
                      maxZoom: 19,
                      onMapReady: () => ready = true,
                      onTap: (_, point) => widget.onSelected(point)),
                  children: [
                    CleanMapTiles(
                        child: TileLayer(
                            urlTemplate: const String.fromEnvironment(
                                'MAP_TILE_URL',
                                defaultValue:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                            userAgentPackageName: 'com.foodienoms.foodienoms',
                            tileProvider: tiles,
                            maxNativeZoom: 19,
                            panBuffer: 0,
                            errorTileCallback: (_, __, ___) => tileFailed())),
                    if (widget.selected != null)
                      MarkerLayer(markers: [
                        Marker(
                            point: widget.selected!,
                            height: 59,
                            width: 50,
                            alignment: Alignment.topCenter,
                            child: Semantics(
                                label: 'Selected shop location',
                                // The map's scale recognizer wins against a
                                // normal pan recognizer. Claim only touches on
                                // this pin immediately; leave the map free
                                // everywhere else.
                                child: RawGestureDetector(
                                    key: const ValueKey('business-shop-pin'),
                                    behavior: HitTestBehavior.opaque,
                                    gestures: {
                                      EagerGestureRecognizer:
                                          GestureRecognizerFactoryWithHandlers<
                                                  EagerGestureRecognizer>(
                                              EagerGestureRecognizer.new,
                                              (_) {}),
                                    },
                                    child: Listener(
                                        behavior: HitTestBehavior.opaque,
                                        onPointerDown: (event) {
                                          if (dragPointer != null) return;
                                          widget.onInteraction?.call();
                                          setState(() {
                                            dragPointer = event.pointer;
                                            pointerOrigin = event.position;
                                            dragOrigin = controller.camera
                                                .latLngToScreenOffset(
                                                    widget.selected!);
                                            dragOffset = Offset.zero;
                                          });
                                        },
                                        onPointerMove: (event) {
                                          if (event.pointer != dragPointer ||
                                              pointerOrigin == null) {
                                            return;
                                          }
                                          setState(() => dragOffset =
                                              event.position - pointerOrigin!);
                                        },
                                        onPointerUp: (event) {
                                          if (event.pointer == dragPointer) {
                                            finishDrag();
                                          }
                                        },
                                        onPointerCancel: (event) {
                                          if (event.pointer != dragPointer) {
                                            return;
                                          }
                                          setState(() {
                                            dragPointer = null;
                                            pointerOrigin = null;
                                            dragOrigin = null;
                                            dragOffset = Offset.zero;
                                          });
                                        },
                                        child: Transform.translate(
                                            offset: dragOffset,
                                            child: const ShopPinMarker(
                                                selected: true,
                                                draggable: true)))))),
                      ]),
                  ]),
              Positioned(
                  left: 10,
                  top: 10,
                  right: 70,
                  child: IgnorePointer(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x120E3525),
                                    blurRadius: 12,
                                    offset: Offset(0, 3))
                              ]),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        widget.selected == null
                                            ? 'Choose your pickup point'
                                            : 'Your pickup point',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: managementInk)),
                                    const SizedBox(height: 2),
                                    Text(
                                        widget.selected == null
                                            ? 'Tap the map to add a shop pin'
                                            : 'Drag the pin to adjust',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54)),
                                  ]))))),
              Positioned(
                  right: 10,
                  top: 10,
                  child: MapControlStack(
                      onZoomIn: () => zoom(1),
                      onZoomOut: () => zoom(-1),
                      onLocate: () {
                        if (ready) {
                          controller.move(widget.selected ?? center, 16);
                        }
                      },
                      zoomInLabel: 'Zoom in on shop map',
                      zoomOutLabel: 'Zoom out on shop map',
                      locateLabel: 'Center on shop pin')),
              if (failed)
                const Positioned(
                    left: 8,
                    right: 8,
                    bottom: 30,
                    child: ColoredBox(
                        color: Color(0xEEFFFFFF),
                        child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                                'Map unavailable. Search for your shop or enter coordinates.',
                                style: TextStyle(fontSize: 11))))),
              const Positioned(bottom: 0, right: 0, child: MapAttribution()),
            ]));
      }));
}
