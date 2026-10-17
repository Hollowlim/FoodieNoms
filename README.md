# FoodieNoms — screenshot-based HTML demo

The website has been rebuilt in **plain HTML, CSS and JavaScript** around the screenshots supplied in chat. Desktop browsing preserves the narrow Student/Vendor app proportions rather than turning the design into a wide marketing website. Admin uses the supplied desktop sidebar layout.

## Easiest presentation: no installation

1. Download the latest repository ZIP from GitHub (**Code → Download ZIP**).
2. **Extract All** into a new folder so you do not open the old version.
3. Right-click **`FoodieNoms-demo.html` → Open with → Google Chrome or Microsoft Edge**.

This is a self-contained presentation file: CSS, scripts, photos, logo recreation and icons are embedded. No Node.js, Flutter, internet connection or VS Code extension is needed to run it in a normal browser. It is intended for an external browser, not VS Code's restricted `file:///` preview. If your PC/browser policy blocks local HTML, use Live Server below.

## Edit in VS Code

- Open the extracted root folder containing `index.html`.
- Edit `index.html`, `src/style.css`, `src/app.js` and `src/store.js`.
- Open `index.html` in your external browser, or install **Live Server by Ritwick Dey** and right-click it → **Open with Live Server**.
- VS Code may require you to trust this project folder to enable extensions.

`FoodieNoms-demo.html` is a generated presentation copy. Changes to the source do not update it until you rebuild it.

## Screens and demonstration journey

Start at **Choose your experience**. Student/Vendor open the welcome screen; select **I already have an account** to reach login. The login screen includes **Student demo**, **Vendor demo** and **Admin demo** shortcuts, so no real credentials are needed.

1. Open **Admin demo → Vendors** and approve **Subang Cafe**.
2. Use the **Switch experience** control above the frame. Open Vendor → Login → **Vendor demo**.
3. Select **Add Surplus Food** and publish a listing. New Subang Cafe listings require approval; Sample Bakery is already approved.
4. Switch to Student → Login → **Student demo**. Browse the compact deal list, search, or select **View all** for category/price/pickup filters.
5. Open a deal → **Reserve for Pickup** → **Continue to Checkout** → **Reserve — Pay at Pickup**. Note the six-digit code.
6. Switch to Vendor → **Orders**, enter the code and select **Mark Collected**.
7. Review the updated Student reservation or Admin oversight. Use **Reset demo** above the frame before the next presentation.

Student Profile and Vendor Dashboard link to their feature directories: favourites, cart, pickup pass, reviews, settings, help, business profile, pickup verification, notifications and insights. Admin's overview links to support, role, service-area and audit screens. Registration, password reset and location screens are front-end simulations. Review submission requires a collected sample reservation. Support requests are recorded locally; nothing is sent.

## Design fidelity and assets

The original wide-layout redesign has been replaced. The frames, section order, compact cards, colours, button treatment, navigation and visible copy follow the supplied screenshots.

**An exact pixel/asset match is not claimed.** The original logo and photography were not supplied as individual files. The current logo, food photos, avatar and illustrated map are generated recreations; see [asset provenance](src/assets/README.md). Original PNG/JPG/SVG exports are needed to replace these with the exact Figma assets. Reference boards also depict different sample states; live demo stock and order states can differ after interactions.

## Optional Node.js tools

Only developers rebuilding the self-contained presentation or running tests need Node.js 20+:

```sh
npm start
npm test
npm run check
npm run build
```

On Windows PowerShell, use `npm.cmd` instead of `npm` if `npm.ps1` is blocked. The server opens on port 3000. The build regenerates `FoodieNoms-demo.html` and `dist/`. Dependencies do not need installing.

## Demo limits and future app packaging

All roles share local sample data in the same browser. Data is not shared across PCs/devices; storage availability for local files depends on the browser. Reset clears it. Roles are not authentication or authorization. Prices, impact totals, notification content and maps are illustrative. No real payment, GPS, email, camera QR scanning, backend or production account is connected. Do not enter private information.

The static `dist/` website can later be packaged with Capacitor for Android and iOS; that conversion is not part of this revision. A separate existing [Flutter/Dart Android version](mobile/README.md) remains in `mobile/` and has not been changed to match this HTML revision.

## Validation

- Four reservation/stock/collection unit tests.
- Browser-tested Admin approval → Vendor publication → Student search/reservation → code-verified pickup, persistence, module navigation and 320/390px layouts.
- The self-contained HTML was loaded over HTTP and its reservation flow verified after disabling networking, with no additional HTTP asset requests.
- Direct `file:///` navigation in the managed cloud browser is blocked by its administrator policy, so a Windows double-click launch has not been directly verified here. No ES modules or fetch calls are required by the presentation file.
