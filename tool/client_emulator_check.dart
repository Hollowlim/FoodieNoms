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

Future<String> statusOf(String id) async =>
    (await FirebaseFirestore.instance.doc('reservations/$id').get())
        .data()!['status'] as String;

Future<int> stockOf(String listingId) async =>
    (await FirebaseFirestore.instance.doc('listings/$listingId').get())
        .data()!['stock'] as int;

Future<void> groupedOrderWithPickupCode() async {
  await signIn('vendor@example.test');
  final a = await publish(5, startsIn: 0);
  final b = await publish(5, startsIn: 0);
  await signIn('student@example.test');
  final order = await service.call('reserveOrder', {
    'requestId': service.requestId(),
    'paymentMethod': 'ewallet',
    'items': [
      {'listingId': a, 'quantity': 2},
      {'listingId': b, 'quantity': 1},
    ],
  });
  final code = order['pickupCode'] as String;
  final ids = (order['ids'] as List).cast<String>();
  if (!RegExp(r'^[0-9]{4}$').hasMatch(code)) throw 'Bad pickup code $code';
  expectEqual(await stockOf(a), 3);
  expectEqual(await stockOf(b), 4);
  final first =
      (await FirebaseFirestore.instance.doc('reservations/${ids[0]}').get())
          .data()!;
  expectEqual(first['paymentStatus'], 'test_paid');
  expectEqual(first['paymentMethod'], 'ewallet');

  await signIn('vendor@example.test');
  await expectStateError(
      service.call('markOrderNoShow', {'orderId': order['orderId']}),
      'after its pickup time ends');
  await service.call('markOrderReady', {'orderId': order['orderId']});
  expectEqual(await statusOf(ids[0]), 'ready');
  expectEqual(await statusOf(ids[1]), 'ready');
  final wrong = ((int.parse(code) + 1) % 10000).toString().padLeft(4, '0');
  await expectStateError(
      service.call('collectPickupCode', {'pickupCode': wrong}),
      'No order for your shop');
  await service.call('collectPickupCode', {'pickupCode': code});
  expectEqual(await statusOf(ids[0]), 'collected');
  expectEqual(await statusOf(ids[1]), 'collected');
  await expectStateError(
      service.call('collectPickupCode', {'pickupCode': code}),
      'already collected');
}

Future<void> failedItemUndoesOrder() async {
  await signIn('vendor@example.test');
  final a = await publish(5, startsIn: 0);
  final b = await publish(1, startsIn: 0);
  await signIn('student@example.test');
  await expectStateError(
      service.call('reserveOrder', {
        'requestId': service.requestId(),
        'items': [
          {'listingId': a, 'quantity': 2},
          {'listingId': b, 'quantity': 2},
        ],
      }),
      'Not enough stock');
  expectEqual(await stockOf(a), 5);
  // The allowance came back with the stock, so the full limit is available.
  await service.call('reserveOrder', {
    'requestId': service.requestId(),
    'items': [
      {'listingId': a, 'quantity': maxPerCustomer},
    ],
  });
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
    (
      'grouped order, ready and 4-digit pickup code',
      groupedOrderWithPickupCode
    ),
    ('a failed item undoes the whole order', failedItemUndoesOrder),
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
