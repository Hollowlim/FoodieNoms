# FoodieNoms — client demo

A responsive, interactive sample application based on the supplied FoodieNoms screenshots. Student and Vendor layouts adapt to mobile; Admin includes a desktop sidebar. Built with plain JavaScript and CSS, without dependency installation.

## Run

Requires Node.js 20 or newer.

```sh
cd FoodieNoms
npm start
```

Open `http://localhost:3000` in Chrome or Edge on your PC. Set `PORT` to use another port.

**VS Code:** Open the repository root folder containing `package.json` (not `mobile/`). After installing Node.js, restart VS Code. You can run the commands above in **Terminal → New Terminal**, or select **FoodieNoms: open website demo** in **Run and Debug** and press **F5** if Chrome is installed. If a server is already running on port 3000, open it in your browser directly.

For a presentation, use the same browser throughout so Student, Vendor and Admin share the demo data. Use the browser's device toolbar to show the mobile layout.

## Static website build

```sh
npm run build
```

This produces `dist/`, containing only the website files. It can be served by a static hosting provider and will also work under a path such as `/FoodieNoms/`. Open it through an HTTP server, not by double-clicking the HTML file.

## Existing Flutter application

The separate **Flutter/Dart Android app** remains in [mobile/](mobile/). See [its setup and APK instructions](mobile/README.md). This website is the quickest first-presentation route; the Flutter source is retained for mobile development.

```sh
npm test
npm run check
```

## Suggested client presentation

1. Select **Administrator**, open **Vendors**, and approve **Subang Cafe**.
2. **Switch role** → **Vendor** → **Add Surplus Food**, and publish a deal.
3. **Switch role** → **Student**, browse/search/filter deals and open the new listing.
4. Reserve a portion, confirm pay-at-pickup and note the six-digit pickup code.
5. **Switch role** → **Vendor** → **Reservations**, enter that code and confirm collection.
6. View the updated reservation in Student and Admin. Reports and Activity Log reflect the changes.
7. Use **Reset demo** before the next presentation.

Additional interactions include favourites, cancellation with stock restoration, listing edits/moderation, profile editing and an illustrative nearby map.

## Demo boundaries

- All roles share sample data stored in this browser's localStorage. Different browsers/devices do not share data. Reset clears the sample state.
- Role selection is demonstration navigation, not authentication or authorization. Do not use real personal information or deploy this as a production service.
- No backend, Supabase, live GPS/map tiles, payment processing, camera/QR scanner, email, or push notifications are connected. Pickup uses a sample numeric code, not a QR image.
- Food artwork uses emoji; the original logo and food photography were not supplied as standalone assets. Fonts use Google Fonts when available, with system fallbacks.
- This is a browser application, not a Flutter/Android package. The supplied PDF describes a future production architecture; its full feature list is outside this first-demo scope.
- Browser persistence is convenient for presentation only. Stock and pickup checks are local demo logic, not production concurrency or security guarantees.

## Files

- `src/app.js`: screens, navigation, events and demo persistence
- `src/store.js`: sample data and reservation transitions
- `src/style.css`: theme and responsive layouts
- `server.js`: small development HTTP server
- `scripts/build.js`: creates the static `dist/` website
- `.vscode/`: optional F5 launch configuration
- `tests/store.test.js`: reservation, stock and collection tests
