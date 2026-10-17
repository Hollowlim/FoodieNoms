# FoodieNoms — fresh iPhone and iPad demo

A new, standalone demo made with **HTML, CSS and JavaScript**. Open this `fresh-webapp` folder to work on the new version. It does not depend on the older website or Flutter project.

**No Node.js, npm, Flutter, terminal commands or paid extension are needed to view it.**

## First time in VS Code on Windows

1. Extract the ZIP first if you downloaded one. Do not work inside the ZIP.
2. Choose **File → Open Folder** in VS Code. Select **`fresh-webapp`**, the folder containing this README and `index.html`.
3. If VS Code shows **Restricted Mode**, trust this FoodieNoms folder only if you trust the downloaded project.
4. Open **Extensions** with **Ctrl + Shift + X**. Install **Live Server** by **Ritwick Dey** (`ritwickdey.LiveServer`). VS Code also recommends it for this folder.
5. In the left Explorer, right-click **`index.html` → Open with Live Server**.
6. View the app in Chrome or Edge. The address normally starts with **`http://127.0.0.1:5500`**.

Keep VS Code and Live Server running while presenting. If you see `file:///` or “Forbidden. File does not reside within a trusted folder,” close that internal preview and follow steps 3–6.

### Preview inside VS Code

After Live Server starts, copy the preview page's `http://.../preview.html` address. Press **Ctrl + Shift + P → Simple Browser: Show** and paste it to keep the frame beside your source code. Use the HTTP address, not `file:///`. You can also leave Chrome/Edge beside VS Code; Live Server refreshes after saved changes.

## See an iPhone or iPad frame while coding

Right-click **`preview.html` → Open with Live Server**. The preview page includes an **iPhone (393 × 852)** and **iPad (820 × 1180)** selector and a rotation control. Open the preview beside VS Code and save your code to see changes through Live Server.

This is a device-sized browser frame, not an iOS simulator. It checks the responsive layout; Safari and a real device can differ. To use the app without the frame, open `index.html`.

Alternatively, in Chrome or Edge press **F12**, then **Ctrl + Shift + M** to toggle the browser's device toolbar. Select an iPhone/iPad preset or enter a custom viewport size.

## What to demonstrate

- **Student:** discover food, search/filter, see details, reserve for pickup, and show a pickup code.
- **Vendor:** use the seeded Subang Cafe business, create/edit surplus listings after approval, and confirm collection.
- **Admin:** approve vendors and manage the sample platform.

On the welcome screen, choose **Already have an account? Log in**. The shared **Email or username** login opens the matching Student, Vendor or Admin portal. No special admin URL is needed; the older `?admin=1` link still opens the same login form. This is a frontend login for presentation, not secure server authentication.

Use `student@example.com` or `vendor@example.com` with any password of at least six characters for the corresponding sample portal. After signup, the email and Student/Vendor role are remembered in this browser; passwords are not saved or checked for those local accounts. An unrecognised email follows the Student/Vendor welcome choice, or defaults to Student through the common login.

Admin login:

```text
Username: admin123
Password: admin@123
```

Choose **Sign up as Student** or **Sign up as Vendor** for a local demo account. Use sample names and email addresses. Passwords entered for demo accounts are not saved.

For a connected presentation, use the **same browser and the same address** for all roles:

1. Sign up as Vendor (or use sample Vendor login) to view the seeded pending Subang Cafe business, then log out.
2. Log in as admin and approve Subang Cafe, then log out.
3. Log in as the vendor and publish a food listing.
4. Log in as a student and reserve the listing.
5. Log in as the vendor and confirm the student's collection with the pickup code.

The app stores demo state in that browser's local storage. Another phone, another browser, a private window or a different server address has separate data. This version has no backend and does not synchronize accounts or orders between devices. Login checks are for demonstration; they do not secure real user data. Payments, map locations and notifications are simulated.

## Open it on your iPhone or iPad

For a quick website preview, your PC and phone can use the same Wi-Fi:

1. Start Live Server on the PC.
2. Find the PC's local IPv4 address in **Windows Settings → Network & internet → your connection → Properties**.
3. In iPhone/iPad Safari, open `http://YOUR-PC-IP:5500/index.html`, for example `http://192.168.1.20:5500/index.html`.
4. If Windows Firewall asks, allow VS Code/Live Server on your trusted **Private** network. If the phone cannot connect, check that both devices use the same Wi-Fi and that network isolation is disabled.

`localhost` and `127.0.0.1` on the phone refer to the phone, not your PC. A LAN `http://` address is useful for checking the website layout, but it does not provide this demo's secure PWA installation and offline support.

### Add it to the Home Screen

Publish the contents of this folder on an **HTTPS static website host** first. The project has no hosted link until you deploy it. Upload all files together, including `assets`, `manifest.webmanifest` and `sw.js`; no build command is required. Paths support either a domain root or a project subfolder.

On the iPhone/iPad:

1. Open the hosted **HTTPS** app link in **Safari**.
2. Tap **Share → Add to Home Screen**. Enable **Open as Web App** if that switch is shown, then tap **Add**.
3. Open the FoodieNoms icon from the Home Screen.

The Home Screen version is a **web app (PWA)**, not a native App Store/TestFlight iOS application. It does not require a Mac or an Apple Developer membership. After a successful online visit and service-worker installation, the downloaded app shell can reopen offline; demo data remains on that device. Browsers may clear local storage/cache, so do not use this sample for records you must keep.

## Files to edit

| File | Purpose |
| --- | --- |
| `index.html` | App entry point and iOS/PWA metadata |
| `styles.css` | Responsive screen layouts and visual styling |
| `app.js` | Screens and interactions |
| `data.js` | Demo state and local persistence |
| `assets/` | Local illustrations, images and icons |
| `preview.html`, `preview.css`, `preview.js` | Desktop device-frame preview |
| `manifest.webmanifest`, `sw.js` | Home Screen metadata and offline app-shell caching |

The imagery is recreated reference artwork, not original Figma exports. Replace the files in `assets/` with approved original assets when they are available.

## Publishing updates and optional development checks

For a published PWA update, bump `VERSION` in `sw.js` and deploy all changed files together. A new service worker waits while an older app window is open; finish the current reservation, close all FoodieNoms windows and reopen the app to activate the update. The worker does not reload an active reservation. Service-worker registration is skipped on `localhost` and `127.0.0.1`, so the usual Live Server address shows your latest saved files. Live Server refresh behavior is separate from PWA updates.

Developers who already have Node.js can optionally run `node --test tests/data.test.cjs`. This command is for automated checks only; Node.js is not required to run the demo with Live Server.

## Validation evidence

See [the verification report](docs/verification.md) and the captured [iPhone](docs/screenshots/iphone-home.png), [iPad](docs/screenshots/ipad-home.png), and [device preview](docs/screenshots/device-preview.png). Browser checks are not physical iOS-device tests. Artwork provenance is recorded in [assets/README.md](assets/README.md).
