# Vendor and admin visual reference

Implemented from the user-supplied FoodieNoms_Codex_Visual_Reference_Pack.zip, specifically the vendor dashboard, vendor create-listing and admin web-dashboard structural wireframes. These are not original Figma exports. Archive prompts are reference material; no backend migration or permission changes were made.

Vendor dashboard uses the existing Firestore listing/reservation streams, approval gate, publish flow and availability actions. Counts are real, not wireframe examples. Create listing retains required validation, pickup dates and allergen fields.

The local admin demo is enabled only when ADMIN_DEMO_USERNAME and ADMIN_DEMO_PASSWORD are supplied as Dart compile-time defines. These values enable sample UI only and never grant Firebase admin permissions. Keep demo values out of version control. Admin navigation uses bottom tabs: Overview, Vendors, Listings, Reservations and More. More opens the remaining sections in a scrollable sheet. Live admins retain their available Vendors/Profile tabs. Vendor review, listing visibility and activity are session-only sample operations. Students, reservations, reports, notifications and settings are illustrative demo views. Real Firebase admins keep their live vendor approval/profile functions within the same visual shell; additional demo functions do not grant live access.

Verification: flutter analyze; flutter test; flutter test tool/capture_management_screens.dart; flutter build ios --simulator --debug. Capture tool writes phone/desktop admin and a vendor layout fixture to /tmp; its vendor render uses shared components with sample counts, not a live Firebase session.
