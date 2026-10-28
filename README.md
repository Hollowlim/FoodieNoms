# FoodieNoms — Flutter + Firebase Spark

The app is configured for **foodienoms-42a7d**. The connected customer, vendor and admin screens use Firebase Auth and Firestore directly. The Cloud Functions Flutter dependency has been removed.

## Customer preview when the catalogue is empty

If no active vendor listings exist, Explore displays local preview food cards with example prices and detail pages. Search and category filters work on these examples. Every card is marked Preview Only and cannot create an order. Real vendor listings replace these cards automatically. Edit `lib/firebase/customer_preview.dart` to change the examples.

## Connected screens

- Customers: Figma-inspired Home, location selector, interactive OpenStreetMap, search/category filters, food details, atomic reservations, Orders and a fuller Profile.
- Vendors: Listings, publish/pause food, pickup code confirmation, Profile. Publishing and collection require admin approval.
- Admins: vendor applications, approval and Profile. The first administrator is provisioned through trusted setup.
- Accounts: email/password registration, login, password reset, persistent private profiles and sign-out.

All reservations are unpaid. Payments, cancellation/refunds, notifications, photos and account deletion are not implemented.

## Live deployment status

The expanded Spark rules were successfully compiled and released to `foodienoms-42a7d` on 27 October 2026 after the user requested the access-denied fix. Listings, reservations, atomic stock changes and vendor pickup permissions are now enabled under the tested ownership/role restrictions. The app was restarted to reconnect. No live sample food or orders were inserted.

Billing remains disabled. No Cloud Functions deployment or billing upgrade is needed for this implementation.

## Run

```sh
flutter pub get
flutter run
```

The separate offline UI preview remains available with `flutter run --dart-define=DEMO_MODE=true`. Its sample records are unrelated to Firebase accounts.

## Database and testing

See [Firebase setup](docs/FIREBASE_SETUP.md) for role setup, the first admin account, data rules and testing.

```sh
flutter analyze
flutter test
flutter build ios --simulator --debug
firebase emulators:exec --project demo-foodienoms --only firestore "npm --prefix functions run test:emulator"
```

Default Firebase configuration excludes Cloud Functions. The earlier server source and `firebase.cloud-functions.json` are retained for reference only.

## Customer design reference

The customer Home, location/map and Profile were translated from the user's Figma screenshots. See [design notes](docs/DESIGN_REFERENCE.md) for fidelity limits. GPS is optional and session-only; manual Subang Jaya browsing is available. The map can follow device location, but vendor pins and turn-by-turn navigation are not implemented. Original food photography and the map illustration are now bundled from the supplied visual reference pack. Profile photos remain unavailable; the app uses account initials. See [asset provenance](docs/ui-references/README.md).

To render shared Home/Profile widgets without signing in, run `flutter test tool/capture_student_screens.dart`. It writes `/tmp/foodienoms-home-design.png` and `/tmp/foodienoms-profile-design.png` for visual review. These renders use sample profile data and do not touch Firebase.

## Live device location

Customer Map and the Home location selector now use OpenStreetMap with optional live GPS. Tap the target button or Use My Location, then allow location while using the app. Updates stop when no map is open or the app is backgrounded. OpenStreetMap receives the viewed map area as approved by the user; coordinates are not saved to Firebase. The simulator uses simulated coordinates. See [live-map implementation notes](docs/LIVE_MAP_PLAN.md).
