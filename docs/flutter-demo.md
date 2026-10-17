# Flutter Android demo design and implementation

The client needs an installed mobile application for their first presentation. Implement the same Student, Vendor, and Administrator demonstration in Flutter/Dart, with green, mint and cream styling from the supplied screenshots. Use native Material widgets and responsive layouts. Retain the earlier web sample as a separate reference.

All roles share an in-memory DemoStore inside one app session. No real accounts, payment, GPS, or backend. Reset starts the presentation over; closing the app clears demo changes. The central flow is vendor approval → publishing → student reservation → matching pickup code → collection. Cancellation restores stock once. Pending vendors cannot publish. Administrators can moderate listings and see event history.

Implementation steps:
- Add tested Dart models and reservation/vendor/listing state transitions.
- Add role selection, native navigation, student discovery/detail/checkout/pass/orders/profile, vendor dashboard/editor/collection, and admin approval/moderation/reporting.
- Generate the standard Android runner with Flutter, run analysis and Flutter tests, and build a debug APK when toolchains are available.
- Add GitHub Actions validation and APK artifact upload; document local Android installation and demo limitations.

Verification includes store tests for invalid quantities, overselling, duplicate cancellation/collection and vendor approval, plus widget tests for role navigation and the reservation journey. Do not report an APK as built without successful build evidence.
