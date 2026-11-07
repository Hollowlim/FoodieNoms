import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reference_assets.dart';
import 'service.dart';

class FoodPhotoException implements Exception {
  const FoodPhotoException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PreparedListingPhoto {
  const PreparedListingPhoto(
      {required this.bytes, required this.width, required this.height});
  final Uint8List bytes;
  final int width, height;
}

/// Decode one frame, normalize orientation, and strip all source metadata.
/// The bounded JPEG lives separately from the lightweight listing document.
PreparedListingPhoto prepareListingPhoto(Uint8List input) {
  if (input.isEmpty || input.length > 12 * 1024 * 1024) {
    throw const FoodPhotoException('Choose a food photo smaller than 12 MB.');
  }
  try {
    final decoder = img.findDecoderForData(input);
    final info = decoder?.startDecode(input);
    if (info == null || info.width <= 0 || info.height <= 0) {
      throw const FoodPhotoException(
          'This photo format is unavailable. Choose a JPEG or PNG photo.');
    }
    if (info.width * info.height > 20000000) {
      throw const FoodPhotoException(
          'This photo is too large to process. Choose a smaller photo.');
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) {
      throw const FoodPhotoException(
          'This photo could not be read. Try another.');
    }
    var oriented = img.bakeOrientation(decoded);
    final scale =
        math.min(1.0, 1024 / math.max(oriented.width, oriented.height));
    if (scale < 1) {
      oriented = img.copyResize(oriented,
          width: math.max(1, (oriented.width * scale).round()),
          height: math.max(1, (oriented.height * scale).round()),
          interpolation: img.Interpolation.average);
    }
    // Construct a fresh image from pixels; EXIF (including GPS), ICC, and text
    // metadata from the source are never copied into the uploaded JPEG.
    var clean = img.Image.fromBytes(
        width: oriented.width,
        height: oriented.height,
        bytes: oriented.getBytes(order: img.ChannelOrder.rgb).buffer,
        numChannels: 3,
        order: img.ChannelOrder.rgb);
    for (final size in [1024, 800, 640, 480]) {
      if (math.max(clean.width, clean.height) > size) {
        final ratio = size / math.max(clean.width, clean.height);
        clean = img.copyResize(clean,
            width: math.max(1, (clean.width * ratio).round()),
            height: math.max(1, (clean.height * ratio).round()),
            interpolation: img.Interpolation.average);
      }
      for (final quality in [78, 64, 48]) {
        final bytes = img.encodeJpg(clean, quality: quality);
        if (bytes.length <= maxListingPhotoBytes) {
          return PreparedListingPhoto(
              bytes: bytes, width: clean.width, height: clean.height);
        }
      }
    }
    throw const FoodPhotoException(
        'This photo could not fit the upload limit. Choose a simpler photo.');
  } on FoodPhotoException {
    rethrow;
  } catch (_) {
    throw const FoodPhotoException(
        'This photo could not be read. Choose a JPEG or PNG photo.');
  }
}

class FoodPhotoPicker {
  FoodPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  final _preferences = SharedPreferencesAsync();
  static const _pendingKey = 'foodienoms.pendingFoodPhoto.v1';

  Future<Map<String, dynamic>?> _pending() async {
    final raw = await _preferences.getString(_pendingKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<PreparedListingPhoto> _prepare(XFile file) async {
    if (await file.length() > 12 * 1024 * 1024) {
      throw const FoodPhotoException('Choose a food photo smaller than 12 MB.');
    }
    return compute(prepareListingPhoto, await file.readAsBytes());
  }

  Future<PreparedListingPhoto?> pick(ImageSource source,
      {required String uid, required String draftId}) async {
    // The editor has already saved every form field to its private cloud draft.
    // Persist the association before Android can destroy the native activity.
    final previous = kIsWeb ? null : await _pending();
    if (!kIsWeb) {
      await _preferences.setString(
          _pendingKey, jsonEncode({'uid': uid, 'draftId': draftId}));
    }
    try {
      final file = await _picker.pickImage(
          source: source,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 80,
          requestFullMetadata: false);
      if (file == null) {
        if (!kIsWeb) {
          if (previous == null) {
            await clearRecovery(uid: uid, draftId: draftId);
          } else {
            await _preferences.setString(_pendingKey, jsonEncode(previous));
          }
        }
        return null;
      }
      if (!kIsWeb) {
        await _preferences.setString(_pendingKey,
            jsonEncode({'uid': uid, 'draftId': draftId, 'path': file.path}));
      }
      return await _prepare(file);
    } on PlatformException catch (error) {
      throw FoodPhotoException(error.code.contains('access_denied') ||
              error.code.contains('permission')
          ? 'Photo access is disabled. Allow camera/photos in Settings, or choose an illustrative photo.'
          : 'The camera or gallery is unavailable. Try the other option or an illustrative photo.');
    }
  }

  Future<PreparedListingPhoto?> recover(
      {required String uid, required String draftId}) async {
    if (kIsWeb) return null;
    final record = await _pending();
    if (record?['uid'] != uid || record?['draftId'] != draftId) return null;
    try {
      if (record?['path'] is String) {
        return await _prepare(XFile(record!['path'] as String));
      }
      if (defaultTargetPlatform != TargetPlatform.android) return null;
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty) return null;
      if (lost.files?.isNotEmpty == true) {
        final file = lost.files!.first;
        await _preferences.setString(_pendingKey,
            jsonEncode({'uid': uid, 'draftId': draftId, 'path': file.path}));
        return await _prepare(file);
      }
      throw const FoodPhotoException(
          'The previous photo could not be recovered. Select it again.');
    } on FoodPhotoException {
      rethrow;
    } catch (_) {
      throw const FoodPhotoException(
          'The previous photo is no longer available. Your draft is saved; select the photo again.');
    }
  }

  Future<void> clearRecovery(
      {required String uid, required String draftId}) async {
    if (kIsWeb) return;
    final record = await _pending();
    if (record?['uid'] == uid && record?['draftId'] == draftId) {
      await _preferences.remove(_pendingKey);
    }
  }
}

/// A small session cache scoped to Firebase project AND signed-in identity.
/// No private draft photo can be reused by a later signed-in account.
class _PhotoCache {
  static final items = <String, Uint8List>{};
  static String? session;
  static Future<Uint8List> load(FoodieService service, String id) async {
    final scope =
        '${service.db.app.options.projectId}:${service.auth.currentUser?.uid}';
    if (session != scope) {
      items.clear();
      session = scope;
    }
    final old = items.remove(id);
    if (old != null) {
      items[id] = old;
      return old;
    }
    final bytes = await service.loadListingPhoto(id);
    if (session == scope) {
      items[id] = bytes;
      while (items.length > 24) {
        items.remove(items.keys.first);
      }
    }
    return bytes;
  }
}

class ListingFoodPhoto extends StatefulWidget {
  const ListingFoodPhoto(
      {super.key,
      required this.service,
      required this.listing,
      this.bytes,
      this.showBadge = true});
  final FoodieService? service;
  final Map<String, dynamic> listing;
  final Uint8List? bytes;
  final bool showBadge;
  @override
  State<ListingFoodPhoto> createState() => _ListingFoodPhotoState();
}

class _ListingFoodPhotoState extends State<ListingFoodPhoto> {
  String? scope;
  Future<Uint8List>? photo;
  void updatePhoto() {
    final id = widget.listing['imageId'] as String?;
    final next = '$id:${widget.service?.auth.currentUser?.uid}';
    if (scope == next) return;
    scope = next;
    photo = id == null || widget.service == null
        ? null
        : _PhotoCache.load(widget.service!, id);
  }

  Widget bitmap(Uint8List bytes) => Image.memory(bytes,
      fit: BoxFit.cover,
      gaplessPlayback: false,
      cacheWidth: 1024,
      errorBuilder: (_, __, ___) => unavailable());
  Widget unavailable() => const ColoredBox(
      color: Color(0xFFE9EEE7),
      child: Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.black45)));

  @override
  Widget build(BuildContext context) {
    updatePhoto();
    final actual = widget.bytes != null || widget.listing['imageId'] != null;
    return Semantics(
        image: true,
        label: actual ? 'Vendor food photo' : 'Illustrative food photo',
        child: Stack(fit: StackFit.expand, children: [
          if (widget.bytes != null)
            bitmap(widget.bytes!)
          else if (!actual)
            ReferenceFoodPhoto(index: listingPhotoIndex(widget.listing))
          else if (photo == null)
            unavailable()
          else
            FutureBuilder<Uint8List>(
                key: ValueKey(scope),
                future: photo,
                builder: (context, snapshot) {
                  if (snapshot.hasData) return bitmap(snapshot.data!);
                  if (snapshot.hasError) {
                    return GestureDetector(
                        onTap: () => setState(() {
                              scope = null;
                            }),
                        child: Semantics(
                            label: 'Photo unavailable. Tap to retry.',
                            button: true,
                            child: unavailable()));
                  }
                  return const ColoredBox(
                      color: Color(0xFFE9EEE7),
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)));
                }),
          if (widget.showBadge)
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                    color: const Color(0xA6000000),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 3, horizontal: 2),
                        child: Text(actual ? 'Vendor photo' : 'Illustrative',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9))))),
        ]));
  }
}
