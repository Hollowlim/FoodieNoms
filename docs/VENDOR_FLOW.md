# Vendor onboarding and management

New vendor profiles remain pending until a real administrator approves them. The app displays a dedicated pending-business screen with registration/review/start-selling steps, account email, a server-backed status check and sign out. The existing profile stream automatically switches to the dashboard when approval changes. The local admin demo does not grant real approval.

Approved vendors can publish food, edit content/prices/photos/remaining stock/pickup windows, filter Active/Paused/Sold out/Ended listings, increment/decrement stock, pause/reopen food and renew ended pickup windows. The dashboard scrolls as one list. Stock adjustments read the latest inventory in a transaction and remain subject to the existing approved-owner rules.

New listings default to pickup starting now and ending in two hours; vendors can choose another start/end before publishing. Submission refreshes the immediate-start time, validates the window and returns a success message to the dashboard.

Pickups have Pending/Collected/Cancelled tabs, QR scanning and manual code entry, a per-order handover confirmation and cancellation for reserved orders. Collection timing, single-use status and cancellation inventory release remain enforced by Firestore. Vendor profile includes password reset access.

Validation: Flutter analysis and tests, six real FoodieService flows against local Auth/Firestore emulators, and the iOS simulator build. The inventory flow checks changes after a customer reservation and refusal to reopen a zero-stock listing. No approval flags or live Firebase rules are modified by this UI update.
