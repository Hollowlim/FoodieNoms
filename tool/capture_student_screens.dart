// Run: flutter test tool/capture_student_screens.dart
// Writes reference renders to /tmp without requiring Firebase credentials.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/app.dart';
import 'package:foodienoms/firebase/customer_preview.dart';
import 'package:foodienoms/firebase/student_ui.dart';
import 'package:foodienoms/firebase/reference_assets.dart';

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
            .then((bytes) => ByteData.sublistView(bytes)));
      await font.load();
    }
  });
  testWidgets('logo blends white into cream without tinting its surroundings',
      (tester) async {
    tester.view.physicalSize = const Size(200, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: const MaterialApp(
            home: ColoredBox(
                color: studentCream,
                child: Center(
                    child: BrandLogo(
                        width: 100,
                        height: 100,
                        backgroundColor: studentCream))))));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/foodienoms_logo.png'), key.currentContext!));
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      List<int> pixel(int x, int y) => data.sublist(
          (y * image.width + x) * 4, (y * image.width + x) * 4 + 4);
      expect(pixel(2, 2), [250, 249, 243, 255]);
      expect(pixel(51, 51), [250, 249, 243, 255]);
      expect(pixel(100, 100), isNot([250, 249, 243, 255]));
      image.dispose();
    });
  });
  for (final page in ['home', 'profile']) {
    testWidgets('render $page at iPhone width', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final location = PilotLocation();
      addTearDown(location.dispose);
      final key = GlobalKey();
      final home = page == 'home';
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                useMaterial3: true,
                fontFamily: 'Roboto',
                scaffoldBackgroundColor: studentCream,
                colorScheme: ColorScheme.fromSeed(seedColor: studentGreen)),
            home: Scaffold(
              appBar: home
                  ? null
                  : AppBar(
                      backgroundColor: studentCream,
                      title: const Text('FoodieNoms',
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w700))),
              body: home
                  ? Column(children: [
                      StudentDiscoverHeader(
                          location: location, onSearch: (_) {}),
                      const Expanded(child: CustomerPreview())
                    ])
                  : StudentProfilePanel(
                      name: 'Student Account',
                      email: 'student@example.com',
                      onPersonalInfo: () {},
                      onReviews: () {},
                      onNotifications: () {},
                      onLocation: () {},
                      onSettings: () {},
                      onLogout: () {}),
              bottomNavigationBar: FoodieNavigation(
                  role: 'customer',
                  selectedIndex: home ? 0 : 3,
                  onSelected: (_) {}),
            ),
          )));
      await tester.runAsync(() => Future.wait([
            precacheImage(const AssetImage('assets/foodienoms_logo.png'),
                key.currentContext!),
            precacheImage(
                const AssetImage(referenceFoodSheet), key.currentContext!),
            precacheImage(const AssetImage(referenceMap), key.currentContext!),
          ]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(home ? 'Rescue delicious food.' : 'My profile'),
          findsOneWidget);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/foodienoms-$page-design.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
