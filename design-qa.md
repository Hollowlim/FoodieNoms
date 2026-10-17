# Screenshot reconstruction QA

final result: blocked

## Scope and source truth

Reference: the user's inline FoodieNoms boards in this conversation: account/authentication; Student app; Vendor app; desktop Admin; extension/module screens. These are the selected visual targets. No original standalone screenshots, logo exports or photos were available as local files: the attached development PDF has no embedded image assets. Exact pixel comparison and a combined source/implementation image could therefore not be produced. This is not a claim of pixel-perfect acceptance.

Implementation evidence: `docs/screenshots/account.png`, `login.png`, `student-discover.png`, `food-detail.png`, `vendor-dashboard.png`. Desktop Admin was additionally inspected in `/tmp/foodienoms-reference-admin.png` during this session. Screenshots were captured from Chromium-rendered HTML using Playwright, not inferred from source code.

## Dimensions and states

Reference mobile frames are approximately 244 × 494 pixels on the supplied boards. Implementation target is 390 × 790 CSS pixels, deviceScaleFactor 1, a proportional scale of approximately 1.6. Frames expand vertically when live content requires it. Admin reference is approximately 512 × 422 and implementation target 1024 × 844 (scale 2). Browser capture viewport: 1200 × 1050; evidence uses element screenshots of the frame. Actual responsive overflow checks ran at 320 and 390 CSS pixels. Source board downscaling and different sample states prevent exact pixel measurements.

Clean screenshots show initial sample state. The functional journey separately creates a fourth listing and a reservation, so that state intentionally differs from the source's three sample listing rows. Source boards themselves show different inventory/order states on different screens.

## Review and iteration history

- P1 original wide desktop hero/layout: replaced with centered app frames, compact phone content and separate desktop Admin sidebar.
- P1 emoji food artwork: replaced with photographic raster assets. Library icons use official Tabler SVG files.
- P2 login spacing: reduced excess space above demo role shortcuts and adjusted text weight.
- P2 discovery list height: reduced row padding to restore the source's compact three-row density.
- P2 Vendor dashboard height: removed inherited action-group bottom padding that created an oversized blank region.
- P2 signup account selector: replaced dropdown with the source's Student / Food Vendor pill choices without losing form entries.
- P2 food-detail structure: removed unrequested quantity/favourite controls from the main detail layout; quantities remain in the basket module and favourites can be saved in their module.
- Post-fix captures were regenerated and visually inspected for account, login, discovery, details and Vendor dashboard. No remaining core interaction failure or horizontal overflow was found in the tested journey.

## Fidelity surfaces

- Typography: Arial/Helvetica sans-serif with source-like compact weights and 22–25px mobile headings. Original font metadata is unavailable, so exact font matching is unconfirmed.
- Spacing/layout: phone proportions, header placement, compact deal list, footer, button groups, plain account choices and Admin columns follow the boards; the earlier marketing-site composition is removed.
- Colours/tokens: cream #FCFAF5, primary #29643B, dark green #18543E, mint #EAF2DB, teal #187452. These are inferred from supplied boards rather than measured original Figma tokens.
- Images: P1 exact-original asset fidelity remains blocked. Logo, food/cafe photographs, profile image and illustrated map are generated recreations, not extracted source assets. Their subjects follow the references but cannot be passed as exact matches. See `src/assets/README.md`.
- Copy: principal source headings, labels, role names, prices and CTA text restored. Additional code/status and honest demo outcomes appear where needed for interaction. Static baseline Admin numbers are explicitly illustrative; new session actions adjust relevant values.

## Functional evidence

Four store tests passed, as did syntax checks and static/offline build. Browser checks passed approval → publication → Student search/reservation → code-verified collection, reload persistence, module navigation, and 320/390px overflow checks, with no browser JavaScript errors. The single-file presentation made no further HTTP asset requests and its reservation flow worked after networking was disabled.

Direct `file:///` navigation was blocked by the managed cloud browser's administrator policy. It was not worked around. The presentation uses classic scripts and embedded assets, without module imports or fetch requests; Windows double-click launch remains a user-device check.

## Remaining requirement

Supply the original Figma logo/photo/avatar/map exports and preferably full-resolution individual screen PNGs. Replace generated assets, capture matching states at the original viewport, and perform the combined source/implementation comparison before calling the design an exact match. No claim of exact fidelity or completed website-to-native conversion is made in this revision.

## Requested login and toolbar revision

The outer screen label / Switch experience / Reset demo toolbar was removed from every screen. Admin login uses the requested public demo credentials, with an inline error for a mismatch and an in-portal logout action. Demo role shortcuts were removed. Signup now explicitly offers Student and Vendor and cannot choose Admin. Browser checks passed on source and standalone HTML, including logout/re-login and reservation. These changes do not resolve the original-asset blockers above.
