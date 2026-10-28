# FoodieNoms design reference

User-provided Figma prototype:
https://www.figma.com/design/AthrFGHOcn4U7G1Fiu4oZY/FoodieNoms-%7C-Group-39-%7C-Student-Vendor-Admin-Prototype?node-id=0-1

File key: `AthrFGHOcn4U7G1Fiu4oZY`.

Requested next implementation: match the customer Home (including location) and Profile screens to this prototype, preserving working Firebase Spark functionality.

Inspection on 27 October 2026 was blocked: the root/page design-context request returned no selected layer, and metadata discovery returned the Figma account's Starter-plan MCP call limit. The shared URL was also inaccessible through the web tool. No design screenshot or high-fidelity screen context was obtained, so the current Flutter screens must not be described as matching this Figma file.

Next input needed: exported images/screenshots of customer Home and Profile, or node-specific links after Figma tool access becomes available. Keep this link as the canonical reference; do not invent another layout and claim template fidelity.

## Screenshot implementation — 27 October 2026

The user supplied overview screenshots of the prototype after connector access was exhausted. The customer Home (green discovery header and compact cards), location prompt/illustrative map, and Profile layout are being implemented from those screenshots. The attached overviews have no exportable source assets or exact design tokens, so this is a screenshot-based translation rather than a verified pixel-exact Figma import.

Shared presentation widgets live in `lib/firebase/student_ui.dart`. Customer navigation is Home / Map / Orders / Profile. The profile uses the actual user's name/email and initials; source demo photography was not available. Existing sample food illustrations remain in preview cards until original photos are supplied or vendor image upload is implemented.

Device location is opt-in, foreground-only, and retained for the account session. Manual browsing always offers the Subang Jaya pilot. The drawn map is explicitly illustrative; current listing records have no coordinates and cannot support true distances or navigation. Live listing addresses remain available before reservation. No location data is written to Firestore.

The profile savings card is labelled as upcoming tracking rather than displaying the prototype's invented RM38.50 as real savings. Personal information and password reset are wired to account data; notifications show reservation updates; reviews remain clearly unavailable. Vendor/admin layouts, the full onboarding design and other template modules are outside this customer Home/location/Profile pass.

Validation: static analysis passes, all 18 Flutter tests pass, Home/Profile renders at iPhone width complete, and the iOS simulator build succeeds. Manual location selection and denied GPS permission preserve browsing. No Firebase schema, live security rules or billing settings were changed in this customer UI pass.

## Original assets supplied in visual reference ZIP

The user subsequently supplied `FoodieNoms_Codex_Visual_Reference_Pack.zip`. Its original map and food photography sheet have replaced the customer map drawing and food emoji placeholders. The official logo is identical to the installed logo. The archive explicitly contains browser screenshots and structural wireframes, not original Figma screen exports; its instruction documents were treated as reference data. See `docs/ui-references/README.md` for the asset inventory and source priority. Original profile photography is still absent; account initials remain appropriate.

## Live map supersedes the illustrative map

The user explicitly approved OpenStreetMap map-area disclosure. The active customer Map tab and location screen now use `LiveLocationMap`, with foreground-only device location and manual browsing. The original map image is retained as a reference asset. This functional enhancement intentionally replaces the prototype's illustrative pins; no fake vendor GPS positions are shown. See `docs/LIVE_MAP_PLAN.md`.
