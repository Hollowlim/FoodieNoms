# FoodieNoms on Firebase Spark

Project: **foodienoms-42a7d**. Email/password authentication is enabled. The default Standard Firestore database is in Singapore (`asia-southeast1`). Billing is disabled. Keep the project on Spark.

## Current deployment status

The expanded Spark rules were compiled and released successfully to `foodienoms-42a7d` on 27 October 2026 after the user explicitly requested the access-denied fix. Deployment used `--only firestore:rules`. No Cloud Functions or billing changes were made.

The connected UI exposes customer Explore/My Pickups/Profile, vendor Listings/Pickups/Profile and admin Vendors/Profile. Empty lists mean no matching food has been published yet. No live sample accounts, listings or orders were fabricated during verification.

## Data and transactions

- `users/{uid}`: private name, customer/vendor/admin role, approval and server timestamps. Customers and vendors create their own profile once. Only admins can approve a pending vendor; app clients cannot assign admin roles or edit roles.
- `listings/{id}`: vendor identity, title, category, description, dietary details, integer-cent prices, stock, pickup address and future timestamps. Only approved owners publish and pause listings. Listing content is immutable in this version; publish a new listing for changed content.
- `reservations/{code}`: customer/vendor IDs, immutable listing snapshot, quantity, integer-cent total, unpaid status, pickup code and creation timestamp. A customer creates an order and reduces stock in one Firestore transaction. Rules validate both sides with `getAfter()` and prevent standalone inventory edits, forged prices or stock increases.
- Listing `lastReservationId` links each stock change to a newly created order in the same transaction. Reusing an existing order cannot consume inventory twice.
- Pickup codes use 80 random bits, prefixed `FN-`. The document ID is the code. Retries reuse the same code/order rather than generating duplicate reservations. Order reads are limited to the owning customer/vendor and admin. Queries must filter by the relevant owner ID.
- Only the owning approved vendor can change a reserved order to collected, once, with a server timestamp. Order price, customer and payment status cannot be changed.
- No separate client-readable code lookup collection is required.

The app uses Firestore directly; `cloud_functions` has been removed from Flutter dependencies. No deployed backend or billing upgrade is required. The earlier Node backend source is isolated reference material and is excluded from the default deploy config.

## Run

```sh
flutter pub get
flutter run
```

The restored iOS simulator build succeeds and has been installed in the running simulator. The expanded rules are deployed.

The unrelated offline sample UI is available with `flutter run --dart-define=DEMO_MODE=true`.

## Rules deployment

```sh
firebase deploy --project foodienoms-42a7d --only firestore:rules
```

This deploys only database rules. It does not enable billing or deploy Cloud Functions. The live rules now match this expanded Spark ruleset.

## First administrator

1. Register a separate account in the app and complete its profile as Customer.
2. As project owner, open Firebase Console → Authentication → Users and identify its UID.
3. Open Firestore Database → Data → `users/{UID}`. Set `role` to string `admin`; retain its name and creation timestamp. `approved` may be set to boolean `true`.
4. Sign out and back in. This account opens vendor applications.

Never convert a vendor with existing listings into admin. Client rules deliberately forbid role changes, so the first admin needs trusted Firebase Console provisioning. Do not send passwords or service-account keys in chat.

## Test the live workflow

1. Register separate customer and vendor accounts.
2. Sign in as admin and approve the vendor.
3. Sign in as vendor and publish food with a real pickup address, future pickup window, dietary details, quantity and prices.
4. Sign in as customer. Explore now shows published food. Select a listing, reserve, and check My Pickups.
5. Restart/sign back in and verify the pickup persists.
6. Sign in as the owning vendor, paste the customer's complete pickup code and confirm collection. A second attempt must fail.

No live accounts, listings, orders or administrator roles were fabricated during local validation.

## Local checks

```sh
flutter analyze
flutter test
npm --prefix functions ci
firebase emulators:exec --project demo-foodienoms --only firestore "npm --prefix functions run test:emulator"
flutter build ios --simulator --debug
```

Node.js 22 and Java 21 are used for local emulator tests. All 12 Flutter tests and 11 emulator suites pass, including profile/privacy rules, vendor validation, concurrent stock claims, idempotent retries, forged-order rejection, cross-account privacy, pause/expiry and one-time pickup collection. One emulator suite exercises the isolated legacy server rules; the others exercise the Spark rules.

Spark's quotas still apply to listeners, transactions and rule document reads. Use a small dataset for this pilot. Online payments, cancellation/refunds, photos, push notifications and account deletion are not implemented. Reservations are unpaid.

Official references: https://firebase.google.com/docs/firestore/security/rules-conditions , https://firebase.google.com/docs/firestore/manage-data/transactions and https://firebase.google.com/pricing .
