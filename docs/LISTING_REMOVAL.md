# Vendor listing removal

Each published listing card has **Remove listing**, including expired, sold-out and unavailable items. Confirm removal or choose **Keep listing**. The button disables during confirmation/saving, and errors leave the item available for retry.

Removal hides the item from the vendor’s Published list and stops student discovery/new reservations. Existing reservations stay in Pickups/Orders with their original title, price, pickup window and location. Vendors can still complete or cancel them; customer cancellation follows the existing cutoff.

## Storage and permissions

`FoodieService.call('removeListing', {'listingId': id})` runs a transaction that checks the authenticated owner and approved vendor profile. It sets only `active: false` and a server `removedAt` timestamp. Repeated removal is idempotent.

The listing record, photo, stock, claim counters and reservations are retained. This is necessary for stock releases, existing pickup history and duplicate-request handling. Permanent record deletion remains prohibited. No migration or new index is required; older listings have no `removedAt` field and work unchanged.

Rules allow only the approved owner to add the removal timestamp while making the listing inactive. Timestamp forgery, changing other fields during removal, later reopening/editing, removing the marker and hard deletion are denied. Existing reservation cancellation/collection permissions remain enabled. A removed listing cannot be reactivated by a stale app or publish retry. There is no restore action in the current UI; create a new listing if needed.

The vendor dashboard filters removed documents from every Published status filter and count. A customer still viewing the removed item gets an unavailable message rather than account-permission instructions.

## Files

- `lib/firebase/vendor_ui.dart`: Remove listing action/confirmation, progress/errors and hidden removed records.
- `lib/firebase/service.dart`: authenticated removal transaction, stale edit/reopen/publish guards and a clear stale-reservation error.
- `lib/firebase/app.dart`: unavailable-deal feedback for students.
- `firestore.rules`: approved-owner removal and immutable removal marker.
- `test/vendor_listing_removal_test.dart`: active/expired removal confirmation, cancellation, duplicate submission, failure, busy and narrow layouts.
- `functions/test/listing-removal.emulator.js`: removal ownership, timestamps, field constraints, irreversible state and retained data.
- `tool/client_emulator_check.dart`: real Firebase client removal, blocked new sales, preserved snapshots, vendor/customer cancellations and collection after removal.

No live listings are automatically removed by installing the update or publishing the rules. A vendor must confirm each removal in the app.

## Verification

`flutter analyze` reports no issues. All 127 Flutter tests and 56 Firestore emulator tests pass. All 10 real Firebase client journeys pass, including removal, blocked new sales, preserved order snapshots, vendor/customer cancellation, collection of an existing order and rejection of stale reopening/publish attempts. The iOS simulator debug build succeeds.

The tested Firestore rules were released to `foodienoms-42a7d` on 7 November 2026. No listings were removed as part of deployment.
