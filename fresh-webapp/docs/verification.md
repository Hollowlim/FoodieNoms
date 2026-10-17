# Fresh web app verification

## Implemented and checked

- New classic HTML/CSS/JavaScript application in this folder; no imports from the earlier app or Flutter code. Recreated static assets are reused with their provenance stated.
- Sixteen isolated data tests pass: approval, publishing, stock, validated prices/quantities/time windows, snapshots, cancellation, pickup, favourites, profile, persistence/corruption recovery and reset.
- Browser flow passed: bad Admin password denied → correct login → Cafe approval → Vendor publishes → Student searches/reserves two portions → pickup pass → wrong collection code denied → matching code collected.
- Browser checks passed: signup choices, no saved passwords, saved favourites, cancellation with exactly-once stock restoration, suspended account status, reapproval after rejection, and session logout.
- Viewport checks: 320×667, 393×852, 744×1133, 820×1180, 1180×820, 1024×1366, plus short 852×393 Admin landscape. No document horizontal overflow in the tested screens; short sidebars scroll.
- Device preview selects phone/tablet iframe dimensions and rotates without reloading app state. At 100% zoom, oversized frames can scroll without losing the left edge.
- All 33 service-worker app-shell resource paths exist. Registration is skipped on Live Server loopback addresses to keep edits fresh. An explicit test registration installed successfully; after networking was disabled, reload, images, login, discovery and reservations worked offline.
- No browser JavaScript errors in these journeys. Optional static build produces the current new app, with relative paths for a project subfolder.

## Visual checks and limits

Screenshots in `screenshots/` show the actual Chromium-rendered app and device preview. The palette and compact mobile structure are grounded in the provided FoodieNoms screenshot boards; iPad adds a sidebar and food-card columns. The iPad layout is an adaptation because no original iPad frame was supplied. An exact Figma pixel match is not claimed: original logo/photo exports remain unavailable and these raster assets are recreations.

These are Chromium viewport checks, not Safari, Xcode, an iOS simulator or physical iPhone/iPad tests. No public HTTPS deployment, actual Home Screen installation or App Store/TestFlight publication was performed. The included manifest/service worker prepare a web app for hosting; they do not create a native iOS binary. Data and demo access checks are local, without a backend or production authentication.

## Files

- `iphone-start.png`: 393×852 account selection.
- `iphone-home.png`: 393×852 Student home.
- `ipad-home.png`: 820×1180 Student home.
- `device-preview.png`: 1400×1100 desktop showing a phone frame and working controls.


## Premium presentation refresh

Verified at 320×667, 393×852, 820×1180 and 1180×820 in Chromium: only Student/Vendor on welcome, login header within first 100 CSS pixels, no document horizontal overflow, reservation through pickup pass, no visible demo labels. Separate `index.html?admin=1` rejects an incorrect password and accepts the configured credentials. No browser JavaScript errors. Existing 20 data tests, syntax checks and static build passed. Real iOS Safari validation remains outstanding.
