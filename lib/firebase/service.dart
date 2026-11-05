import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Mirrors pickupGraceMs() in firestore.rules.
const pickupGraceMs = 15 * 60 * 1000;

/// Mirrors maxPerCustomer() in firestore.rules.
const maxPerCustomer = 5;

/// Mirrors slotMs() in firestore.rules: pickup slots sit on the quarter hour.
const pickupSlotMs = 15 * 60 * 1000;

/// Simulated payment methods in Han's payment screen. No money moves.
const simulatedPaymentMethods = ['ewallet', 'banking', 'card'];

/// Items per order. Each item is a separate write, so keep orders small.
const maxOrderItems = 3;

/// The quarter-hour slot containing [time].
int slotContaining(int time) => time - time % pickupSlotMs;

/// The pickup window of an order: its slot, or the listing window for orders
/// placed before slots existed.
int orderSlotStart(Map<String, dynamic> order) =>
    (order['slotStart'] ?? order['pickupStart']) as int;
int orderSlotEnd(Map<String, dynamic> order) =>
    (order['slotEnd'] ?? order['pickupEnd']) as int;

bool isOpenOrder(Map<String, dynamic> order) =>
    order['status'] == 'reserved' || order['status'] == 'ready';

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

  /// Web transactions rethrow errors as an untyped JS object, which would hide
  /// the message from [firebaseMessage], so the original error is kept here.
  Future<T> _transact<T>(Future<T> Function(Transaction tx) handler) async {
    StateError? failure;
    try {
      return await db.runTransaction((tx) async {
        failure = null;
        try {
          return await handler(tx);
        } on StateError catch (error) {
          failure = error;
          rethrow;
        }
      });
    } catch (_) {
      if (failure != null) throw failure!;
      rethrow;
    }
  }

  Future<void> approveVendor(String vendorId) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    final actor = db.collection('users').doc(user.uid);
    final target = db.collection('users').doc(vendorId);
    await _transact((transaction) async {
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
      'editListing' => _edit(data),
      'cancelReservation' => _cancel(data),
      'reserveOrder' => _reserveOrder(data),
      'collectPickupCode' => _collectPickupCode(data),
      'markOrderReady' => _markOrder(data, 'ready'),
      'markOrderNoShow' => _markOrder(data, 'noshow'),
      'cancelOrder' => _cancelOrder(data),
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
    await _transact((tx) async {
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

  Future<Map<String, dynamic>> _edit(Map<String, dynamic> data) async {
    final uid = _uid;
    final ref = db.collection('listings').doc(data['listingId'] as String);
    final details = Map<String, dynamic>.from(data)..remove('listingId');
    await _transact((tx) async {
      final listing = (await tx.get(ref)).data();
      final profile = (await tx.get(db.collection('users').doc(uid))).data();
      if (listing?['vendorId'] != uid ||
          profile?['role'] != 'vendor' ||
          profile?['approved'] != true) {
        throw StateError('Only the approved listing owner can edit this food.');
      }
      tx.update(ref, details);
    });
    return {'id': ref.id};
  }

  Future<Map<String, dynamic>> _cancel(Map<String, dynamic> data) async {
    final uid = _uid;
    final ref =
        db.collection('reservations').doc(data['reservationId'] as String);
    await _transact((tx) async {
      final order = (await tx.get(ref)).data();
      if (order == null ||
          (order['customerId'] != uid && order['vendorId'] != uid)) {
        throw StateError('Reservation not found for your account.');
      }
      if (order['status'] == 'cancelled') return;
      if (!isOpenOrder(order)) {
        throw StateError('Collected orders cannot be cancelled.');
      }
      if (order['vendorId'] != uid &&
          DateTime.now().millisecondsSinceEpoch >= orderSlotEnd(order)) {
        throw StateError(
            'The cancellation window has ended. Contact the vendor.');
      }
      final listing =
          db.collection('listings').doc(order['listingId'] as String);
      final claim =
          listing.collection('claims').doc(order['customerId'] as String);
      final held = await tx.get(claim);
      final quantity = order['quantity'] as int;
      tx.update(ref, {
        'status': 'cancelled',
        'cancelledBy': uid,
        'cancelledAt': FieldValue.serverTimestamp()
      });
      // No listing read: customers can cancel even after the vendor pauses it.
      tx.update(listing,
          {'stock': FieldValue.increment(quantity), 'lastReleaseId': ref.id});
      if (held.exists) {
        tx.update(claim, {
          'quantity': FieldValue.increment(-quantity),
          'lastReleaseId': ref.id
        });
      }
    });
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _setActive(Map<String, dynamic> data) async {
    await db
        .collection('listings')
        .doc(data['listingId'] as String)
        .update({'active': data['active']});
    return {'ok': true};
  }

  /// Single-item reservation, kept for the current screens.
  Future<Map<String, dynamic>> _reserve(Map<String, dynamic> data) async {
    final result = await _reserveOrder({
      'requestId': data['requestId'],
      'items': [
        {'listingId': data['listingId'], 'quantity': data['quantity']}
      ],
    });
    final id = result['orderId'] as String;
    return {...result, 'id': id, 'code': id};
  }

  /// Reserves up to [maxOrderItems] items from one shop for one pickup slot,
  /// sharing a 4-digit pickup code. Without `slotStart`, the earliest slot
  /// that is still open and overlaps every item's window is used.
  Future<Map<String, dynamic>> _reserveOrder(Map<String, dynamic> data) async {
    final uid = _uid;
    final key = data['requestId'] as String;
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key)) {
      throw StateError(
          'Invalid reservation request. Reopen this listing and try again.');
    }
    final items = (data['items'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final paymentMethod = data['paymentMethod'] as String?;
    if (paymentMethod != null &&
        !simulatedPaymentMethods.contains(paymentMethod)) {
      throw StateError('Choose a payment method.');
    }
    final listingIds = items.map((item) => item['listingId']).toSet();
    if (items.isEmpty ||
        items.length > maxOrderItems ||
        listingIds.length != items.length) {
      throw StateError(
          'An order can have 1 to $maxOrderItems different items.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final deals = <Map<String, dynamic>>[];
    for (final item in items) {
      Map<String, dynamic>? deal;
      try {
        deal = (await db
                .collection('listings')
                .doc(item['listingId'] as String)
                .get())
            .data();
      } on FirebaseException {
        // Paused listings are hidden from students.
        deal = null;
      }
      if (deal == null) {
        throw StateError('This listing is no longer available.');
      }
      deals.add(deal);
    }
    if (deals.any((deal) => deal['vendorId'] != deals.first['vendorId'])) {
      throw StateError('All items in one order must come from the same shop.');
    }
    var slotStart = data['slotStart'] as int?;
    slotStart ??= deals
        .map((deal) => slotContaining(now > (deal['pickupStart'] as int)
            ? now
            : deal['pickupStart'] as int))
        .reduce((a, b) => a > b ? a : b);
    final slotEnd = slotStart + pickupSlotMs;
    if (slotStart % pickupSlotMs != 0) {
      throw StateError('Choose one of the listed pickup times.');
    }
    if (slotEnd <= now) {
      throw StateError('This pickup time has passed.');
    }
    if (deals.any((deal) =>
        slotEnd <= (deal['pickupStart'] as int) ||
        slotStart! >= (deal['pickupEnd'] as int))) {
      throw StateError('Choose a pickup time when every item is available.');
    }
    // One id per item, stable across retries of the same request.
    final ids = [
      for (var i = 0; i < items.length; i++)
        'FN-${key.substring(0, 18).toUpperCase()}${i.toRadixString(16).padLeft(2, '0').toUpperCase()}'
    ];
    final orderId = ids.first;
    String? pickupCode;
    final placed = <String>[];
    // Each item is its own write: rules may read at most 20 documents per write.
    for (var i = 0; i < items.length; i++) {
      try {
        pickupCode = await _reserveItem(
            uid: uid,
            id: ids[i],
            orderId: orderId,
            listingId: items[i]['listingId'] as String,
            quantity: items[i]['quantity'] as int,
            slotStart: slotStart,
            pickupCode: pickupCode,
            paymentMethod: paymentMethod);
        placed.add(ids[i]);
      } catch (_) {
        // Never leave part of an order reserved.
        for (final id in placed) {
          try {
            await _cancel({'reservationId': id});
          } catch (_) {}
        }
        rethrow;
      }
    }
    return {
      'orderId': orderId,
      'pickupCode': pickupCode,
      'ids': ids,
      'slotStart': slotStart,
      'slotEnd': slotEnd,
    };
  }

  /// Reserves one item and returns the order's pickup code. The first item,
  /// with no [pickupCode] yet, also claims a free code for the shop.
  Future<String> _reserveItem(
      {required String uid,
      required String id,
      required String orderId,
      required String listingId,
      required int quantity,
      required int slotStart,
      String? pickupCode,
      String? paymentMethod}) {
    final order = db.collection('reservations').doc(id);
    final listing = db.collection('listings').doc(listingId);
    final slotEnd = slotStart + pickupSlotMs;
    return _transact((tx) async {
      final previous = await tx.get(order);
      if (previous.exists) {
        final old = previous.data()!;
        if (old['customerId'] != uid ||
            old['listingId'] != listingId ||
            old['quantity'] != quantity) {
          throw StateError(
              'This request is already linked to a different reservation.');
        }
        return old['pickupCode'] as String;
      }
      final deal = (await tx.get(listing)).data();
      if (deal == null ||
          deal['active'] != true ||
          (deal['pickupEnd'] as int) <= DateTime.now().millisecondsSinceEpoch) {
        throw StateError('This listing is no longer available.');
      }
      if (quantity < 1 || (deal['stock'] as int) < quantity) {
        throw StateError('Not enough stock remains for this quantity.');
      }
      final claim = listing.collection('claims').doc(uid);
      final held = ((await tx.get(claim)).data()?['quantity'] as int?) ?? 0;
      if (held + quantity > maxPerCustomer) {
        throw StateError(
            'You can reserve at most $maxPerCustomer of this item.');
      }
      final codes = db
          .collection('vendors')
          .doc(deal['vendorId'] as String)
          .collection('pickupCodes');
      var code = pickupCode;
      if (code == null) {
        final random = Random.secure();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (var attempt = 0; attempt < 12 && code == null; attempt++) {
          final candidate = random.nextInt(10000).toString().padLeft(4, '0');
          final lock = (await tx.get(codes.doc(candidate))).data();
          if (lock == null || (lock['until'] as int) < now) code = candidate;
        }
        if (code == null) {
          throw StateError('This shop is very busy. Please try again.');
        }
        tx.set(codes.doc(code), {
          'orderId': orderId,
          'reservationId': id,
          'until': slotEnd + pickupGraceMs,
        });
      }
      tx.set(order, {
        'customerId': uid,
        'vendorId': deal['vendorId'],
        'listingId': listingId,
        'title': deal['title'],
        'vendorName': deal['vendorName'],
        'address': deal['address'],
        'pickupStart': deal['pickupStart'],
        'pickupEnd': deal['pickupEnd'],
        'quantity': quantity,
        'unitPriceCents': deal['priceCents'],
        'totalCents': (deal['priceCents'] as int) * quantity,
        'status': 'reserved',
        'code': id,
        'paymentStatus': paymentMethod == null ? 'unpaid' : 'test_paid',
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'orderId': orderId,
        'slotStart': slotStart,
        'slotEnd': slotEnd,
        'pickupCode': code,
      });
      tx.update(listing, {
        'stock': (deal['stock'] as int) - quantity,
        'lastReservationId': id
      });
      tx.set(claim, {'quantity': held + quantity, 'lastReservationId': id},
          SetOptions(merge: true));
      return code;
    });
  }

  /// The items of one order, as the customer or the vendor sees them.
  Future<List<DocumentReference<Map<String, dynamic>>>> _orderItems(
      String role, String uid, String orderId) async {
    final items = await db
        .collection('reservations')
        .where(role == 'vendor' ? 'vendorId' : 'customerId', isEqualTo: uid)
        .where('orderId', isEqualTo: orderId)
        .get();
    if (items.docs.isEmpty) {
      throw StateError('This order was not found for your account.');
    }
    return items.docs.map((doc) => doc.reference).toList();
  }

  /// Vendor counter flow: the student reads out the 4-digit code.
  Future<Map<String, dynamic>> _collectPickupCode(
      Map<String, dynamic> data) async {
    final uid = _uid;
    final code = (data['pickupCode'] as String).trim();
    if (!RegExp(r'^[0-9]{4}$').hasMatch(code)) {
      throw StateError('Enter the 4-digit pickup code.');
    }
    final lock = (await db
            .collection('vendors')
            .doc(uid)
            .collection('pickupCodes')
            .doc(code)
            .get())
        .data();
    if (lock == null) {
      throw StateError('No order for your shop matches this code.');
    }
    if ((lock['until'] as int) < DateTime.now().millisecondsSinceEpoch) {
      throw StateError('The pickup time for this code has ended.');
    }
    final orderId = lock['orderId'] as String;
    final refs = await _orderItems('vendor', uid, orderId);
    await _transact((tx) async {
      final orders = [for (final ref in refs) (await tx.get(ref)).data()!];
      final open = [
        for (var i = 0; i < refs.length; i++)
          if (isOpenOrder(orders[i])) i
      ];
      if (open.isEmpty) {
        throw StateError(orders.any((o) => o['status'] == 'collected')
            ? 'This pickup was already collected.'
            : 'This order is no longer open.');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < orderSlotStart(orders[open.first]) - pickupGraceMs) {
        throw StateError('This pickup window has not opened yet.');
      }
      for (final i in open) {
        tx.update(refs[i], {
          'status': 'collected',
          'collectedAt': FieldValue.serverTimestamp()
        });
      }
    });
    return {'orderId': orderId, 'collected': true};
  }

  /// Vendor marks an order ready, or not collected once its slot is over.
  Future<Map<String, dynamic>> _markOrder(
      Map<String, dynamic> data, String status) async {
    final uid = _uid;
    final refs = await _orderItems('vendor', uid, data['orderId'] as String);
    await _transact((tx) async {
      final orders = [for (final ref in refs) (await tx.get(ref)).data()!];
      final now = DateTime.now().millisecondsSinceEpoch;
      final from = status == 'ready' ? ['reserved'] : ['reserved', 'ready'];
      final targets = [
        for (var i = 0; i < refs.length; i++)
          if (from.contains(orders[i]['status'])) i
      ];
      if (targets.isEmpty) throw StateError('This order is no longer open.');
      final slotEnd = orderSlotEnd(orders[targets.first]);
      if (status == 'noshow' && now <= slotEnd + pickupGraceMs) {
        throw StateError(
            'You can mark this as not collected after its pickup time ends.');
      }
      if (status == 'ready' && now > slotEnd + pickupGraceMs) {
        throw StateError('This pickup time has ended.');
      }
      for (final i in targets) {
        tx.update(refs[i], {
          'status': status,
          status == 'ready' ? 'readyAt' : 'noshowAt':
              FieldValue.serverTimestamp()
        });
      }
    });
    return {'ok': true};
  }

  /// Cancels every open item of an order, returning stock and allowance.
  Future<Map<String, dynamic>> _cancelOrder(Map<String, dynamic> data) async {
    final uid = _uid;
    final role = data['role'] as String? ?? 'customer';
    final refs = await _orderItems(role, uid, data['orderId'] as String);
    for (final ref in refs) {
      await _cancel({'reservationId': ref.id});
    }
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _collect(Map<String, dynamic> data) async {
    final uid = _uid;
    final code = (data['code'] as String).trim().toUpperCase();
    if (!RegExp(r'^FN-[A-F0-9]{20}$').hasMatch(code)) {
      throw StateError('Enter the complete pickup code shown in My Pickups.');
    }
    final ref = db.collection('reservations').doc(code);
    await _transact((tx) async {
      final order = await tx.get(ref);
      final value = order.data();
      if (value == null || value['vendorId'] != uid) {
        throw StateError('No reservation for your store matches this code.');
      }
      if (value['status'] == 'cancelled') {
        throw StateError('This reservation was cancelled.');
      }
      if (!isOpenOrder(value)) {
        throw StateError('This pickup was already collected.');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < orderSlotStart(value) - pickupGraceMs) {
        throw StateError('This pickup window has not opened yet.');
      }
      if (now > orderSlotEnd(value) + pickupGraceMs) {
        throw StateError('This pickup window has ended.');
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

  /// Every item of one order, for the order and pickup screens.
  Stream<QuerySnapshot<Map<String, dynamic>>> orderItems(
          String role, String uid, String orderId) =>
      db
          .collection('reservations')
          .where(role == 'vendor' ? 'vendorId' : 'customerId', isEqualTo: uid)
          .where('orderId', isEqualTo: orderId)
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
