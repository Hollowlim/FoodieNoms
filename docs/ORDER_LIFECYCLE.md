# Orders, pickup slots and pickup codes

Backend for the reservation flow in Han's TBS-approved prototype. The current Flutter screens keep working unchanged; the new calls are for the screens that follow Han's design.

## Service calls

All calls go through `FoodieService.call(name, data)`.

| Screen in Han's prototype | Call | Data |
|---|---|---|
| Basket and payment, "Reserve & pay" | `reserveOrder` | `requestId`, `items` (1 to 3 of `{listingId, quantity}`, one shop), optional `slotStart`, optional `paymentMethod` |
| Reservation confirmed, order screen | `orderItems(role, uid, orderId)` stream | Every item in the order, live |
| Student "Cancel order" | `cancelOrder` | `orderId` |
| Vendor "Mark ready" | `markOrderReady` | `orderId` |
| Vendor "Not collected" | `markOrderNoShow` | `orderId` |
| Vendor "Verify pickup", 4 digits | `collectPickupCode` | `pickupCode` |

`reserveOrder` returns `orderId`, `pickupCode`, `ids`, `slotStart` and `slotEnd`. The existing `reserveListing`, `cancelReservation` and `collectReservation` calls still work.

## Rules

- **Slots** are 15 minutes, on the quarter hour, and must overlap each item's pickup window. Without `slotStart`, the earliest open slot is used. There is no limit per slot.
- **Orders** group items from one shop. Each item is written separately because rules may read at most 20 documents per write. If a later item fails, earlier items are cancelled, so stock and allowances return.
- **Pickup codes** are 4 digits, unique per shop while the order can still be collected. A code is stored at `vendors/{vendorId}/pickupCodes/{code}` and becomes free again 15 minutes after its slot ends.
- **Statuses:** `reserved` → `ready` → `collected`. Open orders (`reserved` or `ready`) can be cancelled: students until the slot ends, vendors at any time. Vendors can mark an open order `noshow` only once collection is no longer possible.
- **Collection** is allowed from 15 minutes before the slot to 15 minutes after it. Orders placed before slots existed keep the listing's whole window.
- **Payment** is simulated. With `paymentMethod` (`ewallet`, `banking` or `card`), the order is saved as `test_paid`; without it, `unpaid`. No money moves. A sandbox "payment fails" outcome should not call `reserveOrder`.
- **Categories** add Han's Café, Dessert, Drinks and Others; Pastries and Other remain for existing listings.

## Decisions behind this

| Topic | Decision |
|---|---|
| Payment | Simulated only, using Han's payment screen |
| Slot capacity | No limit |
| Removing food | Hide (pause), never delete |
| No-show stock | Not returned, as in the prototype. The proposal does not cover this. |
| Food photos | Preset photos. The proposal requires an image but not uploads, and Cloud Storage needs the paid Blaze plan. |

## Deploying

Merge and deploy `firestore.rules` together with an app built from this code. Builds that include PR #1 can still reserve under these rules, without slots or pickup codes. Builds from before PR #1 cannot reserve, as they do not write claims.
