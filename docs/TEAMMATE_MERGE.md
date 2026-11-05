# Listing, pickup and cancellation integration

Imported teammate PR #1, already merged into GitHub main at c46ad21ee116075cbdf20405357b80d375eb5402. Local integration preserves the existing customer, vendor and admin screens.

- Listing edits: approved owners can edit their own content, prices, remaining stock and pickup window. Existing orders retain their original snapshots. Saving unchanged stock does not overwrite reservations made while the form was open.
- Reservations: at most five items per customer per listing across non-cancelled orders. A claim document is updated atomically with each reservation; rejected requests leave stock unchanged.
- Collection: allowed from 15 minutes before the pickup start through 15 minutes after its end, checked by both client and server rules.
- Cancellation: customers may cancel before their order's pickup end; approved owning vendors can cancel reserved orders later to clear no-shows. Cancellation restores stock and claim quantity atomically and is safe to retry. Completed orders cannot be cancelled.
- Immediate pickup: new listings can start up to five minutes ago if the window is still open.

Added Edit listing and Cancel reservation controls to the app. The latter asks for confirmation. The service supports legacy reservations without claim documents and cancellation after a listing is paused. Approved owners may read claim documents for their listings to perform the cancellation transaction; other customers/vendors cannot.

Validation: Flutter analysis and widget tests; complete Node/Firestore emulator suite; five real FoodieService journeys in headless Chrome with local Auth and Firestore emulators; iOS simulator build.

These files are a coordinated client/rules update. Deploy firestore.rules before using the updated reservation, edit or cancellation flows against the live project. Older client versions do not write claims and cannot reserve under the new rules. No live Firebase deployment is performed by merging the source.
