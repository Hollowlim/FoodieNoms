# Ready, Not collected and 4-digit pickup codes

This phase adapts the useful pickup features from [teammate PR #2](https://github.com/Hollowlim/FoodieNoms/pull/2) into the current FoodieNoms app. The current one-listing reservation flow, prices, saved shop coordinates, photos, drafts, removal, accounts and QR verification are preserved. Pickup slots, multi-listing baskets and simulated payment remain a later phase. The remote PR was not merged wholesale.

## Try the flow

1. A customer creates a new reservation. Orders → View pickup QR shows both a **4-digit pickup code** and the existing QR.
2. The vendor opens Pickups → Pending and taps **Mark ready**. The customer sees **Ready for pickup** in Orders and the in-app updates feed.
3. At handover, the vendor can scan the existing QR, type the 4-digit code and confirm collection, or use the order’s existing Mark collected confirmation.
4. An uncollected reserved/ready order becomes eligible for **Not collected** only after its saved pickup end plus 15 minutes. The vendor confirms this action. It moves into the Not collected history tab and its usable QR/code is hidden.
5. Reserved and ready orders can still be cancelled under the existing cutoff rules. Cancellation returns stock and allowance atomically. Marking Not collected retains the original stock deduction, as in the teammate’s prototype; the confirmation explains this choice.

Pending/Upcoming includes both reserved and ready orders. The live customer detail, list and vendor pending count update from Firestore. The new status feed is in-app; no push notification service was introduced.

Older reservations retain their long FN reference and QR; no backfill is required. They can also be marked ready or, after their window/grace, not collected. Only new reservations receive the new 4-digit counter code.

Expired open pickup passes also hide their usable QR/code after the grace period, even if the vendor has not yet marked them Not collected. They retain their order details and show a pickup-window-ended message.

## Backend

All calls use the existing `FoodieService.call`:

| Action | Payload |
| --- | --- |
| Reserve current listing | `reserveListing`: existing `listingId`, `quantity`, `requestId`, optional `expectedPriceCents` |
| Mark ready | `markOrderReady`: `reservationId` |
| Mark not collected | `markOrderNoShow`: `reservationId` |
| Collect short code | `collectPickupCode`: `pickupCode` as a 4-character string |
| Existing collection | `collectReservation`: `code` accepts the short code or existing FN reference |
| Existing cancellation | `cancelReservation`: `reservationId` |

Status calls also accept `orderId` as an alias for the reservation ID in this single-listing phase. They do not implement grouped orders.

Reservation additions are optional `pickupCode`, `readyAt` and `noshowAt`. Codes are strings so leading zeroes survive. The existing `code` remains the immutable long reference used in the QR. A reservation always retains its original pickup window and location snapshot.

`vendors/{vendorUid}/pickupCodes/{code}` contains only `reservationId` and `until` (saved pickup end + grace, epoch milliseconds). Each new reservation claims its code in the same transaction as stock, the per-customer claim and the reservation. Occupied codes trigger a bounded retry without changing stock. A code can be reused at a shop only after the previous collection window expires. Repeated reservation requests return their original code. Different shops have independent namespaces.

Authenticated allocation can read a code record’s opaque reference and expiry. Code records cannot be listed, and order details stay restricted to their customer/vendor/admin. Collection and status updates remain restricted to the approved owning vendor. Marking ready/no-show cannot change price, quantity, pickup snapshots or inventory. Completed/cancelled/no-show orders cannot be collected again. Retrying acknowledged status updates preserves their timestamps.

No schema migration, new index, package, payment service, Cloud Function or paid-plan change is required. New rules still accept older reservation writes without a short code, preserving older app builds.

## Changed files

- `lib/firebase/order_state.dart`: shared labels, open-state/tab matching and grace eligibility.
- `lib/firebase/service.dart`: atomic code allocation, collision handling, Ready/Not collected and short-code verification.
- `lib/firebase/pickup_ui.dart`: short code alongside QR, status-aware pass and vendor controls.
- `lib/firebase/app.dart`: status actions/confirmation, live order filtering, customer updates and manual code entry.
- `lib/firebase/student_experience.dart`: Not collected history tab.
- `lib/firebase/vendor_ui.dart`: ready orders included in pending counts.
- `firestore.rules`: code locks, optional code fields and status-transition authorization.
- `test/pickup_status_test.dart`, `functions/test/pickup-status.emulator.js`, `tool/client_emulator_check.dart`: UI/rule/client integration checks.

## Testing

The added checks cover leading zeroes, collisions, expired code reuse, cross-shop uniqueness, ownership, immutable codes/snapshots, one-time collection, Ready cancellation, no-show timing and retained stock, legacy reservations/QR and small-phone history navigation. The real client fixture uses only explicit localhost demo emulators and never seeds production records.

Verified: all 137 Flutter tests, 63 Firestore emulator cases and 11 real Firebase client journeys pass. `flutter analyze` reports no issues. Customer and vendor pickup widgets render successfully at iPhone size. The iOS simulator build is checked separately before installation; physical-camera scanning remains a device check.

The iOS simulator build succeeded. The tested rules were deployed to `foodienoms-42a7d` on 7 November 2026. No production orders or pickup codes were seeded or migrated by the automated tests.
