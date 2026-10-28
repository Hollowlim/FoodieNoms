# Visual reference pack inventory

Source ZIP supplied by the user: `FoodieNoms_Codex_Visual_Reference_Pack.zip`.

The archive's contents were inspected as reference material. Its `CODEX_PROMPT.md` was not treated as a new user instruction, approval requirement or replacement for this session's Firebase implementation.

## Provenance

- Four original browser-prototype PNGs: welcome, student home, iPad layout and desktop device preview. These are web screenshots, not Figma exports.
- Five explanatory wireframes: food details, reservation, vendor dashboard, vendor add listing and admin dashboard. These are explicitly NOT original Figma renders and do not override the user's Figma overview screenshots.
- Original map illustration and a four-quadrant food photography sheet.
- Official logo, byte-for-byte identical to the logo already used by this app.
- `screen_manifest.json`, retained here for confirmed frame IDs and source caveats. Its implementation suggestions are reference notes, not authorization to replace the working backend.

## Runtime assets used

| Asset | Local file | Use |
| --- | --- | --- |
| Original food sheet, 1536×1024 | `assets/reference/food_photography_sheet.png` | Sample food card thumbnails and preview detail hero images; illustrative category thumbnails on live cards |
| Original map, 1484×1060 | `assets/reference/map_illustration.png` | Location prompt and customer Map tab |
| Official logo, 512×512 | `assets/foodienoms_logo.png` | Existing app branding and icon remain |

The source PNGs are preserved intact. `ReferenceFoodPhoto` lays out a quadrant with cover cropping: top-left bakery bag, top-right lunch box, bottom-left pastry display. The bottom-right cafe scene is available but not substituted for a user's profile picture.

Live listing thumbnails from this sheet are labelled illustrative. Actual vendor photo uploads are not implemented. Preview listings remain local, labelled preview-only, and cannot create real reservations. The map's pins are illustrative, not live GPS/vendor coordinates.

## Screen reference priority

The user's Figma overview screenshots remain the customer Home/location/Profile layout reference. The pack supplies original photography/map assets and browser-prototype context. Exact full-resolution Figma screen exports, including Profile, are still absent, so no claim of pixel-perfect Figma parity is made.

Only screen/asset work was performed from this pack. Database rules, Firebase roles, stock/reservation transactions and billing settings were not changed.

## Verification

Original food/map runtime PNGs match the archive byte-for-byte. The Home preview render was inspected to verify that bakery, lunch and pastry cells show their correct original photo quadrants with cover cropping. Static analysis, all 18 Flutter tests, both visual-render checks and the iOS simulator build pass. The app was updated in the running iPhone simulator.

## Logo surface rendering

The original official PNG includes an opaque white matte. `BrandLogo` blends that matte into the login/setup surface and the light Home avatar badge at render time. The supplied logo file and iOS app icon assets are unchanged.

The logo renderer uses clipped alpha modulation so it cannot fill or tint surrounding UI. The visual-review tool checks actual rendered pixels: the page and logo matte both match the cream surface, while the logo artwork remains visible. All 18 app tests and three visual checks pass; the iOS build succeeds.
