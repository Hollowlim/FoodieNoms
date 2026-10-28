# Proposed live location map

Status: implemented after the user explicitly approved OpenStreetMap and sharing the approximate viewed area on 28 October 2026. The location screen and customer Map tab now use interactive OpenStreetMap tiles.

## Requested behavior

Replace the illustration on the location screen and Map tab with a pan/zoom map, a blue current-location marker, and a re-center control. Keep manual Subang Jaya browsing. Do not add false vendor pins: current vendor listings contain addresses but no latitude/longitude.

## Proposed provider and data flow

Use flutter_map with OpenStreetMap tiles. Loading a viewport requests tiles from `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. These requests disclose the approximate area being viewed and normal network metadata (including the device's public IP) to OpenStreetMap. If the map follows GPS, that viewed area follows the device's approximate location. The app would not upload GPS coordinates to Firebase or add background tracking.

After consent, request location through the existing iOS foreground permission prompt. Keep coordinates in the account session, subscribe while the map is visible and the app is foregrounded, and stop updates when the map closes, the app backgrounds, the user selects manual browsing or signs out. No bulk/offline map downloads or prefetching.

## Provider requirements

Show visible OpenStreetMap attribution with a copyright link, send a stable FoodieNoms app identifier on native tile requests, use normal HTTP caching with a bounded on-device cache, and show a clear loading/error state. Public tile service has usage limits and best-effort availability. Vendor geocoding, nearby-distance filtering and turn-by-turn routing are outside this change.

References:
- https://docs.fleaflet.dev/usage/options
- https://docs.fleaflet.dev/layers/raster-tile-layer/caching
- https://operations.osmfoundation.org/policies/tiles/

## Work completed

Implemented foreground-only live location, a blue device marker, panning/zoom, a re-center control and manual Subang Jaya browsing. Map tile requests use an app identifier, visible attribution and an HTTP-aware bounded cache. No coordinates are saved to Firebase, no Firebase rules were changed, and billing was not enabled.

Validation: all 21 Flutter tests pass. Map tests inject offline tiles and simulated GPS. They verify position updates, drag/re-center, manual reset, unavailable GPS, stopping on route closure, and foreground/background subscription control. A single HEAD request for a pilot-area map tile returned HTTP 200. Real physical-device GPS accuracy and real-world movement remain to be tested on a phone.

To try it: open Map and tap the target button, or open the Home location selector and tap Use My Location. Grant iOS foreground location access. The iOS simulator uses simulated coordinates, not the user's physical position.

The final iOS simulator build succeeds and is installed. The simulator was explicitly set to the test coordinate `3.0567, 101.5851` (Subang Jaya) for trying the marker; this is simulated, not the user's physical location. The normal iOS permission prompt still applies when the user taps Use My Location. Firebase and billing settings were unchanged.
