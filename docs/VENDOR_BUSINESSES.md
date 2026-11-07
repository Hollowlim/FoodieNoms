# Vendor approval and shop locations

Admin navigation contains Overview, Vendors, Administrators and Profile. The overview shows live vendor counts. Vendors can be searched and filtered by Pending, Approved or Revoked. Approval and revocation require confirmation; revocation also requires a reason. Reapproval restores selling access.

Vendors can prepare their business profile while waiting for approval. Open **Set up shop name & location** on the waiting screen, or **Profile → Edit business & location** after approval. Save a shop name, full pickup address and an explicitly selected map pin. Tapping the map or entering coordinates selects the point; simply opening the map never saves its center. The optional current-location button requests a foreground location fix and still requires Save.

The coordinate check covers the approximate Subang Jaya/USJ pilot map box: latitude 2.98–3.12 and longitude 101.54–101.64. This is a pilot-area bound, not address verification or automatic geocoding.

New food listings use the saved business name, address and coordinates. Customers see approved, configured shops on the Map tab, can tap a pin to browse that shop's available food, and can open directions to the saved point. Reservations retain their original pickup address and coordinates when a business or listing changes later.

Revocation updates the private account and public business approval together. The customer catalogue and map remove the vendor, and database rules reject new listings, reservations and vendor fulfillment changes. Existing orders remain stored; customers can still cancel eligible reservations. The vendor sees the reason and can edit business details while waiting for reapproval.

Private roles and approval history stay in `users/{uid}`. Public shop data lives in `vendorBusinesses/{uid}` and contains only shop identity, address, coordinates, configuration/approval state and update time. It never contains passwords or login email addresses. Existing vendors receive unconfigured records with their prior approval state; no shop coordinates are inferred.

Validation uses the complete Flutter test suite, Firestore emulator rules tests, and `tool/run_client_emulator_check.sh`. The client journey covers setup, approval, publication, map visibility, coordinate snapshots, revocation, customer cancellation and reapproval without writing test orders to the live database.

## Customer live-location range

Customer maps use the same approximate pilot box as shop validation. A valid device fix outside it remains only in session memory and shows **Outside service area**. The map stays over Subang Jaya, draws the pilot outline and omits the outside device marker. Visible foreground maps continue checking location so entering the area restores the real blue marker. Customers can switch to **Browse Subang Jaya** manually. This location status does not introduce a GPS requirement for pickup reservations.

## Place search and pin editing

Vendors can choose Search or Coordinates. Search submits the entered shop, street or landmark text to the Photon geocoder with the fixed pilot bounding box. It does not send the device's GPS fix or account details, and typing alone does not send a request. Results use OpenStreetMap data and are filtered to the service area. The selected address remains editable; a vendor can drag the pin, tap another point, or paste a latitude/longitude pair before pressing Save business profile.

The shared search service spaces requests by at least one second, combines duplicate requests, and keeps up to 30 successful query results in memory for 20 minutes. Photon’s public demonstration service permits reasonable project use and can throttle requests or become unavailable. Coordinate entry and manual pin placement remain available when search fails. A deployment can select another compatible HTTPS Photon endpoint with PLACE_SEARCH_URL. No paid geocoding account or Firebase backend deployment is required for this UI change.

Provider documentation: https://github.com/komoot/photon and https://github.com/komoot/photon/blob/master/docs/api-v1.md . The public demo’s availability and fair-use terms are documented there. Map and search attribution remains visible in the editor.
