// Runs the real FoodieService against the rules on local emulators and prints
// results to the browser console. Use tool/run_client_emulator_check.sh.
// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: emulatorOnly);
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  service = FoodieService();
  var failed = 0;
  for (final (name, check) in [
    ('publish, reserve and collect', journey),
    ('per-student limit across orders', limit),
    ('collecting too early', tooEarly),
    ('edit snapshot and vendor cancellation', editAndCancel),
    (
      'customer cancellation on paused food restores allowance',
      customerCancelPaused
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
