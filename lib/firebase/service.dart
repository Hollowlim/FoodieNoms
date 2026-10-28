import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FoodieService {
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  Future<void> createAccountProfile(String name, String role) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    final cleanName = name.trim();
    if (cleanName.isEmpty ||
        cleanName.length > 100 ||
        !['customer', 'vendor'].contains(role)) {
      throw ArgumentError('Enter a name and choose customer or vendor.');
    }
    final ref = db.collection('users').doc(user.uid);
    await db.runTransaction((transaction) async {
      final current = await transaction.get(ref);
      if (current.exists) return; // A retry must never overwrite a role.
      transaction.set(ref, {
        'name': cleanName,
        'role': role,
        'approved': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> approveVendor(String vendorId) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    final actor = db.collection('users').doc(user.uid);
    final target = db.collection('users').doc(vendorId);
    await db.runTransaction((transaction) async {
      final profile = await transaction.get(actor);
      final vendor = await transaction.get(target);
      if (profile.data()?['role'] != 'admin') {
        throw StateError('Only an admin can approve vendors.');
      }
      if (vendor.data()?['role'] != 'vendor') {
        throw StateError('Vendor application not found.');
      }
      if (vendor.data()?['approved'] == true) return;
      transaction.update(target, {
        'approved': true,
        'approvedBy': user.uid,
        'approvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    return switch (name) {
      'publishListing' => _publish(data),
      'setListingActive' => _setActive(data),
      'reserveListing' => _reserve(data),
      'collectReservation' => _collect(data),
      _ => throw UnsupportedError('Unknown action: $name'),
    };
  }

  String get _uid {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    return user.uid;
  }

  Future<Map<String, dynamic>> _publish(Map<String, dynamic> data) async {
    final uid = _uid;
    final ref = db.collection('listings').doc();
    await db.runTransaction((tx) async {
      final profile = await tx.get(db.collection('users').doc(uid));
      final vendor = profile.data();
      if (vendor?['role'] != 'vendor' || vendor?['approved'] != true) {
        throw StateError(
            'Your vendor account needs admin approval before publishing.');
      }
      tx.set(ref, {
        ...data,
        'vendorId': uid,
        'vendorName': vendor!['name'],
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': ref.id};
  }

  Future<Map<String, dynamic>> _setActive(Map<String, dynamic> data) async {
    await db
        .collection('listings')
        .doc(data['listingId'] as String)
        .update({'active': data['active']});
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _reserve(Map<String, dynamic> data) async {
    final uid = _uid;
    final key = data['requestId'] as String;
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key)) {
      throw StateError(
          'Invalid reservation request. Reopen this listing and try again.');
    }
    final quantity = data['quantity'] as int;
    final code = 'FN-${key.substring(0, 20).toUpperCase()}';
    final order = db.collection('reservations').doc(code);
    final listing = db.collection('listings').doc(data['listingId'] as String);
    return db.runTransaction((tx) async {
      final previous = await tx.get(order);
      if (previous.exists) {
        final old = previous.data()!;
        if (old['customerId'] != uid ||
            old['listingId'] != listing.id ||
            old['quantity'] != quantity) {
          throw StateError(
              'This request is already linked to a different reservation.');
        }
        return {'id': code, 'code': code};
      }
      final snapshot = await tx.get(listing);
      final deal = snapshot.data();
      if (deal == null ||
          deal['active'] != true ||
          (deal['pickupEnd'] as int) <= DateTime.now().millisecondsSinceEpoch) {
        throw StateError('This listing is no longer available.');
      }
      if (quantity < 1 || quantity > 100 || (deal['stock'] as int) < quantity) {
        throw StateError('Not enough stock remains for this quantity.');
      }
      tx.set(order, {
        'customerId': uid,
        'vendorId': deal['vendorId'],
        'listingId': listing.id,
        'title': deal['title'],
        'vendorName': deal['vendorName'],
        'address': deal['address'],
        'pickupStart': deal['pickupStart'],
        'pickupEnd': deal['pickupEnd'],
        'quantity': quantity,
        'unitPriceCents': deal['priceCents'],
        'totalCents': (deal['priceCents'] as int) * quantity,
        'status': 'reserved',
        'code': code,
        'paymentStatus': 'unpaid',
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(listing, {
        'stock': (deal['stock'] as int) - quantity,
        'lastReservationId': code
      });
      return {'id': code, 'code': code};
    });
  }

  Future<Map<String, dynamic>> _collect(Map<String, dynamic> data) async {
    final uid = _uid;
    final code = (data['code'] as String).trim().toUpperCase();
    if (!RegExp(r'^FN-[A-F0-9]{20}$').hasMatch(code)) {
      throw StateError('Enter the complete pickup code shown in My Pickups.');
    }
    final ref = db.collection('reservations').doc(code);
    await db.runTransaction((tx) async {
      final order = await tx.get(ref);
      final value = order.data();
      if (value == null || value['vendorId'] != uid) {
        throw StateError('No reservation for your store matches this code.');
      }
      if (value['status'] != 'reserved') {
        throw StateError('This pickup was already collected.');
      }
      tx.update(ref,
          {'status': 'collected', 'collectedAt': FieldValue.serverTimestamp()});
    });
    return {'ok': true};
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      db.collection('users').doc(uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> listings(
      String role, String uid) {
    final query = db.collection('listings');
    return role == 'vendor'
        ? query.where('vendorId', isEqualTo: uid).snapshots()
        : query.where('active', isEqualTo: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reservations(
          String role, String uid) =>
      db
          .collection('reservations')
          .where(role == 'vendor' ? 'vendorId' : 'customerId', isEqualTo: uid)
          .snapshots();

  String requestId() {
    final random = Random.secure();
    return List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

String firebaseMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' =>
        'Choose a stronger password with at least 8 characters.',
      'email-already-in-use' =>
        'This email already has an account. Try signing in.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Email or password is incorrect.',
      'network-request-failed' => 'Check your connection and try again.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      _ => error.message ?? 'Unable to sign in. Please try again.',
    };
  }
  if (error is StateError) return error.message;
  if (error is FirebaseException) {
    return error.code == 'permission-denied'
        ? 'Access denied. Check your account permissions and deployed Firebase rules.'
        : 'Unable to load data. Check your connection and retry.';
  }
  return 'Unable to complete this action. Please try again.';
}

String money(dynamic cents) =>
    'RM ${((cents as num) / 100).toStringAsFixed(2)}';
String pickupWindow(Map<String, dynamic> data) {
  String format(int milliseconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${d.day}/${d.month}/${d.year} $hour:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  return '${format(data['pickupStart'] as int)} – ${format(data['pickupEnd'] as int)}';
}
