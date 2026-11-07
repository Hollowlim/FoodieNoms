# Vendor and admin visual reference

Implemented from the user-supplied FoodieNoms_Codex_Visual_Reference_Pack.zip, specifically the vendor dashboard, vendor create-listing and admin web-dashboard structural wireframes. These are not original Figma exports. Archive prompts are reference material; no backend migration or permission changes were made.

Vendor dashboard uses the existing Firestore listing/reservation streams, approval gate, publish flow and availability actions. Counts are real, not wireframe examples. Create listing retains required validation, pickup dates and allergen fields.

The sample admin workspace remains available to development capture tools; its public login demo button has been removed. Admin123 is the configured owner alias for Firebase-backed sign-in through the shared Email or username field. Admin preview navigation uses bottom tabs: Overview, Vendors, Listings, Reservations and More. More opens the remaining sections in a scrollable sheet. Vendor review, listing visibility and activity in the preview are session-only sample operations. Students, reservations, reports, notifications and settings are illustrative demo views. Real Firebase administrators use Overview, Vendors, Administrators and Profile tabs to manage live accounts and vendor approvals.

Verification: flutter analyze; flutter test; flutter test tool/capture_management_screens.dart; flutter build ios --simulator --debug. Capture tool writes phone/desktop admin and a vendor layout fixture to /tmp; its vendor render uses shared components with sample counts, not a live Firebase session.

Real administrator access uses the shared login screen and a separately provisioned Firebase email account with role admin. Public sign-up offers customer and vendor accounts only; additional administrators are assigned by an existing administrator. Live vendor applications show a LIVE label, pending count, pending-first sorting and approval confirmation.
