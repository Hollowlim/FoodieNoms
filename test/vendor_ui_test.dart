import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/vendor_ui.dart';
import 'package:foodienoms/firebase/service.dart';

Map<String, dynamic> listing(
        {bool active = true, int stock = 3, bool ended = false}) =>
    {
      'title': 'Bakery bag',
      'priceCents': 800,
      'category': 'Bakery',
      'address': '1 Test Street',
      'active': active,
      'stock': stock,
      'pickupStart': DateTime.now().millisecondsSinceEpoch,
      'pickupEnd': DateTime.now()
          .add(Duration(hours: ended ? -1 : 2))
          .millisecondsSinceEpoch,
    };
void main() {
  test(
      'vendor statuses distinguish draft, unavailable, sold-out and expired food',
      () {
    expect(vendorListingStatus(listing()), 'Active');
    expect(
        vendorListingStatus({
          'formData': {'title': 'Draft food'}
        }),
        'Draft');
    expect(vendorListingStatus(listing(active: false)), 'Unavailable');
    expect(vendorListingStatus(listing(stock: 0)), 'Sold out');
    expect(vendorListingStatus(listing(active: false, ended: true)), 'Expired');
  });
  test(
      'stock adjustments reject invalid amounts and preserve current inventory',
      () {
    expect(adjustedVendorStock(3, 1), 4);
    expect(adjustedVendorStock(1, -1), 0);
    expect(() => adjustedVendorStock(0, -1), throwsStateError);
    expect(() => adjustedVendorStock(10000, 1), throwsStateError);
  });
  testWidgets(
      'pending vendors see onboarding, status check and sign out instead of publishing',
      (tester) async {
    var checked = false;
    var signedOut = false;
    await tester.pumpWidget(MaterialApp(
        home: VendorPendingContent(
            email: 'vendor@example.test',
            onCheck: () => checked = true,
            onSignOut: () => signedOut = true)));
    expect(find.text('Your business is pending approval'), findsOneWidget);
    expect(find.text('Add Surplus Food'), findsNothing);
    await tester.scrollUntilVisible(find.text('Check approval status'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check approval status'));
    expect(checked, isTrue);
    await tester.scrollUntilVisible(find.text('Sign out'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    expect(signedOut, isTrue);
  });
  testWidgets(
      'vendor listing controls adjust stock and offer renewal for ended food',
      (tester) async {
    int? delta;
    var edited = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: VendorListingCard(
                    listing: listing(),
                    onEdit: () => edited = true,
                    onToggle: () {},
                    onAdjust: (value) => delta = value)))));
    await tester.tap(find.byTooltip('Add one item'));
    expect(delta, 1);
    await tester.tap(find.byTooltip('Remove one item'));
    expect(delta, -1);
    await tester.tap(find.text('Edit listing'));
    expect(edited, isTrue);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: VendorListingCard(
                    listing: listing(ended: true),
                    onEdit: () {},
                    onToggle: () {},
                    onAdjust: (_) {})))));
    expect(find.text('Renew pickup window'), findsOneWidget);
    final addButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline));
    expect(addButton.onPressed, isNull);
  });
  testWidgets('revoked vendors see the reason and can edit business details',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: VendorPendingContent(
            email: 'vendor@example.test',
            revoked: true,
            reason: 'Review required',
            onCheck: () {},
            onSignOut: () {},
            onBusiness: () => opened = true)));
    expect(find.text('Your selling access is revoked'), findsOneWidget);
    expect(find.text('Reason: Review required'), findsOneWidget);
    expect(find.text('Your business is pending approval'), findsNothing);
    await tester.scrollUntilVisible(
        find.text('Set up shop name & location'), 180);
    await tester.tap(find.text('Set up shop name & location'));
    expect(opened, isTrue);
  });

  testWidgets(
      'published and expired listings can be listed again with an injected photo',
      (tester) async {
    var duplicates = 0;
    var toggled = false;
    for (final ended in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: VendorListingCard(
                      listing: listing(ended: ended),
                      photo: const ColoredBox(
                          key: ValueKey('actual-food-photo'),
                          color: Colors.green),
                      onEdit: () {},
                      onToggle: () => toggled = true,
                      onAdjust: (_) {},
                      onDuplicate: () => duplicates++)))));
      expect(find.byKey(const ValueKey('actual-food-photo')), findsOneWidget);
      expect(find.text('Illustrative'), findsNothing);
      await tester.ensureVisible(find.text('List again'));
      await tester.tap(find.text('List again'));
      expect(duplicates, ended ? 2 : 1);
      if (!ended) {
        await tester.tap(find.text('Mark unavailable'));
        expect(toggled, isTrue);
      }
    }
  });

  testWidgets('sold-out listing stock can be replenished before reopening',
      (tester) async {
    int? delta;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: VendorListingCard(
                    listing: listing(active: false, stock: 0),
                    onEdit: () {},
                    onToggle: () {},
                    onAdjust: (value) => delta = value)))));
    final reopen = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Reopen listing'));
    expect(reopen.onPressed, isNull);
    await tester.tap(find.byTooltip('Add one item'));
    expect(delta, 1);
    final remove = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline));
    expect(remove.onPressed, isNull);
  });

  test('draft summaries preserve records and tolerate incomplete form data',
      () {
    const empty = VendorDraftRecord(id: 'empty', data: {'formData': {}});
    expect(empty.title, 'Untitled draft');
    expect(empty.category, isNull);
    expect(empty.savedAt, isNull);
    final savedAt = DateTime(2026, 11, 6, 14, 30);
    final saved = VendorDraftRecord(id: 'saved', data: {
      'formData': {'title': ' Bakery bag ', 'category': ' Bakery '},
      'updatedAt': Timestamp.fromDate(savedAt),
    });
    expect(saved.title, 'Bakery bag');
    expect(saved.category, 'Bakery');
    expect(saved.savedAt, savedAt);
  });

  testWidgets('saved drafts show private status and resume the full record',
      (tester) async {
    String? resumed;
    Map<String, dynamic>? restored;
    final record = {
      'vendorId': 'vendor-1',
      'formVersion': 1,
      'sourceListingId': 'listing-1',
      'formData': {'title': 'Bakery bag', 'category': 'Bakery', 'stock': '4'},
      'updatedAt': Timestamp.fromDate(DateTime(2026, 11, 6, 14, 30)),
    };
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: VendorDraftList(
                    drafts: [VendorDraftRecord(id: 'draft-1', data: record)],
                    onDelete: (_) async {},
                    onResume: (id, data) {
                      resumed = id;
                      restored = data;
                    })))));
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Private work in progress. Students cannot see drafts.'),
        findsOneWidget);
    expect(find.text('Bakery'), findsOneWidget);
    expect(find.text('Saved 6 Nov 2026 · 14:30'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resume-draft-draft-1')));
    expect(resumed, 'draft-1');
    expect(identical(restored, record), isTrue);
    expect(restored?['sourceListingId'], 'listing-1');
  });

  testWidgets(
      'draft deletion needs confirmation and prevents duplicate deletion',
      (tester) async {
    final deletion = Completer<void>();
    final deleted = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: VendorDraftList(
                    drafts: const [
          VendorDraftRecord(id: 'draft-1', data: {'formData': {}})
        ],
                    onResume: (_, __) {},
                    onDelete: (id) {
                      deleted.add(id);
                      return deletion.future;
                    })))));
    final deleteButton = find.byKey(const ValueKey('delete-draft-draft-1'));
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Delete this draft?'), findsOneWidget);
    expect(
        find.textContaining(
            'Published listings, photos and existing reservations are kept.'),
        findsOneWidget);
    await tester.tap(find.text('Keep draft'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete draft'));
    await tester.pump();
    expect(deleted, ['draft-1']);
    expect(find.text('Deleting…'), findsOneWidget);
    final resume = tester.widget<FilledButton>(
        find.byKey(const ValueKey('resume-draft-draft-1')));
    expect(resume.onPressed, isNull);
    deletion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Draft deleted.'), findsOneWidget);
  });

  testWidgets('draft loading, offline cache and failure states stay useful',
      (tester) async {
    Widget content(VendorDraftList child) =>
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
    await tester.pumpWidget(content(VendorDraftList(
        drafts: const [], loading: true, onDelete: (_) async {})));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No saved drafts yet'), findsNothing);
    var retried = false;
    await tester.pumpWidget(content(VendorDraftList(
        drafts: const [
          VendorDraftRecord(id: 'draft-1', data: {'formData': {}})
        ],
        fromCache: true,
        error: 'Check your connection.',
        onRetry: () => retried = true,
        onDelete: (_) async =>
            throw StateError('Unable to delete this draft.'))));
    expect(find.text('Untitled draft'), findsOneWidget);
    expect(find.text('Showing cached drafts. Updates sync when connected.'),
        findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
    await tester
        .ensureVisible(find.byKey(const ValueKey('delete-draft-draft-1')));
    await tester.tap(find.byKey(const ValueKey('delete-draft-draft-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete draft'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to delete this draft.'), findsOneWidget);
    expect(find.text('Untitled draft'), findsOneWidget);
  });

  testWidgets('management cards fit narrow phone screens with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          VendorListingCard(
              listing: {
                ...listing(),
                'title': 'A freshly baked surprise pastry selection'
              },
              photo: const ColoredBox(color: Colors.green),
              onEdit: () {},
              onToggle: () {},
              onAdjust: (_) {},
              onDuplicate: () {}),
          VendorDraftList(drafts: const [
            VendorDraftRecord(id: 'draft-1', data: {
              'formData': {
                'title': 'A draft with a longer food name',
                'category': 'Bakery'
              }
            })
          ], onResume: (_, __) {}, onDelete: (_) async {}),
        ])))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
