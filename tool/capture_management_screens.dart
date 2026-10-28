// Run: flutter test tool/capture_management_screens.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/admin_preview.dart';
import 'package:foodienoms/firebase/management_ui.dart';

void main() {
  setUpAll(() async {
    final directory =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final item in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf')
    ]) {
      final font = FontLoader(item.$1)
        ..addFont(File('$directory/${item.$2}')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)));
      await font.load();
    }
  });
  for (final page in ['admin-phone', 'admin-desktop', 'vendor']) {
    testWidgets('render $page', (tester) async {
      tester.view.physicalSize = page == 'admin-desktop'
          ? const Size(1440, 1100)
          : const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'Roboto',
                colorScheme: ColorScheme.fromSeed(seedColor: managementGreen),
                scaffoldBackgroundColor: managementCream),
            home: page.startsWith('admin')
                ? const AdminPreview()
                : Scaffold(
                    appBar: AppBar(
                        title: const Text('FoodieNoms'),
                        backgroundColor: managementGreen,
                        foregroundColor: Colors.white),
                    body: ListView(children: [
                      const VendorBanner(),
                      Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Vendor dashboard',
                                    style: TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 16),
                                const ManagementCard(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('Active listings: 0'),
                                      SizedBox(height: 8),
                                      Text('Pending reservations: 0')
                                    ])),
                                FilledButton(
                                    onPressed: () {},
                                    child: const Text('+ Add Surplus Food')),
                                const SizedBox(height: 18),
                                const Text('Your listings',
                                    style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 18),
                                const Text(
                                    'No listings yet. Publish your first surplus meal once approved.'),
                              ]))
                    ]),
                  ),
          )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/foodienoms-$page.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
