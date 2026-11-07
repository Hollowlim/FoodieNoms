import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/listing_editor_model.dart';

void main() {
  final now = DateTime(2026, 11, 6, 14);
  ListingEditorModel valid() => ListingEditorModel(
      title: 'Tofu lunch',
      category: 'Meals',
      description: 'Rice and tofu',
      priceText: '8.90',
      originalPriceText: '12.90',
      quantityText: '4',
      startsNow: false,
      pickupStart: now.millisecondsSinceEpoch,
      pickupEnd: now.add(const Duration(hours: 2)).millisecondsSinceEpoch);

  test('required content and bounded optional fields', () {
    final model = ListingEditorModel.empty(now: now);
    expect(model.validateStep(0).keys, containsAll(['title', 'description']));
    model.title = 'Lunch';
    model.description = 'Rice';
    expect(model.validateStep(0), isEmpty);
    model.ingredients = 'a' * 501;
    model.allergens = 'a' * 501;
    model.foodDescription = 'a' * 1001;
    model.category = 'Unknown';
    expect(
        model.validateStep(0).keys,
        containsAll(
            ['ingredients', 'allergens', 'foodDescription', 'category']));
  });
  test('RM parser rejects negatives, fractions, nonfinite and excessive values',
      () {
    for (final text in [
      '',
      '0',
      '-1',
      '8.999',
      'NaN',
      '1e3',
      '10000.01',
      '.5',
      '8.'
    ]) {
      expect(listingRmCents(text), isNull, reason: text);
    }
    expect(listingRmCents('0.01'), 1);
    expect(listingRmCents(' 12.90 '), 1290);
    expect(listingRmCents('8.9'), 890);
    expect(listingMoney(890), 'RM 8.90');
  });
  test('strict student discount and integer quantity validation', () {
    final model = valid();
    expect(model.validateStep(1), isEmpty);
    expect(model.discountPercent, 31);
    expect(model.savingsCents, 400);
    for (final text in ['12.90', '13.00']) {
      model.priceText = text;
      expect(model.validateStep(1), contains('priceText'));
    }
    model.priceText = '8.90';
    for (final text in ['0', '-1', '1.5', '', '10001']) {
      model.quantityText = text;
      expect(model.validateStep(1), contains('quantityText'));
    }
    model.quantityText = '0';
    expect(model.validateStep(1, editing: true), isEmpty);
  });
  test('pickup times enforce end, grace, horizon and editing an ongoing window',
      () {
    final model = valid();
    expect(model.validateStep(2, now: now), isEmpty);
    model.pickupEnd = model.pickupStart;
    expect(model.validateStep(2, now: now), contains('pickupEnd'));
    model.pickupEnd = now.add(const Duration(hours: 2)).millisecondsSinceEpoch;
    model.pickupStart =
        now.subtract(const Duration(minutes: 6)).millisecondsSinceEpoch;
    expect(model.validateStep(2, now: now), contains('pickupStart'));
    expect(model.validateStep(2, now: now, editing: true), isEmpty);
    model.startsNow = true;
    expect(model.validateStep(2, now: now), isEmpty);
    expect(model.toListingData(now: now)['pickupStart'],
        now.millisecondsSinceEpoch);
    model.pickupEnd = now.add(const Duration(days: 31)).millisecondsSinceEpoch;
    expect(model.validateStep(2, now: now), contains('pickupEnd'));
    model.pickupEnd =
        now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;
    expect(model.validateStep(2, now: now), contains('pickupEnd'));
  });
  test(
      'partial draft round trip retains unfinished values, content, tags and photo',
      () {
    final model = valid()
      ..priceText = '8.'
      ..quantityText = ''
      ..imageId = 'a' * 32
      ..ingredients = 'Tofu'
      ..allergens = 'Soy'
      ..dietaryTags = ['Vegan']
      ..halalStatus = 'vendor_declared';
    final restored = ListingEditorModel.fromDraft(model.toDraft());
    expect(restored.toDraft(), model.toDraft());
    expect(restored.dietarySummary, contains('certification not verified'));
    expect(
        ListingEditorModel.fromDraft({'halalStatus': 'halal_certified'})
            .halalStatus,
        'not_declared');
  });
  test(
      'List Again keeps food details while clearing prices, stock and all times',
      () {
    final data = valid().toListingData(now: now);
    final model = ListingEditorModel.fromListing({...data, 'imageId': 'a' * 32},
        duplicate: true);
    expect(model.title, 'Tofu lunch');
    expect(model.imageId, 'a' * 32);
    expect(model.priceText, isEmpty);
    expect(model.originalPriceText, isEmpty);
    expect(model.quantityText, isEmpty);
    expect(model.pickupStart, isNull);
    expect(model.pickupEnd, isNull);
    expect(model.validateStep(1), isNotEmpty);
    expect(model.validateStep(2, now: now), isNotEmpty);
  });
  test('editing avoids overwriting unchanged stock and guards changed stock',
      () {
    final model = valid();
    expect(
        model.toListingData(
            now: now, editing: true, initialStock: 4, expectedStock: 4),
        isNot(contains('stock')));
    model.quantityText = '6';
    final data = model.toListingData(
        now: now, editing: true, initialStock: 4, expectedStock: 3);
    expect(data['stock'], 6);
    expect(data['expectedStock'], 3);
    model.quantityText = '4';
    expect(
        model.toListingData(
            now: now,
            editing: true,
            initialStock: 4,
            expectedStock: 3)['stock'],
        4);
    expect(data, isNot(contains('vendorId')));
    expect(data, isNot(contains('latitude')));
  });
}
