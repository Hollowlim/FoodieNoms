import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/pickup_ui.dart';
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
            .then((b) => ByteData.sublistView(b)));
      await font.load();
    }
  });
  for (final page in ['qr', 'review', 'photos']) {
    testWidgets('render pickup $page', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final order = {
        'code': 'FN-0123456789ABCDEF0123',
        'status': 'reserved',
        'title': 'Chicken Rice Box',
        'vendorName': 'Test Cafe',
        'quantity': 2,
        'pickupStart': 1800000000000,
        'pickupEnd': 1800003600000,
        'address': '1 Example Street, Subang Jaya',
        'totalCents': 1600,
        'priceCents': 800,
        'originalPriceCents': 2000,
        'dietary': 'Contains soy and egg'
      };
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  fontFamily: 'Roboto',
                  scaffoldBackgroundColor: studentCream,
                  colorScheme: ColorScheme.fromSeed(seedColor: studentGreen)),
              home: Scaffold(
                  appBar: AppBar(
                      title: Text(page == 'qr'
                          ? 'Order details'
                          : page == 'review'
                              ? 'Review'
                              : 'Edit food listing')),
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: page == 'qr'
                              ? PickupPass(order: order)
                              : page == 'review'
                                  ? ReservationReview(
                                      listing: order, quantity: 2)
                                  : ListingPhotoPicker(
                                      selected: 1, onSelected: (_) {})))))));
      if (page == 'photos') {
        await tester.runAsync(() => precacheImage(
            const AssetImage(referenceFoodSheet), key.currentContext!));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 2);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/foodienoms-pickup-$page.png')
            .writeAsBytes(data!.buffer.asUint8List());
        img.dispose();
      });
    });
  }
}
