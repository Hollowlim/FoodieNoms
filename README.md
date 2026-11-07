# FoodieNoms — Flutter + Firebase Spark

FoodieNoms connects students/customers with approved food vendors in the Subang Jaya pilot area. Customer, vendor and administrator interfaces share one Flutter/Dart codebase. The app uses Firebase Authentication and Cloud Firestore directly, with transactions and Firestore rules enforcing permissions and stock changes.

## Current features

- **Customers:** Home/search/category filters, food details, vendor map pins, optional foreground GPS, reservations, cancellation within the allowed window, order history and QR pickup passes. New reservations also receive a four-digit pickup code. Profile shows Meals Saved from collected item quantities.
- **Vendors:** registration and approval waiting screen, business details and map location, address search or coordinate entry, listing photos, a three-step listing editor, private drafts, preview, editing, stock controls, availability, renewal, duplication and removal. Pickups support Ready, Collected and Not collected statuses, with QR scanning or manual pickup-code entry.
- **Administrators:** live vendor applications, approval/revocation with reasons, an overview and separate administrator account assignment. New administrator accounts require an existing administrator's authorization and password confirmation.
- **Accounts:** shared Email or username login, customer/vendor email registration, password visibility controls and Firebase email password-reset links. Firebase account roles determine the interface; public registration cannot create an administrator.

Reservations are unpaid. Online payments/refunds, push notifications, customer reviews, account deletion and turn-by-turn navigation are not implemented. In-app notifications summarize order status. Estimated financial savings remains a labelled placeholder; Meals Saved counts collected items, not food weight or nutritional portions.

When no matching live food is available, the customer catalogue offers clearly labelled, local preview examples. These cannot be ordered. The separate `DEMO_MODE` preview uses offline sample records unrelated to Firebase accounts.

## Run

Install Flutter and the platform tools, then run from the project root:

```sh
flutter pub get
flutter run
```

The Firebase client configuration targets `foodienoms-42a7d`. It is not an administrator credential; access is restricted by the deployed Firestore rules and each authenticated account's role. Do not commit service-account keys, passwords or local account configuration.

Existing administrators can use their registered email on the normal login screen. To enable the owner's `Admin123` alias on a local build, copy the example file and enter the email of an already provisioned administrator:

```sh
cp config/admin.example.json config/admin.local.json
# Edit config/admin.local.json with your existing administrator email.
flutter run --dart-define-from-file=config/admin.local.json
```

`config/admin.local.json` is ignored by Git. This setting resolves an alias only; it does not create an account or grant administrator access. See [administrator setup](docs/ADMIN_ACCOUNTS.md).

For the separate offline preview:

```sh
flutter run --dart-define=DEMO_MODE=true
```

## Firebase and maps

The current flows are designed for Firebase Spark without deploying Cloud Functions or enabling billing. Small compressed listing photos are stored in separate Firestore documents, with size limits and publication permissions. Dedicated image storage may be needed as usage grows.

The default [Firebase configuration](firebase.json) deploys Firestore rules/indexes and defines local emulators. The earlier Cloud Functions implementation and `firebase.cloud-functions.json` are retained for reference; the Flutter app does not call that server implementation.

Maps use OpenStreetMap through `flutter_map`; place searches use Photon. Device location is optional, foreground-only and not saved to Firebase. The service-area boundary is an approximate Subang/USJ pilot box. Vendor business locations are saved to show customer map pins. See [map behavior](docs/LIVE_MAP_PLAN.md) and [vendor business locations](docs/VENDOR_BUSINESSES.md).

## Checks and builds

```sh
flutter analyze
flutter test
flutter build ios --simulator --debug
npm --prefix functions ci
npm --prefix functions run check
npm --prefix functions test
firebase emulators:exec --project demo-foodienoms --only firestore "npm --prefix functions run test:emulator"
```

For real Flutter clients against local Auth/Firestore emulators, with the Firebase CLI, Java and Chrome available:

```sh
sh tool/run_client_emulator_check.sh
sh tool/run_password_reset_check.sh
```

The latest iOS simulator build succeeds. Android project and Firebase configuration are included, but an Android build has not yet been verified. A device build or store release also needs the appropriate signing setup.

## Implementation notes

- [Firebase setup and data rules](docs/FIREBASE_SETUP.md)
- [Student/customer experience](docs/STUDENT_EXPERIENCE.md)
- [Vendor flow](docs/VENDOR_FLOW.md)
- [Vendor listing editor, photos and drafts](docs/VENDOR_LISTING_EDITOR.md)
- [Listing removal and existing reservations](docs/LISTING_REMOVAL.md)
- [QR pickup flow](docs/QR_PICKUP_FLOW.md)
- [Ready/Not collected statuses and four-digit codes](docs/PICKUP_STATUS_CODES.md)
- [Password recovery](docs/PASSWORD_RECOVERY.md)
- [Design references](docs/DESIGN_REFERENCE.md) and [asset provenance](docs/ui-references/README.md)

The shared UI capture tools under `tool/` render local fixtures without creating production orders. The source includes the selected pickup-status/code behavior adapted from [teammate PR #2](https://github.com/Hollowlim/FoodieNoms/pull/2); multi-item orders, pickup slots and simulated payments from that PR have not been integrated.
