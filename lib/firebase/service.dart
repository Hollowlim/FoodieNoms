import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'admin_identity.dart';
import 'password_reset.dart';
import 'order_state.dart';

/// Mirrors pickupGraceMs() in firestore.rules.
const pickupGraceMs = 15 * 60 * 1000;

/// Mirrors maxPerCustomer() in firestore.rules.
const maxPerCustomer = 5;
const maxListingPhotoBytes = 160 * 1024;

class _PickupCodeCollision implements Exception {
  const _PickupCodeCollision();
}

class ListingStockChanged extends StateError {
  ListingStockChanged(this.currentStock)
      : super(
            'Available quantity changed while you were editing. Review the latest stock before saving.');
  final int currentStock;
}

int adjustedVendorStock(int current, int delta) {
  final next = current + delta;
  if (delta == 0 ||
      delta < -10000 ||
      delta > 10000 ||
      next < 0 ||
      next > 10000) {
    throw StateError('Available stock must stay between 0 and 10,000.');
  }
  return next;
}

class AdminCreationResult {
  const AdminCreationResult({required this.uid, required this.setupEmailSent});
  final String uid;
  final bool setupEmailSent;
}

class FoodieService {
  FoodieService(
      {this.authEmulatorHost,
      this.authEmulatorPort = 9099,
      this.pickupCodeGenerator});
  final String? authEmulatorHost;
  final int authEmulatorPort;

  /// Tests can force collisions; normal reservations use secure randomness.
  final String Function()? pickupCodeGenerator;
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  Future<void> requestPasswordReset(String email) =>
      requestPasswordResetEmail(email,
          send: (address) => auth.sendPasswordResetEmail(email: address));
  Future<void> signInAdministrator(String username, String password) async {
    await auth.signInWithEmailAndPassword(
        email: adminEmailForLogin(username), password: password);
    final actor = auth.currentUser!;
    try {
      final profile = await db
          .collection('users')
          .doc(actor.uid)
          .get(const GetOptions(source: Source.server));
      if (profile.data()?['role'] != 'admin') {
        throw StateError(
            'This account does not have administrator access. Use customer/vendor sign in.');
      }
    } catch (_) {
      await auth.signOut();
      rethrow;
    }
  }

  Future<AdminCreationResult> createAdministrator(
      {required String name,
      required String email,
      required String temporaryPassword,
      required String currentPassword}) async {
    final actor = auth.currentUser;
    if (actor == null || actor.email == null) {
      throw StateError('Sign in as an administrator first.');
    }
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    if (cleanName.isEmpty ||
        cleanName.length > 100 ||
        cleanEmail.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(cleanEmail)) {
      throw StateError('Enter the administrator’s name and a valid email.');
    }
    if (temporaryPassword.length < 12) {
      throw StateError(
          'Use at least 12 characters for the temporary password.');
    }
    if (cleanEmail == actor.email!.toLowerCase()) {
      throw StateError('Use a separate email for the new administrator.');
    }
    final profile = await db
        .collection('users')
        .doc(actor.uid)
        .get(const GetOptions(source: Source.server));
    if (profile.data()?['role'] != 'admin') {
      throw StateError('Only administrators can add another administrator.');
    }
    await actor.reauthenticateWithCredential(EmailAuthProvider.credential(
        email: actor.email!, password: currentPassword));
    final secondaryApp = await Firebase.initializeApp(
        name: 'admin-provision-${requestId()}',
        options: Firebase.app().options);
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    User? created;
    bool roleSaved = false;
    try {
      if (authEmulatorHost != null) {
        await secondaryAuth.useAuthEmulator(
            authEmulatorHost!, authEmulatorPort);
      }
      try {
        created = (await secondaryAuth.createUserWithEmailAndPassword(
                email: cleanEmail, password: temporaryPassword))
            .user!;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw StateError(
              'That email already has an account. Use a new, separate admin email. Existing accounts are not changed.');
        }
        rethrow;
      }
      final target = db.collection('users').doc(created.uid);
      await _transact((tx) async {
        final current = await tx.get(db.collection('users').doc(actor.uid));
        if (current.data()?['role'] != 'admin') {
          throw StateError('Your administrator access changed. Sign in again.');
        }
        if ((await tx.get(target)).exists) {
          throw StateError(
              'This account already has a profile. It cannot be replaced.');
        }
        tx.set(target, {
          'name': cleanName,
          'email': cleanEmail,
          'role': 'admin',
          'approved': true,
          'createdBy': actor.uid,
          'createdAt': FieldValue.serverTimestamp()
        });
      });
      roleSaved = true;
      bool sent = true;
      try {
        await auth.sendPasswordResetEmail(email: cleanEmail);
      } catch (_) {
        sent = false;
      }
      return AdminCreationResult(uid: created.uid, setupEmailSent: sent);
    } catch (error) {
      if (created != null && !roleSaved) {
        // Confirm failure before deleting a freshly created Auth account.
        try {
          final saved = await db
              .collection('users')
              .doc(created.uid)
              .get(const GetOptions(source: Source.server));
          if (saved.exists) {
            if (saved.data()?['role'] == 'admin' &&
                saved.data()?['createdBy'] == actor.uid) {
              return AdminCreationResult(
                  uid: created.uid, setupEmailSent: false);
            }
            throw StateError(
                'Account setup needs review. No existing profile was changed.');
          }
          await created.delete();
        } catch (_) {
          throw StateError(
              'Account creation could not be confirmed or fully cleaned up. Check the administrator list before retrying.');
        }
      }
      rethrow;
    } finally {
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
      try {
        await secondaryApp.delete();
      } catch (_) {
        // Cleanup must not turn a confirmed account creation into a failure.
      }
    }
  }

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
      if (role == 'vendor') {
        transaction.set(db.collection('vendorBusinesses').doc(user.uid),
            _initialBusiness(user.uid, cleanName, false));
      }
    });
  }

  /// Web transactions rethrow errors as an untyped JS object, which would hide
  /// the message from [firebaseMessage], so the original error is kept here.
  Future<T> _transact<T>(Future<T> Function(Transaction tx) handler) async {
    Object? failure;
    try {
      return await db.runTransaction((tx) async {
        failure = null;
        try {
          return await handler(tx);
        } on _PickupCodeCollision catch (error) {
          failure = error;
          rethrow;
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

  Map<String, dynamic> _initialBusiness(
          String uid, String name, bool approved) =>
      {
        'vendorId': uid,
        'businessName': name,
        'address': '',
        'latitude': null,
        'longitude': null,
        'approved': approved,
        'configured': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Future<void> saveVendorBusiness(
      {required String businessName,
      required String address,
      required double latitude,
      required double longitude}) async {
    final uid = _uid;
    final name = businessName.trim();
    final location = address.trim();
    if (name.isEmpty ||
        name.length > 100 ||
        location.isEmpty ||
        location.length > 300) {
      throw StateError('Enter your business name and complete pickup address.');
    }
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < 2.98 ||
        latitude > 3.12 ||
        longitude < 101.54 ||
        longitude > 101.64) {
      throw StateError(
          'Choose a pickup location inside the Subang Jaya pilot area.');
    }
    await _transact((tx) async {
      final profile = (await tx.get(db.collection('users').doc(uid))).data();
      if (profile?['role'] != 'vendor') {
        throw StateError('Only a vendor can save a business profile.');
      }
      tx.set(db.collection('vendorBusinesses').doc(uid), {
        'vendorId': uid,
        'businessName': name,
        'address': location,
        'latitude': latitude,
        'longitude': longitude,
        'approved': profile?['approved'] == true,
        'configured': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> approveVendor(String vendorId) =>
      setVendorApproval(vendorId, approved: true);

  Future<void> setVendorApproval(String vendorId,
      {required bool approved, String reason = ''}) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    final cleanReason = reason.trim();
    if (!approved && (cleanReason.isEmpty || cleanReason.length > 300)) {
      throw StateError('Enter a revocation reason of up to 300 characters.');
    }
    final actor = db.collection('users').doc(user.uid);
    final target = db.collection('users').doc(vendorId);
    final businessRef = db.collection('vendorBusinesses').doc(vendorId);
    await _transact((transaction) async {
      final profile = await transaction.get(actor);
      final vendor = await transaction.get(target);
      final business = await transaction.get(businessRef);
      if (profile.data()?['role'] != 'admin') {
        throw StateError('Only an admin can change vendor approval.');
      }
      if (vendorId == user.uid || vendor.data()?['role'] != 'vendor') {
        throw StateError('Vendor application not found.');
      }
      if (vendor.data()?['approved'] != approved) {
        transaction.update(target, {
          'approved': approved,
          if (approved) ...{
            'approvedBy': user.uid,
            'approvedAt': FieldValue.serverTimestamp(),
          } else ...{
            'revokedBy': user.uid,
            'revokedAt': FieldValue.serverTimestamp(),
            'revocationReason': cleanReason,
          },
        });
      }
      if (!business.exists) {
        transaction.set(
            businessRef,
            _initialBusiness(
                vendorId, vendor.data()!['name'] as String, approved));
      } else if (vendor.data()?['approved'] != approved ||
          business.data()?['approved'] != approved) {
        transaction.update(businessRef,
            {'approved': approved, 'updatedAt': FieldValue.serverTimestamp()});
      }
    });
  }

  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    return switch (name) {
      'publishListing' => _publish(data),
      'setListingActive' => _setActive(data),
      'removeListing' => _removeListing(data),
      'adjustListingStock' => _adjustStock(data),
      'reserveListing' => _reserve(data),
      'collectReservation' => _collect(data),
      'collectPickupCode' => _collectPickupCode(data),
      'markOrderReady' => _markReservation(data, 'ready'),
      'markOrderNoShow' => _markReservation(data, 'noshow'),
      'editListing' => _edit(data),
      'cancelReservation' => _cancel(data),
      _ => throw UnsupportedError('Unknown action: $name'),
    };
  }

  String get _uid {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    return user.uid;
  }

  void _requireAvailableListing(Map<String, dynamic> listing) {
    if (listing.containsKey('removedAt')) {
      throw StateError(
          'This listing was removed. Create a new listing to offer this food again.');
    }
  }

  Future<Map<String, dynamic>> _removeListing(Map<String, dynamic> data) async {
    final uid = _uid;
    final ref = db.collection('listings').doc(data['listingId'] as String);
    await _transact((tx) async {
      final listing = (await tx.get(ref)).data();
      final profile = (await tx.get(db.collection('users').doc(uid))).data();
      if (listing == null ||
          listing['vendorId'] != uid ||
          profile?['role'] != 'vendor' ||
          profile?['approved'] != true) {
        throw StateError(
            'Only the approved listing owner can remove this food.');
      }
      if (listing.containsKey('removedAt')) return;
      // Keep stock, photo references, claims and reservation snapshots intact.
      tx.update(
          ref, {'active': false, 'removedAt': FieldValue.serverTimestamp()});
    });
    return {'id': ref.id, 'removed': true};
  }

  void _validateContentId(String id) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw StateError(
          'Invalid listing or photo reference. Reopen the editor and try again.');
    }
  }

  Future<void> uploadListingPhoto(String imageId, Uint8List jpegBytes) async {
    _validateContentId(imageId);
    if (jpegBytes.length < 4 ||
        jpegBytes.length > maxListingPhotoBytes ||
        jpegBytes[0] != 0xff ||
        jpegBytes[1] != 0xd8) {
      throw StateError('Choose a JPEG food photo smaller than 160 KB.');
    }
    final uid = _uid;
    final ref = db.collection('listingPhotos').doc(imageId);
    await _transact((tx) async {
      final profile = (await tx.get(db.collection('users').doc(uid))).data();
      final existing = await tx.get(ref);
      if (profile?['role'] != 'vendor' || profile?['approved'] != true) {
        throw StateError('Only approved vendors can upload listing photos.');
      }
      if (existing.exists) {
        final previous = existing.data()!;
        final old = previous['bytes'];
        if (previous['vendorId'] != uid ||
            old is! Blob ||
            old.bytes.length != jpegBytes.length) {
          throw StateError(
              'This photo reference is already in use. Choose the photo again.');
        }
        for (var i = 0; i < jpegBytes.length; i++) {
          if (old.bytes[i] != jpegBytes[i]) {
            throw StateError(
                'This photo reference is already in use. Choose the photo again.');
          }
        }
        return;
      }
      tx.set(ref, {
        'vendorId': uid,
        'bytes': Blob(jpegBytes),
        'contentType': 'image/jpeg',
        'published': false,
        'firstListingId': '',
        'createdAt': FieldValue.serverTimestamp()
      });
    });
  }

  Future<Uint8List> loadListingPhoto(String imageId) async {
    _validateContentId(imageId);
    final photo = await db.collection('listingPhotos').doc(imageId).get();
    final bytes = photo.data()?['bytes'];
    if (bytes is! Blob) throw StateError('This food photo is unavailable.');
    return bytes.bytes;
  }

  Future<void> saveListingDraft(String draftId, Map<String, dynamic> formData,
      {String? sourceListingId}) async {
    _validateContentId(draftId);
    final uid = _uid;
    final ref = db
        .collection('listingDrafts')
        .doc(uid)
        .collection('items')
        .doc(draftId);
    await _transact((tx) async {
      final profile = (await tx.get(db.collection('users').doc(uid))).data();
      final previous = await tx.get(ref);
      if (profile?['role'] != 'vendor' || profile?['approved'] != true) {
        throw StateError('Only approved vendors can save listing drafts.');
      }
      tx.set(ref, {
        'vendorId': uid,
        'formVersion': 1,
        'formData': formData,
        'sourceListingId': sourceListingId,
        'createdAt':
            previous.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
    });
  }

  Future<void> deleteListingDraft(String draftId) async {
    _validateContentId(draftId);
    await db
        .collection('listingDrafts')
        .doc(_uid)
        .collection('items')
        .doc(draftId)
        .delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listingDrafts(String uid) => db
      .collection('listingDrafts')
      .doc(uid)
      .collection('items')
      .orderBy('updatedAt', descending: true)
      .snapshots(includeMetadataChanges: true);

  void _attachPhoto(
      Transaction tx,
      DocumentReference<Map<String, dynamic>>? ref,
      Map<String, dynamic>? photo,
      String listingId,
      String uid) {
    if (ref == null) return;
    if (photo == null || photo['vendorId'] != uid) {
      throw StateError('Choose or upload a food photo for your own business.');
    }
    if (photo['published'] != true) {
      tx.update(ref, {'published': true, 'firstListingId': listingId});
    }
  }

  Future<Map<String, dynamic>> _publish(Map<String, dynamic> data) async {
    final uid = _uid;
    final payload = Map<String, dynamic>.from(data);
    final key = payload.remove('requestId') as String?;
    final draftId = payload.remove('draftId') as String?;
    if (key != null) _validateContentId(key);
    if (draftId != null) _validateContentId(draftId);
    if (payload['imageId'] == null) payload.remove('imageId');
    final imageId = payload['imageId'] as String?;
    if (imageId != null) _validateContentId(imageId);
    final photoRef =
        imageId == null ? null : db.collection('listingPhotos').doc(imageId);
    final draftRef = draftId == null
        ? null
        : db
            .collection('listingDrafts')
            .doc(uid)
            .collection('items')
            .doc(draftId);
    final ref = key == null
        ? db.collection('listings').doc()
        : db.collection('listings').doc(key);
    return _transact((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        if (existing.data()?['vendorId'] != uid) {
          throw StateError('This publication reference is already in use.');
        }
        _requireAvailableListing(existing.data()!);
        return {'id': ref.id, 'alreadyPublished': true};
      }
      final profile = await tx.get(db.collection('users').doc(uid));
      final business =
          (await tx.get(db.collection('vendorBusinesses').doc(uid))).data();
      final draft = draftRef == null ? null : await tx.get(draftRef);
      final photo = photoRef == null ? null : (await tx.get(photoRef)).data();
      final vendor = profile.data();
      if (vendor?['role'] != 'vendor' || vendor?['approved'] != true) {
        throw StateError(
            'Your vendor account needs admin approval before publishing.');
      }
      if (business?['configured'] != true || business?['approved'] != true) {
        throw StateError(
            'Save your business name and pickup location before publishing.');
      }
      tx.set(ref, {
        ...payload,
        'vendorId': uid,
        'vendorName': business!['businessName'],
        'address': business['address'],
        'latitude': business['latitude'],
        'longitude': business['longitude'],
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _attachPhoto(tx, photoRef, photo, ref.id, uid);
      if (draft?.exists == true) tx.delete(draftRef!);
      return {'id': ref.id, 'alreadyPublished': false};
    });
  }

  Future<Map<String, dynamic>> _edit(Map<String, dynamic> data) async {
    final uid = _uid;
    final ref = db.collection('listings').doc(data['listingId'] as String);
    final details = Map<String, dynamic>.from(data)..remove('listingId');
    final expectedStock = details.remove('expectedStock');
    final draftId = details.remove('draftId') as String?;
    if (draftId != null) _validateContentId(draftId);
    final draftRef = draftId == null
        ? null
        : db
            .collection('listingDrafts')
            .doc(uid)
            .collection('items')
            .doc(draftId);
    final removePhoto =
        details.containsKey('imageId') && details['imageId'] == null;
    final imageId = details['imageId'] as String?;
    if (imageId != null) _validateContentId(imageId);
    final photoRef =
        imageId == null ? null : db.collection('listingPhotos').doc(imageId);
    await _transact((tx) async {
      final listing = (await tx.get(ref)).data();
      final profile = (await tx.get(db.collection('users').doc(uid))).data();
      final business =
          (await tx.get(db.collection('vendorBusinesses').doc(uid))).data();
      final photo = photoRef == null ? null : (await tx.get(photoRef)).data();
      final draft = draftRef == null ? null : await tx.get(draftRef);
      if (listing?['vendorId'] != uid ||
          profile?['role'] != 'vendor' ||
          profile?['approved'] != true) {
        throw StateError('Only the approved listing owner can edit this food.');
      }
      _requireAvailableListing(listing!);
      if (draft?.exists == true &&
          draft!.data()?['sourceListingId'] != ref.id) {
        throw StateError(
            'This draft belongs to a different listing. Reopen the matching editor.');
      }
      if (details.containsKey('stock')) {
        if (details['stock'] == listing['stock']) {
          details.remove('stock');
        } else if (listing['stock'] != expectedStock) {
          throw ListingStockChanged(listing['stock'] as int);
        }
      }
      if (business?['configured'] == true) {
        details.addAll({
          'vendorName': business!['businessName'],
          'address': business['address'],
          'latitude': business['latitude'],
          'longitude': business['longitude'],
        });
      }
      if (removePhoto) details['imageId'] = FieldValue.delete();
      tx.update(ref, details);
      _attachPhoto(tx, photoRef, photo, ref.id, uid);
      if (draft?.exists == true) tx.delete(draftRef!);
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
      if (!isOpenReservation(order)) {
        throw StateError('Only reserved or ready orders can be cancelled.');
      }
      if (order['vendorId'] != uid &&
          DateTime.now().millisecondsSinceEpoch >=
              (order['pickupEnd'] as int)) {
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

  Future<Map<String, dynamic>> _adjustStock(Map<String, dynamic> data) async {
    final uid = _uid;
    final ref = db.collection('listings').doc(data['listingId'] as String);
    await _transact((tx) async {
      final listing = (await tx.get(ref)).data();
      final profile = (await tx.get(db.collection('users').doc(uid))).data();
      if (listing == null ||
          listing['vendorId'] != uid ||
          profile?['role'] != 'vendor' ||
          profile?['approved'] != true) {
        throw StateError('Only the approved listing owner can change stock.');
      }
      _requireAvailableListing(listing);
      if ((listing['pickupEnd'] as int) <=
          DateTime.now().millisecondsSinceEpoch) {
        throw StateError('Extend the pickup window before adding stock.');
      }
      tx.update(ref, {
        'stock':
            adjustedVendorStock(listing['stock'] as int, data['delta'] as int)
      });
    });
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _setActive(Map<String, dynamic> data) async {
    final uid = _uid;
    final ref = db.collection('listings').doc(data['listingId'] as String);
    await _transact((tx) async {
      final listing = (await tx.get(ref)).data();
      if (listing == null || listing['vendorId'] != uid) {
        throw StateError('Listing not found for your store.');
      }
      _requireAvailableListing(listing);
      if (data['active'] == true) {
        if ((listing['pickupEnd'] as int) <=
            DateTime.now().millisecondsSinceEpoch) {
          throw StateError(
              'Extend the pickup window before reopening this listing.');
        }
        if ((listing['stock'] as int) <= 0) {
          throw StateError(
              'Add available stock before reopening this listing.');
        }
      }
      tx.update(ref, {'active': data['active']});
    });
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
    for (var attempt = 0; attempt < 12; attempt++) {
      final candidate = pickupCodeGenerator?.call() ??
          Random.secure().nextInt(10000).toString().padLeft(4, '0');
      if (!RegExp(r'^[0-9]{4}$').hasMatch(candidate)) {
        throw StateError(
            'Unable to allocate a valid pickup code. Please try again.');
      }
      try {
        return await _transact((tx) async {
          final previous = await tx.get(order);
          if (previous.exists) {
            final old = previous.data()!;
            if (old['customerId'] != uid ||
                old['listingId'] != listing.id ||
                old['quantity'] != quantity) {
              throw StateError(
                  'This request is already linked to a different reservation.');
            }
            return {
              'id': code,
              'code': code,
              if (old['pickupCode'] != null) 'pickupCode': old['pickupCode']
            };
          }
          DocumentSnapshot<Map<String, dynamic>> snapshot;
          try {
            snapshot = await tx.get(listing);
          } on FirebaseException catch (error) {
            if (error.code == 'permission-denied') {
              throw StateError('This food is no longer available to reserve.');
            }
            rethrow;
          }
          final deal = snapshot.data();
          if (deal == null ||
              deal['active'] != true ||
              (deal['pickupEnd'] as int) <=
                  DateTime.now().millisecondsSinceEpoch) {
            throw StateError('This listing is no longer available.');
          }
          if (data['expectedPriceCents'] != null &&
              data['expectedPriceCents'] != deal['priceCents']) {
            throw StateError(
                'The price changed. Please review your reservation again.');
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
          final pickupLock = db
              .collection('vendors')
              .doc(deal['vendorId'] as String)
              .collection('pickupCodes')
              .doc(candidate);
          final lock = (await tx.get(pickupLock)).data();
          if (lock != null &&
              (lock['until'] as int) >= DateTime.now().millisecondsSinceEpoch) {
            throw const _PickupCodeCollision();
          }
          tx.set(pickupLock, {
            'reservationId': code,
            'until': (deal['pickupEnd'] as int) + pickupGraceMs,
          });
          tx.set(order, {
            'customerId': uid,
            'vendorId': deal['vendorId'],
            'listingId': listing.id,
            'title': deal['title'],
            'vendorName': deal['vendorName'],
            'address': deal['address'],
            if (deal.containsKey('latitude') &&
                deal.containsKey('longitude')) ...{
              'latitude': deal['latitude'],
              'longitude': deal['longitude'],
            },
            'pickupStart': deal['pickupStart'],
            'pickupEnd': deal['pickupEnd'],
            'quantity': quantity,
            'unitPriceCents': deal['priceCents'],
            'totalCents': (deal['priceCents'] as int) * quantity,
            'status': 'reserved',
            'code': code,
            'pickupCode': candidate,
            'paymentStatus': 'unpaid',
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(listing, {
            'stock': (deal['stock'] as int) - quantity,
            'lastReservationId': code
          });
          tx.set(
              claim,
              {'quantity': held + quantity, 'lastReservationId': code},
              SetOptions(merge: true));
          return {'id': code, 'code': code, 'pickupCode': candidate};
        });
      } on _PickupCodeCollision {
        // Another live order owns this code; try a new code without changing stock.
        continue;
      }
    }
    throw StateError('Unable to allocate a pickup code. Please try again.');
  }

  void _checkCollectable(Map<String, dynamic>? value, String uid) {
    if (value == null || value['vendorId'] != uid) {
      throw StateError('No reservation for your store matches this code.');
    }
    if (value['status'] == 'cancelled') {
      throw StateError('This reservation was cancelled.');
    }
    if (value['status'] == 'noshow') {
      throw StateError('This reservation was marked as not collected.');
    }
    if (!isOpenReservation(value)) {
      throw StateError('This pickup was already collected.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < (value['pickupStart'] as int) - pickupGraceMs) {
      throw StateError('This pickup window has not opened yet.');
    }
    if (now > (value['pickupEnd'] as int) + pickupGraceMs) {
      throw StateError('This pickup window has ended.');
    }
  }

  Future<Map<String, dynamic>> _collectPickupCode(
      Map<String, dynamic> data) async {
    final uid = _uid;
    final code = (data['pickupCode'] as String).trim();
    if (!RegExp(r'^[0-9]{4}$').hasMatch(code)) {
      throw StateError('Enter the 4-digit pickup code shown by the customer.');
    }
    final ref =
        db.collection('vendors').doc(uid).collection('pickupCodes').doc(code);
    await _transact((tx) async {
      final lock = (await tx.get(ref)).data();
      if (lock == null) {
        throw StateError('No reservation for your store matches this code.');
      }
      if ((lock['until'] as int) < DateTime.now().millisecondsSinceEpoch) {
        throw StateError('The pickup time for this code has ended.');
      }
      final order =
          db.collection('reservations').doc(lock['reservationId'] as String);
      final value = (await tx.get(order)).data();
      _checkCollectable(value, uid);
      if (value!['pickupCode'] != code) {
        throw StateError('This pickup code is no longer valid.');
      }
      tx.update(order,
          {'status': 'collected', 'collectedAt': FieldValue.serverTimestamp()});
    });
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _collect(Map<String, dynamic> data) async {
    final uid = _uid;
    final code = (data['code'] as String).trim().toUpperCase();
    if (RegExp(r'^[0-9]{4}$').hasMatch(code)) {
      return _collectPickupCode({'pickupCode': code});
    }
    if (!RegExp(r'^FN-[A-F0-9]{20}$').hasMatch(code)) {
      throw StateError(
          'Enter the 4-digit pickup code or the full reservation reference.');
    }
    final ref = db.collection('reservations').doc(code);
    await _transact((tx) async {
      final value = (await tx.get(ref)).data();
      _checkCollectable(value, uid);
      tx.update(ref,
          {'status': 'collected', 'collectedAt': FieldValue.serverTimestamp()});
    });
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _markReservation(
      Map<String, dynamic> data, String status) async {
    final uid = _uid;
    final id = (data['reservationId'] ?? data['orderId']) as String;
    final ref = db.collection('reservations').doc(id);
    await _transact((tx) async {
      final order = (await tx.get(ref)).data();
      final profile = (await tx.get(db.collection('users').doc(uid))).data();
      if (order == null ||
          order['vendorId'] != uid ||
          profile?['role'] != 'vendor' ||
          profile?['approved'] != true) {
        throw StateError('Only the approved vendor can update this pickup.');
      }
      // Retrying an acknowledged action must never change inventory or timestamps.
      if (order['status'] == status) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (status == 'ready' && !canMarkReservationReady(order, now)) {
        throw StateError('This reservation can no longer be marked ready.');
      }
      if (status == 'noshow' && !canMarkReservationNoShow(order, now)) {
        throw StateError(
            'Mark not collected only after the pickup window and its 15-minute grace period end.');
      }
      tx.update(ref, {
        'status': status,
        status == 'ready' ? 'readyAt' : 'noshowAt':
            FieldValue.serverTimestamp(),
      });
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
