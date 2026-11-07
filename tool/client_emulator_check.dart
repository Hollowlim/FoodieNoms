// Runs the real FoodieService against the rules on local emulators and prints
// results to the browser console. Use tool/run_client_emulator_check.sh.
// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:foodienoms/firebase/listing_editor_model.dart';
import 'package:foodienoms/firebase/service.dart';

const emulatorOnly = FirebaseOptions(
    apiKey: 'demo',
    appId: '1:1:web:1',
    messagingSenderId: '1',
    projectId: 'demo-foodienoms');

late FoodieService service;

Future<void> signIn(String email) async {
  await FirebaseAuth.instance.signOut();
  await FirebaseAuth.instance
      .signInWithEmailAndPassword(email: email, password: 'emulator-only');
}

Future<String> publish(int stock, {int startsIn = 10}) async {
  final now = DateTime.now();
  final result = await service.call('publishListing', {
    'title': 'Lunch box',
    'description': 'Rice and vegetables',
    'address': '1 Test Street, Subang Jaya',
    'dietary': 'Contains soy',
    'category': 'Meals',
    'priceCents': 800,
    'originalPriceCents': 1500,
    'stock': stock,
    'pickupStart': now.add(Duration(minutes: startsIn)).millisecondsSinceEpoch,
    'pickupEnd': now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
  });
  return result['id'] as String;
}

Future<String> reserve(String listingId, int quantity) async {
  final result = await service.call('reserveListing', {
    'listingId': listingId,
    'quantity': quantity,
    'requestId': service.requestId(),
  });
  return result['code'] as String;
}

Future<void> expectStateError(Future<void> action, String text) async {
  // Checks the text users see, whatever type the platform's transaction throws.
  try {
    await action;
  } catch (e) {
    final message = firebaseMessage(e);
    if (message.contains(text)) return;
    throw 'User would see: $message [${e.runtimeType}]';
  }
  throw 'Expected an error containing "$text"';
}

void expectEqual(Object? actual, Object? expected) {
  if (actual != expected) throw 'Expected $expected, got $actual';
}

Future<void> journey() async {
  await signIn('vendor@example.test');
  final listingId = await publish(20);
  await signIn('student@example.test');
  final code = await reserve(listingId, 2);
  final db = FirebaseFirestore.instance;
  expectEqual((await db.doc('listings/$listingId').get()).data()!['stock'], 18);
  await signIn('vendor@example.test');
  await service.call('collectReservation', {'code': code});
  expectEqual((await db.doc('reservations/$code').get()).data()!['status'],
      'collected');
  await expectStateError(
      service.call('collectReservation', {'code': code}), 'already collected');
}

Future<void> limit() async {
  await signIn('vendor@example.test');
  final listingId = await publish(20);
  await signIn('student@example.test');
  await reserve(listingId, 3);
  await reserve(listingId, 2);
  await expectStateError(reserve(listingId, 1), 'at most $maxPerCustomer');
}

Future<void> tooEarly() async {
  await signIn('vendor@example.test');
  final listingId = await publish(5, startsIn: 60);
  await signIn('student@example.test');
  final code = await reserve(listingId, 1);
  await signIn('vendor@example.test');
  await expectStateError(
      service.call('collectReservation', {'code': code}), 'not opened yet');
}

Future<void> editAndCancel() async {
  await signIn('vendor@example.test');
  final listingId = await publish(20);
  await signIn('student@example.test');
  final code = await reserve(listingId, 2);
  await signIn('vendor@example.test');
  await service.call('editListing',
      {'listingId': listingId, 'title': 'Updated lunch', 'priceCents': 700});
  final db = FirebaseFirestore.instance;
  expectEqual((await db.doc('listings/$listingId').get()).data()!['title'],
      'Updated lunch');
  expectEqual(
      (await db.doc('reservations/$code').get()).data()!['unitPriceCents'],
      800);
  // Vendor must be able to read and release the student's claim.
  await service
      .call('setListingActive', {'listingId': listingId, 'active': false});
  await service.call('cancelReservation', {'reservationId': code});
  expectEqual((await db.doc('listings/$listingId').get()).data()!['stock'], 20);
  await service.call('cancelReservation', {'reservationId': code});
  expectEqual((await db.doc('listings/$listingId').get()).data()!['stock'], 20);
  await expectStateError(
      service.call('collectReservation', {'code': code}), 'cancelled');
  await signIn('student@example.test');
  final uid = FirebaseAuth.instance.currentUser!.uid;
  expectEqual(
      (await db.doc('listings/$listingId/claims/$uid').get())
          .data()!['quantity'],
      0);
}

Future<void> customerCancelPaused() async {
  await signIn('vendor@example.test');
  final listingId = await publish(20);
  await signIn('student@example.test');
  final code = await reserve(listingId, 5);
  await signIn('vendor@example.test');
  await service
      .call('setListingActive', {'listingId': listingId, 'active': false});
  await signIn('student@example.test');
  await service.call('cancelReservation', {'reservationId': code});
  await signIn('vendor@example.test');
  expectEqual(
      (await FirebaseFirestore.instance.doc('listings/$listingId').get())
          .data()!['stock'],
      20);
  await service
      .call('setListingActive', {'listingId': listingId, 'active': true});
  await signIn('student@example.test');
  await reserve(listingId, 5);
}

Future<void> vendorInventory() async {
  await signIn('vendor@example.test');
  final listingId = await publish(5, startsIn: 0);
  await service
      .call('adjustListingStock', {'listingId': listingId, 'delta': 2});
  final ref = FirebaseFirestore.instance.doc('listings/$listingId');
  expectEqual((await ref.get()).data()!['stock'], 7);
  await signIn('student@example.test');
  await reserve(listingId, 2);
  await expectStateError(
      service.call('adjustListingStock', {'listingId': listingId, 'delta': 1}),
      'approved listing owner');
  await signIn('vendor@example.test');
  await service
      .call('adjustListingStock', {'listingId': listingId, 'delta': -1});
  expectEqual((await ref.get()).data()!['stock'], 4);
  await service
      .call('setListingActive', {'listingId': listingId, 'active': false});
  await service
      .call('adjustListingStock', {'listingId': listingId, 'delta': -4});
  await expectStateError(
      service
          .call('setListingActive', {'listingId': listingId, 'active': true}),
      'Add available stock');
  await service
      .call('adjustListingStock', {'listingId': listingId, 'delta': 1});
  await service
      .call('setListingActive', {'listingId': listingId, 'active': true});
  expectEqual((await ref.get()).data()!['stock'], 1);
  expectEqual((await ref.get()).data()!['active'], true);
}

Future<void> adminAccounts() async {
  await signIn('student@example.test');
  await expectStateError(
      service.createAdministrator(
          name: 'Blocked',
          email: 'blocked@example.test',
          temporaryPassword: 'EmulatorOnly!123',
          currentPassword: 'emulator-only'),
      'Only administrators');
  await signIn('admin@example.test');
  final ownerUid = service.auth.currentUser!.uid;
  final created = await service.createAdministrator(
      name: 'New Admin',
      email: 'new-admin@example.test',
      temporaryPassword: 'EmulatorOnly!123',
      currentPassword: 'emulator-only');
  expectEqual(service.auth.currentUser!.uid, ownerUid);
  final data = (await service.db.doc('users/${created.uid}').get()).data()!;
  expectEqual(data['role'], 'admin');
  expectEqual(data['createdBy'], ownerUid);
  expectEqual(data.containsKey('password'), false);
  expectEqual(data.containsKey('temporaryPassword'), false);
  expectEqual(data.keys.length, 6);
  await expectStateError(
      service.createAdministrator(
          name: 'Duplicate',
          email: 'new-admin@example.test',
          temporaryPassword: 'EmulatorOnly!456',
          currentPassword: 'emulator-only'),
      'already has an account');
  expectEqual(service.auth.currentUser!.uid, ownerUid);
  await service.auth.signOut();
  await service.signInAdministrator(
      'new-admin@example.test', 'EmulatorOnly!123');
  final vendors = await service.db
      .collection('users')
      .where('role', isEqualTo: 'vendor')
      .get();
  expectEqual(
      vendors.docs.any((doc) => doc.data()['name'] == 'Subang Cafe'), true);
  await expectStateError(
      service.signInAdministrator('student@example.test', 'emulator-only'),
      'administrator access');
  expectEqual(service.auth.currentUser, null);
}

Future<void> vendorBusinessJourney() async {
  await service.auth.signOut();
  final user = (await service.auth.createUserWithEmailAndPassword(
          email: 'shop-owner@example.test', password: 'emulator-only'))
      .user!;
  final uid = user.uid;
  await service.createAccountProfile('Shop Owner', 'vendor');
  final business = service.db.doc('vendorBusinesses/$uid');
  expectEqual((await business.get()).data()!['configured'], false);
  await service.saveVendorBusiness(
      businessName: 'SS15 Rescue Bakery',
      address: '12 Jalan SS15, Subang Jaya',
      latitude: 3.075,
      longitude: 101.59);
  await expectStateError(publish(5), 'needs admin approval');
  await signIn('admin@example.test');
  await service.setVendorApproval(uid, approved: true);
  await signIn('shop-owner@example.test');
  final listingId = await publish(5, startsIn: 0);
  final listing = service.db.doc('listings/$listingId');
  expectEqual(
      (await listing.get()).data()!['vendorName'], 'SS15 Rescue Bakery');
  await signIn('student@example.test');
  Future<bool> shopVisible() async => (await service.db
          .collection('vendorBusinesses')
          .where('approved', isEqualTo: true)
          .get())
      .docs
      .any((doc) => doc.id == uid);
  expectEqual(await shopVisible(), true);
  final orderId = await reserve(listingId, 1);
  final order = service.db.doc('reservations/$orderId');
  expectEqual((await order.get()).data()!['latitude'], 3.075);
  await signIn('shop-owner@example.test');
  await service.saveVendorBusiness(
      businessName: 'SS15 Rescue Bakery',
      address: '24 Jalan SS15, Subang Jaya',
      latitude: 3.076,
      longitude: 101.591);
  await service.call(
      'editListing', {'listingId': listingId, 'title': 'Bakery rescue bag'});
  expectEqual((await listing.get()).data()!['latitude'], 3.076);
  expectEqual((await order.get()).data()!['latitude'], 3.075);
  await signIn('admin@example.test');
  await service.setVendorApproval(uid,
      approved: false, reason: 'Test review required');
  await signIn('student@example.test');
  expectEqual(await shopVisible(), false);
  await expectStateError(reserve(listingId, 1), 'Access denied');
  await service.call('cancelReservation', {'reservationId': orderId});
  expectEqual((await order.get()).data()!['status'], 'cancelled');
  await signIn('shop-owner@example.test');
  await expectStateError(publish(5), 'needs admin approval');
  await service.saveVendorBusiness(
      businessName: 'SS15 Rescue Bakery',
      address: '24 Jalan SS15, Subang Jaya',
      latitude: 3.076,
      longitude: 101.591);
  expectEqual((await business.get()).data()!['approved'], false);
  await signIn('admin@example.test');
  await service.setVendorApproval(uid, approved: true);
  await signIn('student@example.test');
  expectEqual(await shopVisible(), true);
  final newOrder = await reserve(listingId, 1);
  expectEqual(
      (await service.db.doc('reservations/$newOrder').get())
          .data()!['latitude'],
      3.076);
}

Future<void> listingEditorJourney() async {
  await signIn('vendor@example.test');
  final db = FirebaseFirestore.instance;
  final uid = service.auth.currentUser!.uid;
  final photoId = service.requestId(), draftId = service.requestId();
  final photo = img.encodeJpg(img.Image(width: 24, height: 24));
  await service.uploadListingPhoto(photoId, photo);
  await service.uploadListingPhoto(photoId, photo); // immutable upload retry
  final model = ListingEditorModel.empty()
    ..title = 'Draft tofu lunch'
    ..description = 'Tofu, vegetables and rice'
    ..priceText = '8.'
    ..imageId = photoId
    ..allergens = 'Soy'
    ..dietaryTags = ['Vegan']
    ..halalStatus = 'not_declared';
  await service.saveListingDraft(draftId, model.toDraft());
  final draftRef = db.doc('listingDrafts/$uid/items/$draftId');
  final restored = ListingEditorModel.fromDraft(Map<String, dynamic>.from(
      (await draftRef.get()).data()!['formData'] as Map));
  expectEqual(restored.priceText, '8.');
  expectEqual(restored.description, model.description);
  try {
    await service.call('publishListing', {
      'requestId': draftId,
      'draftId': draftId,
      'title': 'Invalid food',
      'priceCents': -1,
      'imageId': photoId
    });
    throw StateError('Invalid publication unexpectedly succeeded');
  } on FirebaseException catch (_) {}
  expectEqual((await draftRef.get()).exists, true);
  expectEqual(
      (await db.doc('listingPhotos/$photoId').get()).data()!['published'],
      false);
  restored.priceText = '8.90';
  restored.originalPriceText = '12.90';
  restored.quantityText = '4';
  final payload = {
    ...restored.toListingData(),
    'requestId': draftId,
    'draftId': draftId
  };
  final published = await service.call('publishListing', payload);
  final listingId = published['id'] as String;
  expectEqual(listingId, draftId);
  expectEqual((await draftRef.get()).exists, false);
  final retry = await service.call('publishListing', payload);
  expectEqual(retry['id'], listingId);
  expectEqual(retry['alreadyPublished'], true);
  expectEqual((await service.loadListingPhoto(photoId)).length, photo.length);
  await signIn('student@example.test');
  expectEqual((await service.loadListingPhoto(photoId)).length, photo.length);
  try {
    await draftRef.get();
    throw StateError('Customer read a private draft');
  } on FirebaseException catch (e) {
    expectEqual(e.code, 'permission-denied');
  }
  final reservation = await reserve(listingId, 2);
  await signIn('vendor@example.test');
  try {
    await service.call('editListing',
        {'listingId': listingId, 'stock': 6, 'expectedStock': 4});
    throw StateError('Stale stock edit unexpectedly succeeded');
  } on ListingStockChanged catch (e) {
    expectEqual(e.currentStock, 2);
  }
  final current = (await db.doc('listings/$listingId').get()).data()!;
  final edited = ListingEditorModel.fromListing(current)
    ..title = 'Fresh updated tofu';
  final editDraftId = service.requestId();
  await service.saveListingDraft(editDraftId, edited.toDraft(),
      sourceListingId: listingId);
  await service.call('editListing', {
    'listingId': listingId,
    'draftId': editDraftId,
    ...edited.toListingData(editing: true, initialStock: 2, expectedStock: 2)
  });
  expectEqual(
      (await db.doc('listingDrafts/$uid/items/$editDraftId').get()).exists,
      false);
  final copied = ListingEditorModel.fromListing(current, duplicate: true);
  expectEqual(copied.pickupStart, null);
  expectEqual(copied.pickupEnd, null);
  expectEqual(copied.priceText, '');
  expectEqual(copied.quantityText, '');
  copied.priceText = '7.90';
  copied.originalPriceText = '12.90';
  copied.quantityText = '1';
  copied.startsNow = true;
  copied.pickupEnd =
      DateTime.now().add(const Duration(hours: 3)).millisecondsSinceEpoch;
  final copyId = (await service.call('publishListing', {
    ...copied.toListingData(),
    'requestId': service.requestId()
  }))['id'] as String;
  await signIn('student@example.test');
  final order = (await db.doc('reservations/$reservation').get()).data()!;
  expectEqual(order['title'], 'Draft tofu lunch');
  expectEqual(order['unitPriceCents'], 890);
  final concurrent = await Future.wait([
    for (var i = 0; i < 2; i++)
      reserve(copyId, 1).then((_) => true).catchError((_) => false)
  ]);
  expectEqual(concurrent.where((value) => value).length, 1);
  expectEqual((await db.doc('listings/$copyId').get()).data()!['stock'], 0);
}

String removalPhase = '';
Future<void> removalJourney() async {
  try {
    await _removalJourney();
  } catch (error) {
    throw StateError('$removalPhase: $error');
  }
}

Future<void> _removalJourney() async {
  removalPhase = 'Publish and reserve';
  await signIn('vendor@example.test');
  final db = FirebaseFirestore.instance;
  final listingId = await publish(5, startsIn: 0);
  await signIn('student@example.test');
  final first = await reserve(listingId, 1),
      second = await reserve(listingId, 1),
      third = await reserve(listingId, 1);
  final snapshots = {
    for (final code in [first, second, third])
      code: (await db.doc('reservations/$code').get()).data()!
  };
  await signIn('vendor@example.test');
  removalPhase = 'Remove owned listing';
  await service.call('removeListing', {'listingId': listingId});
  final ref = db.doc('listings/$listingId');
  final removed = (await ref.get()).data()!;
  expectEqual(removed['active'], false);
  expectEqual(removed['stock'], 2);
  if (removed['removedAt'] is! Timestamp) {
    throw StateError('Removal timestamp missing.');
  }
  await service.call('removeListing', {'listingId': listingId});
  expectEqual((await ref.get()).data()!['removedAt'], removed['removedAt']);
  removalPhase = 'Check public catalogue';
  final public =
      await db.collection('listings').where('active', isEqualTo: true).get();
  expectEqual(public.docs.any((doc) => doc.id == listingId), false);
  removalPhase = 'Reject reopen and edits';
  for (final (action, payload) in [
    ('setListingActive', {'active': true}),
    ('editListing', {'title': 'Restore old food'}),
    ('adjustListingStock', {'delta': 1})
  ]) {
    await expectStateError(
        service.call(action, {'listingId': listingId, ...payload}), 'removed');
  }
  for (final code in [first, second, third]) {
    final order = (await db.doc('reservations/$code').get()).data()!;
    for (final field in [
      'customerId',
      'vendorId',
      'title',
      'unitPriceCents',
      'pickupStart',
      'pickupEnd',
      'address',
      'status'
    ]) {
      expectEqual(order[field], snapshots[code]![field]);
    }
  }
  await service.call('markOrderReady', {'reservationId': second});
  removalPhase = 'Vendor cancellation after removal';
  await service.call('cancelReservation', {'reservationId': first});
  await signIn('student@example.test');
  removalPhase = 'Block new reservation';
  await expectStateError(reserve(listingId, 1), 'no longer available');
  removalPhase = 'Customer cancellation after removal';
  await service.call('cancelReservation', {'reservationId': second});
  await signIn('vendor@example.test');
  removalPhase = 'Collect existing pickup';
  await service.call('markOrderReady', {'reservationId': third});
  await service.call('collectReservation', {'code': third});
  expectEqual((await db.doc('reservations/$first').get()).data()!['status'],
      'cancelled');
  expectEqual((await db.doc('reservations/$second').get()).data()!['status'],
      'cancelled');
  expectEqual((await db.doc('reservations/$third').get()).data()!['status'],
      'collected');
  final after = (await ref.get()).data()!;
  expectEqual(after['stock'], 4);
  expectEqual(after['active'], false);
  expectEqual(after['removedAt'], removed['removedAt']);
  // Idempotent publish retries must never report success on an archived ID.
  removalPhase = 'Reject a publish retry after removal';
  final stable = service.requestId();
  await service.call('publishListing', {
    'title': 'Accidental bag',
    'description': 'Rice and tofu',
    'dietary': 'Contains soy',
    'category': 'Meals',
    'priceCents': 800,
    'originalPriceCents': 1500,
    'stock': 2,
    'pickupStart': DateTime.now().millisecondsSinceEpoch,
    'pickupEnd':
        DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
    'requestId': stable
  });
  await service.call('removeListing', {'listingId': stable});
  await expectStateError(
      service.call('publishListing', {'requestId': stable}), 'removed');
}

// Owner access is restricted to this explicit localhost demo emulator fixture.
Future<void> seedPickupFixture(String path, Map<String, dynamic> data) async {
  if (Firebase.app().options.projectId != 'demo-foodienoms') {
    throw StateError('Pickup fixtures are for the demo emulator only.');
  }
  Map<String, dynamic> field(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is int) return {'integerValue': '$value'};
    if (value is double) return {'doubleValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is Timestamp) {
      return {'timestampValue': value.toDate().toUtc().toIso8601String()};
    }
    throw StateError('Unsupported test fixture field.');
  }

  final response = await http.patch(
      Uri.parse(
          'http://127.0.0.1:8080/v1/projects/demo-foodienoms/databases/(default)/documents/$path'),
      headers: {
        'authorization': 'Bearer owner',
        'content-type': 'application/json'
      },
      body: jsonEncode({
        'fields': {
          for (final entry in data.entries) entry.key: field(entry.value)
        }
      }));
  if (response.statusCode != 200) {
    throw StateError(
        'Unable to seed isolated pickup fixture: ${response.statusCode}');
  }
}

Future<void> pickupStatusJourney() async {
  await signIn('vendor@example.test');
  final db = FirebaseFirestore.instance;
  final vendorUid = service.auth.currentUser!.uid;
  final listingId = await publish(10, startsIn: 0);
  await signIn('student@example.test');
  final fixed = FoodieService(pickupCodeGenerator: () => '0007');
  final key = service.requestId();
  final first = await fixed.call('reserveListing', {
    'listingId': listingId,
    'quantity': 1,
    'requestId': key,
    'expectedPriceCents': 800
  });
  final firstId = first['id'] as String;
  expectEqual(first['pickupCode'], '0007');
  await expectStateError(
      fixed.call('reserveListing', {
        'listingId': listingId,
        'quantity': 1,
        'requestId': service.requestId()
      }),
      'allocate');
  var attempts = 0;
  final skipCollision = FoodieService(
      pickupCodeGenerator: () => attempts++ == 0 ? '0007' : '0008');
  final second = await skipCollision.call('reserveListing', {
    'listingId': listingId,
    'quantity': 1,
    'requestId': service.requestId()
  });
  expectEqual(second['pickupCode'], '0008');
  await expectStateError(
      service.call('markOrderReady', {'reservationId': firstId}),
      'Only the approved vendor');
  await signIn('vendor@example.test');
  expectEqual((await db.doc('listings/$listingId').get()).data()!['stock'], 8);
  await expectStateError(
      service.call('markOrderNoShow', {'reservationId': firstId}),
      'grace period');
  await service.call('markOrderReady', {'reservationId': firstId});
  final ready = (await db.doc('reservations/$firstId').get()).data()!;
  expectEqual(ready['status'], 'ready');
  expectEqual(ready['pickupCode'], '0007');
  await service.call('markOrderReady', {'reservationId': firstId});
  expectEqual((await db.doc('reservations/$firstId').get()).data()!['readyAt'],
      ready['readyAt']);
  await service.call('collectPickupCode', {'pickupCode': '0007'});
  expectEqual((await db.doc('reservations/$firstId').get()).data()!['status'],
      'collected');
  await expectStateError(service.call('collectReservation', {'code': '0007'}),
      'already collected');
  await service.call('markOrderReady', {'reservationId': second['id']});
  await signIn('student@example.test');
  final retried = await fixed.call('reserveListing',
      {'listingId': listingId, 'quantity': 1, 'requestId': key});
  expectEqual(retried['id'], firstId);
  expectEqual(retried['pickupCode'], '0007');
  await service.call('cancelReservation', {'reservationId': second['id']});
  await signIn('vendor@example.test');
  expectEqual((await db.doc('listings/$listingId').get()).data()!['stock'], 9);
  // Seed an actual expired order snapshot; no production data or clocks are changed.
  final expiredId = 'FN-${service.requestId().substring(0, 20).toUpperCase()}';
  final expired = {
    ...ready,
    'code': expiredId,
    'status': 'ready',
    'pickupCode': '0042',
    'pickupStart': DateTime.now()
        .subtract(const Duration(hours: 2))
        .millisecondsSinceEpoch,
    'pickupEnd': DateTime.now()
        .subtract(const Duration(minutes: 16))
        .millisecondsSinceEpoch
  };
  await seedPickupFixture('reservations/$expiredId', expired);
  await seedPickupFixture('vendors/$vendorUid/pickupCodes/0042', {
    'reservationId': expiredId,
    'until': (expired['pickupEnd'] as int) + pickupGraceMs
  });
  await service.call('markOrderNoShow', {'reservationId': expiredId});
  final missed = (await db.doc('reservations/$expiredId').get()).data()!;
  expectEqual(missed['status'], 'noshow');
  await service.call('markOrderNoShow', {'reservationId': expiredId});
  expectEqual(
      (await db.doc('reservations/$expiredId').get()).data()!['noshowAt'],
      missed['noshowAt']);
  expectEqual((await db.doc('listings/$listingId').get()).data()!['stock'], 9);
  await expectStateError(
      service.call('collectReservation', {'code': expiredId}), 'not collected');
  await expectStateError(
      service.call('cancelReservation', {'reservationId': expiredId}),
      'Only reserved or ready');
  await signIn('student@example.test');
  final recycled = await FoodieService(pickupCodeGenerator: () => '0042').call(
      'reserveListing', {
    'listingId': listingId,
    'quantity': 1,
    'requestId': service.requestId()
  });
  expectEqual(recycled['pickupCode'], '0042');
  await signIn('vendor@example.test');
  // Existing QR verification still uses the immutable FN reference.
  await service.call('collectReservation', {'code': recycled['id']});
  expectEqual(
      (await db.doc('reservations/${recycled['id']}').get()).data()!['status'],
      'collected');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: emulatorOnly);
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  service = FoodieService(authEmulatorHost: '127.0.0.1');
  await signIn('vendor@example.test');
  await service.saveVendorBusiness(
      businessName: 'Subang Cafe',
      address: '1 Test Street, Subang Jaya',
      latitude: 3.0567,
      longitude: 101.5851);
  var failed = 0;
  for (final (name, check) in [
    (
      'photo upload, private draft recovery, idempotent publish, safe edit and List Again',
      listingEditorJourney
    ),
    (
      'remove listing, block new sales, preserve snapshots and complete/cancel existing pickups',
      removalJourney
    ),
    (
      'short pickup codes, collision retry, Ready, Not collected and legacy QR',
      pickupStatusJourney
    ),
    ('publish, reserve and collect', journey),
    ('per-student limit across orders', limit),
    ('collecting too early', tooEarly),
    ('vendor inventory and pause/reopen after reservations', vendorInventory),
    ('edit snapshot and vendor cancellation', editAndCancel),
    (
      'customer cancellation on paused food restores allowance',
      customerCancelPaused
    ),
    (
      'admin creation preserves primary session and denies unauthorized users',
      adminAccounts
    ),
    (
      'vendor setup, map visibility, revoke/reapprove and pickup location snapshots',
      vendorBusinessJourney
    ),
  ]) {
    try {
      await check();
      print('CLIENT_CHECK pass: $name');
    } catch (e) {
      failed++;
      print('CLIENT_CHECK FAIL: $name: $e');
    }
  }
  print('CLIENT_CHECK_DONE failed=$failed');
}
