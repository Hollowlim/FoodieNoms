// Offline visual checks at iPhone width; example shops are fixture data.
// Run: flutter test tool/capture_location_screens.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:foodienoms/firebase/live_location_map.dart';
import 'package:foodienoms/firebase/customer_map_panel.dart';
import 'package:foodienoms/firebase/location_state.dart';
import 'package:foodienoms/firebase/place_search.dart';
import 'package:foodienoms/firebase/vendor_business.dart';

class _PreviewTiles extends TileProvider {
  _PreviewTiles(this.bytes);
  final Uint8List bytes;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(bytes);
}

// A fictional street grid for layout inspection, never used by the app.
Future<Uint8List> _previewTile() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFF0F3ED), BlendMode.src);
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(15, 15, 84, 48), const Radius.circular(8)),
      Paint()..color = const Color(0xFFDAE8D4));
  for (final x in [40.0, 140.0, 228.0]) {
    canvas.drawLine(
        Offset(x, 0),
        Offset(x, 256),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 12);
  }
  for (final y in [80.0, 180.0]) {
    canvas.drawLine(
        Offset(0, y),
        Offset(256, y),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 12);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  setUpAll(() async {
    final directory =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final font in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf')
    ]) {
      await (FontLoader(font.$1)
            ..addFont(File('$directory/${font.$2}')
                .readAsBytes()
                .then(ByteData.sublistView)))
          .load();
    }
  });
  for (final page in ['client', 'vendor']) {
    testWidgets('render clean $page map', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final location = PilotLocation();
      addTearDown(location.dispose);
      final key = GlobalKey();
      final tile = await tester.runAsync(_previewTile);
      await tester.pumpWidget(MapTileProviderScope(
          provider: _PreviewTiles(tile!),
          child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(
                      useMaterial3: true,
                      fontFamily: 'Roboto',
                      colorScheme: ColorScheme.fromSeed(
                          seedColor: const Color(0xFF205F45)),
                      scaffoldBackgroundColor: const Color(0xFFFAF9F3),
                      inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder())),
                  home: Scaffold(
                      appBar: AppBar(
                          title: Text(page == 'client'
                              ? 'FoodieNoms'
                              : 'Business profile')),
                      body: page == 'client'
                          ? CustomerMapPanel(
                              location: location,
                              shops: const [
                                ShopMapPin(
                                    id: 'bakery',
                                    name: 'Subang Bakery',
                                    address: 'SS15, Subang Jaya',
                                    latitude: 3.0567,
                                    longitude: 101.5851),
                                ShopMapPin(
                                    id: 'cafe',
                                    name: 'Campus Cafe',
                                    address: 'USJ 2, Subang Jaya',
                                    latitude: 3.060,
                                    longitude: 101.590),
                              ],
                              onShopTap: (_) {},
                              onChangeLocation: () {})
                          : VendorBusinessForm(
                              initialData: const {
                                  'businessName': 'Subang Bakery',
                                  'address': '12 Jalan SS15/4, Subang Jaya',
                                  'configured': true,
                                  'latitude': 3.0567,
                                  'longitude': 101.5851,
                                },
                              searchPlaces: (_) async => const [
                                    PlaceSearchResult(
                                        id: 'sample',
                                        name: 'Subang Bakery',
                                        address: '12 Jalan SS15/4, Subang Jaya',
                                        latitude: 3.0567,
                                        longitude: 101.5851),
                                  ],
                              onSave: (
                                  {required businessName,
                                  required address,
                                  required latitude,
                                  required longitude}) async {}))))));
      await tester.pumpAndSettle();
      if (page == 'vendor') {
        await tester.drag(find.byType(ListView).first, const Offset(0, -450));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/foodienoms-clean-$page-map.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
