import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:foodienoms/firebase/listing_photo.dart';
import 'package:foodienoms/firebase/service.dart';

void main() {
  test('compresses noisy food photos to bounded decodable JPEG', () {
    final source = img.Image(width: 1400, height: 1000);
    final random = Random(42);
    for (final p in source) {
      p.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
    }
    final result = prepareListingPhoto(img.encodePng(source));
    expect(result.bytes.length, lessThanOrEqualTo(maxListingPhotoBytes));
    expect(result.width, lessThanOrEqualTo(1024));
    final decoded = img.decodeJpg(result.bytes)!;
    expect(decoded.width, result.width);
    expect(decoded.height, result.height);
    expect(decoded.exif.imageIfd.isEmpty, isTrue);
    expect(decoded.exif.gpsIfd.isEmpty, isTrue);
  });
  test(
      'normalizes EXIF orientation and removes the source location and description',
      () {
    final source = img.Image(width: 60, height: 30);
    source.exif.imageIfd.orientation = 6;
    source.exif.imageIfd.imageDescription = 'Private original metadata';
    source.exif.gpsIfd.gpsLatitudeRef = 'N';
    source.exif.gpsIfd.gpsLatitude = 3.075;
    source.exif.gpsIfd.gpsLongitudeRef = 'E';
    source.exif.gpsIfd.gpsLongitude = 101.59;
    final input = img.encodeJpg(source);
    expect(img.decodeJpg(input)!.exif.gpsIfd.isEmpty, isFalse);
    final result = prepareListingPhoto(input);
    final output = img.decodeJpg(result.bytes)!;
    expect(result.width, 30);
    expect(result.height, 60);
    expect(output.exif.imageIfd.isEmpty, isTrue);
    expect(output.exif.gpsIfd.isEmpty, isTrue);
  });
  test('rejects corrupt, oversized and empty photo data with a helpful error',
      () {
    for (final input in [
      img.encodeJpg(img.Image(width: 1, height: 1)).sublist(0, 3),
      List<int>.empty(),
      List<int>.filled(12 * 1024 * 1024 + 1, 0)
    ]) {
      expect(() => prepareListingPhoto(Uint8List.fromList(input)),
          throwsA(isA<FoodPhotoException>()));
    }
  });
  testWidgets(
      'illustrative fallback stays labelled and real image errors never show a generic photo',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
            width: 200,
            height: 150,
            child: ListingFoodPhoto(
                service: null, listing: {'imageKey': 'photo-1'}))));
    expect(find.text('Illustrative'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
            width: 200,
            height: 150,
            child: ListingFoodPhoto(
                service: null,
                listing: {'imageId': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}))));
    expect(find.text('Vendor photo'), findsOneWidget);
    expect(find.text('Illustrative'), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}
