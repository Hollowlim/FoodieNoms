# Vendor surplus listing upgrade

Implemented in the existing Firebase app on 6 November 2026.

## What changed

- **Food details:** required name/category/contents, expandable extra description, camera/gallery photos, replace/remove, illustrative presets, ingredients, allergens, dietary tags and vendor-declared halal status. No automatic halal certification.
- **Pricing & quantity:** integer cents, positive prices, student price below the original, discount/savings summary and stock adjustment controls.
- **Pickup & publish:** registered shop/address, collapsible existing map, local start/end date and time, Starts Now, instructions, student preview, Save Draft and Publish.
- Each step validates before advancing. Earlier values survive Back, drafts and failures. Busy actions prevent duplicate submissions. Leaving changed work prompts to save or discard.
- Vendor dashboard separates Published and Drafts, supports resume/delete draft, edit, List Again, stock changes, availability and reservation navigation. Statuses are Draft, Active, Sold out, Expired and Unavailable.
- Student discovery and food details display uploaded photos and full food information, with a clearly labelled illustrative fallback.

## Files

New production files:

- `lib/firebase/listing_editor.dart`: the production three-step screen and injectable form actions.
- `lib/firebase/listing_editor_model.dart`: validation, integer money, draft serialization, duplication and publish payloads.
- `lib/firebase/listing_photo.dart`: native picker/recovery, image processing and shared photo display.

Updated integration:

- `lib/firebase/app.dart`, `student_ui.dart`, `vendor_ui.dart`, `service.dart`.
- `firestore.rules`, `firestore.indexes.json`.
- `pubspec.yaml`, `pubspec.lock`, generated Flutter plugin metadata and iOS Swift package resolution.
- `ios/Runner/Info.plist`: camera and photo-library explanations.
- `android/`: added the previously missing Android platform, branded app label, foreground location/internet permissions and Firebase configuration. Minimum Android SDK 24.
- `lib/firebase_options.dart`, `firebase.json`: registered Android app `com.foodienoms.foodienoms` in the same Firebase project.

Tests and review tools:

- `test/listing_editor_model_test.dart`, `listing_editor_test.dart`, `listing_photo_test.dart`, updated `vendor_ui_test.dart`.
- `functions/test/listing-editor.emulator.js`.
- `tool/client_emulator_check.dart`, `tool/capture_listing_editor.dart`.

## Database and authorization

Changes are additive. Existing listings and reservation snapshots need no migration.

Listings retain the existing required fields. Optional new fields are `foodDescription`, `ingredients`, `allergens`, `dietaryTags`, `halalStatus`, `pickupInstructions` and `imageId`. `description` still means included contents; `dietary` remains a legacy-compatible summary; `imageKey` remains an illustrative preset.

Private drafts are stored at `listingDrafts/{vendorUid}/items/{draftId}` with `formVersion: 1`, bounded partial `formData`, optional source listing ID and timestamps. Only the owning vendor can read drafts; approved owners can save/delete. Saving is server-confirmed and needs a connection. No draft is shown to students.

Actual photos are separate immutable documents at `listingPhotos/{imageId}`. They contain owner, JPEG bytes, content type, timestamp, publication flag and first listing ID. Approved vendors upload their own photos. Private photos are readable only by their owner/admin. Customer access begins atomically with a valid publication and requires the vendor to remain approved. Other vendors cannot attach another business’s photos. Photo bytes have an index exemption.

Firebase remains on the existing Spark setup. This implementation does not use Firebase Storage or deploy Cloud Functions. Firebase Storage currently requires Blaze: [official Storage FAQ](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).

Source files are limited to 12 MiB and 20 million pixels before decoding. One frame is normalized, resized and encoded as a JPEG of at most **160 KiB**. Source EXIF/GPS/text metadata is removed. Processing uses a worker isolate on native platforms. The image cache is bounded and scoped to the signed-in identity.

The native picker records its draft association before opening. Every form field is saved first. On Android, resume the matching draft to recover a lost picker result after activity destruction. Native cache recovery is best effort: cleared OS cache requires selecting the photo again. Web blob paths cannot survive a browser restart; save the uploaded photo in a draft first.

Publishing uses a stable request ID, so retrying an uncertain result does not create another listing. Photo publication and draft deletion occur in the same successful transaction. Failed publication keeps the draft/photo and form. Uploads can be retried using the same immutable photo ID.

The service derives business name/address/coordinates from the registered business record. It never writes shop GPS from the editor. Existing order pickup/price/title snapshots are preserved. Reservation transactions still prevent overselling and enforce the existing per-customer cap. Stock edits use an expected-stock check; conflicts return the current stock for review. Unchanged stock is omitted from edits.

New pickup windows can start now or up to five minutes ago, and must end in the future within 30 days. Existing ongoing listings may retain their past start when editing. All values are persisted as epoch milliseconds and edited/displayed in the device’s local timezone. Overnight pickup uses a separately selectable end date. List Again copies food/photo information and clears prices, stock and both pickup times.

## Dependencies added

- `image_picker ^1.2.4`: actual camera/gallery selection and Android lost-result recovery.
- `image ^4.12.0`: bounded JPEG compression, orientation normalization and metadata removal.
- `shared_preferences ^2.5.6`: local picker recovery association only; cloud Firestore stores drafts.

## Validation

- `flutter analyze`: no issues found. Dart formatting completed.

- 109 Flutter tests passed, including the existing customer/admin/map/pickup suites and new listing validation, draft restoration, duplication, failure, double-submission, stock conflict, metadata removal and 320px/keyboard layout cases.
- 52 Firestore emulator tests passed, including photo immutability/privacy/publication, draft ownership, invalid values, additive fields and existing order protection.
- 9 real Flutter Firebase client journeys passed against isolated Auth/Firestore emulators. The new journey exercises actual JPEG upload/reload, partial draft restore, failed publication retention, idempotent publication, atomic draft deletion, stock conflict, edit, duplicate and concurrent reservations without overselling.
- The production editor and student preview rendered successfully at iPhone width. Captures are in `build/listing-preview/`; regenerate with `flutter test tool/capture_listing_editor.dart`.
- iOS simulator debug build succeeded and was installed/launched in the iPhone 18 Pro Device Hub simulator.
- Tested Firestore rules and the photo index exemption were deployed to `foodienoms-42a7d`.
- Android platform/Firebase setup is included. The Android APK build was attempted but stopped with **No space left on device** while extracting Gradle. An Android APK and physical-device camera test are not claimed as passed.

## Try it on iPhone

1. Open **Device Hub**, then FoodieNoms. Sign in with an approved vendor. Pending vendors must be approved through the existing admin Vendors page.
2. Complete the business profile and save a valid Subang/USJ pickup pin if prompted.
3. Tap **Add Surplus Food**. Fill Food details, scroll to Camera/Gallery and choose a food photo or an illustrative preset.
4. Enter original/student prices and quantity. Continue, choose an unexpired pickup end and optionally change start date/time.
5. Open **Preview**, then publish. Sign in as a student to find and reserve the listing.
6. Test partial **Save draft**, dashboard **Drafts → Resume**, edit, **List again**, mark unavailable and **Pickups**. List Again requires fresh prices, stock and times.

To rebuild with the existing owner admin username mapping:

```sh
flutter run -d <iphone-device-id> --dart-define-from-file=config/admin.local.json
```

The iOS simulator cannot take a real camera photo. Gallery JPEG/PNG selection works; use a physical iPhone for camera/permission checks. Some HEIC selections are unsupported in the simulator; the app explains the failure and retains the draft.

## Try it on Android

Free enough disk space for Android Studio/SDK, Gradle and the NDK, then install the Android SDK and accept its licenses. Run `flutter doctor`, connect an Android 7.0+ phone with USB debugging or start an Android emulator, then:

```sh
flutter devices
flutter run -d <android-device-id> --dart-define-from-file=config/admin.local.json
```

Use the same vendor/student accounts and steps above. Check gallery, camera permission denial/retry and keyboard layout on the device. For Android activity recovery, open the picker from a saved draft, let the OS destroy the activity, then reopen FoodieNoms and resume that draft.

## Limits

This is a bounded Spark-compatible photo implementation, not a high-volume media service. Photos consume Firestore storage/read quotas. Published and abandoned photo documents are retained; automatic orphan cleanup is not implemented, so history and uncertain uploads are not accidentally deleted. A larger launch should move media delivery/cleanup to a suitable object store and update the adapter/rules deliberately.

The current app has no dark theme; the editor follows its existing light theme. Camera/gallery permissions, OS activity destruction and real GPS need physical-device checks in addition to the completed automated and iOS simulator checks. Android release signing/distribution remains a separate release step.
