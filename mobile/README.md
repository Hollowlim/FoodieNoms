# FoodieNoms — Flutter Android app

This is the **mobile application**, written in **Dart with Flutter**, for a first client demonstration. It has native Android navigation, forms and screens matching the green/cream FoodieNoms references. It does not open or embed the earlier website.

## Get an installable Android APK from GitHub

1. Open the repository’s **Actions** tab.
2. Choose **Build Android demo APK**, then the latest successful run.
3. Under **Artifacts**, download **FoodieNoms-Android-APK** (GitHub sign-in may be required).
4. Extract `app-debug.apk`, transfer it to an Android phone and open it to install. Android may ask you to allow installation from that particular file manager/browser; allow only if you trust this build.

The workflow produces a debug-signed APK for demonstrations, not a Play Store release. Artifacts expire after 30 days; rerun the workflow with **Run workflow** to make a new one. An APK exists only after the build job succeeds. This is Android-only scaffolding; it is not an iPhone installation package.

## Build/run locally

Install **Flutter 3.35.7**, Java 17 and Android Studio with the Android SDK. Android 7.0/API 24 or newer is required by this runner. From the repository root:

```sh
cd mobile
flutter create --platforms=android --org com.foodienoms --project-name foodienoms --no-pub .
flutter pub get
flutter doctor
flutter analyze
flutter test
flutter run
# Or build an APK:
flutter build apk --debug
```

The `flutter create` command fills in platform-generated files/Gradle launcher scripts that are conventionally not committed. Existing Dart screens, tests and Android files are retained. Open `mobile/` in Android Studio or VS Code, not the repository root.

Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

## Presentation journey

- Select **Administrator** → section dropdown → **Vendors** → approve **Subang Cafe**.
- Top-right menu → **Switch experience** → **Vendor** → **Add Surplus Food**. Enter a name, description, original/rescue prices and quantity; publish.
- Switch to **Student**, find the new food deal, reserve it and confirm the simulated pay-at-pickup checkout. Note/copy the six-digit code.
- Switch to **Vendor** → **Orders** → **Verify collection**. Enter that code and confirm.
- Switch to **Student** → **Orders** or **Administrator** → **Reservations** to see **Collected**. Admin Reports and Activity Log show session activity.
- Use top-right menu → **Reset demo** before another presentation.

## Included

Role selection; Student discovery/search/category/price filters, favourites, illustrative nearby map, food details, quantities, checkout, pickup code, reservations, cancellation and profile; Vendor dashboard, listing creation/editing, approval gating and pickup verification; Admin overview, approval/rejection, listing moderation, reservation oversight, reports and activity.

## Demo limitations

State is held in memory and is shared by the three role experiences **within this app session only**. Closing/restarting the app or resetting clears it. All people, food, ratings and payments are illustrative. Role selection is not authentication, and local stock checks are not backend concurrency protection. No Supabase, payment processor, QR camera, real maps/GPS, notifications or production account system is connected. Food artwork uses emoji; the original logo was not provided as a standalone asset. Do not enter private information.

## Validation

`test/demo_store_test.dart` covers stock, approval, cancellation, pickup, moderation, price snapshots and reset. `test/widget_test.dart` covers role selection, a native reservation flow and Admin approval. GitHub Actions runs analysis and tests before building the APK. Check the run status; source upload alone does not prove a successful build.
