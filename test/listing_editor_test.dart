import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/listing_editor.dart';
import 'package:foodienoms/firebase/listing_editor_model.dart';
import 'package:foodienoms/firebase/service.dart';

final business = <String, dynamic>{
  'businessName': 'Subang Cafe',
  'address': '8 Jalan SS15',
  'latitude': 3.075,
  'longitude': 101.59,
  'configured': true,
  'approved': true,
  'vendorId': 'vendor'
};
ListingEditorModel completeModel() => ListingEditorModel.empty()
  ..title = 'Tofu lunch'
  ..description = 'Rice and tofu'
  ..priceText = '8.90'
  ..originalPriceText = '12.90'
  ..quantityText = '4';
Finder primary() => find.byKey(const ValueKey('listing-primary-action'));
Finder field(String name) => find.byKey(ValueKey('listing-$name'));
Future<void> enter(WidgetTester t, Finder target, String text) async {
  await t.ensureVisible(target);
  await t.enterText(target, text);
  await t.pumpAndSettle();
}

Future<void> next(WidgetTester t) async {
  await t.tap(primary());
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'validates each step, clears corrected errors, and keeps earlier values',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: ListingEditorForm(
            initial: ListingEditorModel.empty(),
            business: business,
            onSaveDraft: (_, __) async {},
            onPublish: (_, __, ___) async {})));
    await next(t);
    expect(find.text('Enter a food name of 1–100 characters.'), findsOneWidget);
    await enter(t, field('title'), 'Tofu lunch');
    expect(find.text('Enter a food name of 1–100 characters.'), findsNothing);
    await t.ensureVisible(field('description'));
    await enter(t, field('description'), 'Rice and tofu');
    await next(t);
    expect(find.text('Pricing & quantity'), findsOneWidget);
    await enter(t, field('originalPriceText'), '12.90');
    await t.ensureVisible(field('priceText'));
    await enter(t, field('priceText'), '13.00');
    await t.ensureVisible(field('quantityText'));
    await enter(t, field('quantityText'), '4');
    await next(t);
    expect(find.text('Student price must be lower than the original price.'),
        findsOneWidget);
    await t.ensureVisible(field('priceText'));
    await enter(t, field('priceText'), '8.90');
    expect(find.text('Student price must be lower than the original price.'),
        findsNothing);
    await t.tap(find.byTooltip('Previous step'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(field('title')).controller!.text, 'Tofu lunch');
    await next(t);
    expect(t.widget<TextField>(field('priceText')).controller!.text, '8.90');
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'saves an incomplete draft, prevents duplicate saves, and keeps data on failure',
      (t) async {
    final pending = Completer<void>();
    var calls = 0;
    ListingEditorModel? saved;
    await t.pumpWidget(MaterialApp(
        home: ListingEditorForm(
            initial: ListingEditorModel.empty(),
            business: business,
            onSaveDraft: (m, _) {
              calls++;
              saved = m;
              return pending.future;
            },
            onPublish: (_, __, ___) async {})));
    await enter(t, field('title'), 'Unfinished lunch');
    await t.tap(find.text('Save draft'));
    await t.pump();
    await t.tap(find.text('Save draft'));
    expect(calls, 1);
    expect(saved!.title, 'Unfinished lunch');
    expect(saved!.priceText, isEmpty);
    pending.completeError(StateError('Network unavailable. Retry.'));
    await t.pumpAndSettle();
    expect(find.textContaining('Network unavailable'), findsOneWidget);
    expect(t.widget<TextField>(field('title')).controller!.text,
        'Unfinished lunch');
  });
  testWidgets(
      'publishing failure preserves form and retry submits once while busy',
      (t) async {
    var calls = 0;
    var finished = false;
    final pending = Completer<void>();
    await t.pumpWidget(MaterialApp(
        home: ListingEditorForm(
            initial: completeModel(),
            business: business,
            onSaveDraft: (_, __) async {},
            onPublish: (m, _, __) {
              calls++;
              return calls == 1
                  ? Future.error(StateError('Could not publish. Try again.'))
                  : pending.future;
            },
            onFinished: (value) => finished = value)));
    await next(t);
    await next(t);
    await next(t);
    expect(find.textContaining('Could not publish'), findsOneWidget);
    expect(finished, isFalse);
    await t.tap(primary());
    await t.pump();
    await t.tap(primary());
    expect(calls, 2);
    pending.complete();
    await t.pumpAndSettle();
    expect(finished, isTrue);
  });
  testWidgets('unsaved edits prompt before leaving and keep editing works',
      (t) async {
    var left = false;
    await t.pumpWidget(MaterialApp(
        home: ListingEditorForm(
            initial: ListingEditorModel.empty(),
            business: business,
            onSaveDraft: (_, __) async {},
            onPublish: (_, __, ___) async {},
            onFinished: (_) => left = true)));
    await enter(t, field('title'), 'Changed');
    await t.tap(find.byTooltip('Leave listing'));
    await t.pumpAndSettle();
    expect(find.text('Leave this listing?'), findsOneWidget);
    await t.tap(find.text('Keep editing'));
    await t.pumpAndSettle();
    expect(left, isFalse);
    expect(t.widget<TextField>(field('title')).controller!.text, 'Changed');
  });
  testWidgets('stock conflict returns to quantity review with form kept',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: ListingEditorForm(
            initial: completeModel()..quantityText = '6',
            business: business,
            editing: true,
            initialStock: 4,
            onSaveDraft: (_, __) async {},
            onPublish: (_, __, ___) async {
              throw ListingStockChanged(3);
            })));
    await next(t);
    await next(t);
    await next(t);
    expect(find.text('Pricing & quantity'), findsOneWidget);
    expect(find.textContaining('Current available stock: 3'), findsOneWidget);
    expect(t.widget<TextField>(field('quantityText')).controller!.text, '6');
  });
  testWidgets(
      'partial saved draft restores values and three steps fit narrow screens with keyboard',
      (t) async {
    final originalError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      originalError?.call(details);
    };
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final model = completeModel();
    await t.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(1.25),
                viewInsets: EdgeInsets.only(bottom: 240)),
            child: ListingEditorForm(
                initial: ListingEditorModel.fromDraft(model.toDraft()),
                business: business,
                resumedDraft: true,
                onSaveDraft: (_, __) async {},
                onPublish: (_, __, ___) async {}))));
    expect(t.widget<TextField>(field('title')).controller!.text, 'Tofu lunch');
    for (var i = 0; i < 2; i++) {
      await next(t);
      expect(t.takeException(), isNull);
    }
    expect(find.text('Pickup & publish'), findsOneWidget);
  });
}
