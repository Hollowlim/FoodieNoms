# FoodieNoms — client demo

A responsive, interactive sample application based on the supplied FoodieNoms screenshots. Student and Vendor layouts adapt to mobile; Admin includes a desktop sidebar. Built with plain JavaScript and CSS, without dependency installation.

## Run

Requires Node.js 20 or newer.

```sh
cd /workspace/FoodieNoms
npm start
```

Open the server on port 3000 in your local development browser. Set `PORT` to use another port.

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
- `tests/store.test.js`: reservation, stock and collection tests
