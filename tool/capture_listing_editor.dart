// Offline visual review of the production editor. No Firebase writes or network.
// Run: flutter test tool/capture_listing_editor.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/listing_editor.dart';
import 'package:foodienoms/firebase/listing_editor_model.dart';

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
  testWidgets('capture production listing editor at iPhone width', (t) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                useMaterial3: true,
                fontFamily: 'Roboto',
                colorScheme:
                    ColorScheme.fromSeed(seedColor: const Color(0xFF153D29))),
            home: ListingEditorForm(
                initial: ListingEditorModel.empty()
                  ..title = 'Bakery Surprise Bag'
                  ..category = 'Bakery'
                  ..imageKey = 'photo-0'
                  ..description =
                      'A selection of today’s freshly baked bread and pastries. Contents vary.'
                  ..originalPriceText = '20.00'
                  ..priceText = '8.00'
                  ..quantityText = '4',
                business: const {
                  'businessName': 'Subang Bakery',
                  'address': '12 Jalan SS15/4, Subang Jaya'
                },
                onSaveDraft: (_, __) async {},
                onPublish: (_, __, ___) async {}))));
    await t.pumpAndSettle();
    await t.runAsync(() => precacheImage(
        const AssetImage('assets/reference/food_photography_sheet.png'),
        key.currentContext!));
    await t.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/listing-preview').create(recursive: true);
        await File('build/listing-preview/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('1-food-details');
    for (final name in ['2-pricing-quantity', '3-pickup-publish']) {
      await t.tap(find.byKey(const ValueKey('listing-primary-action')));
      await t.pumpAndSettle();
      await capture(name);
    }
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    await capture('4-student-preview');
  });
}
