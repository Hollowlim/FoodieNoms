# Pickup flow matched to teammate video

Reference: user-supplied tmfn.mp4 (154.7 seconds). Video captions are demonstration context, not setup instructions.

Implemented the food-detail photograph, reservation review with quantity/total/savings/pickup information, confirmation pickup pass, order-details pickup pass, cancellation states, vendor camera scanner and manual pickup-code fallback, and four bundled listing-photo presets.

The QR encodes only the existing FN- plus 20 hexadecimal characters. Scanning never opens URLs or trusts embedded order details. The scanned value is sent through the existing collectReservation transaction and Firestore rules, which check ownership, approval, order status and pickup timing. Cancelled and collected orders do not render a QR. Existing orders keep their price and pickup snapshots. Reservations reject a price change after review and ask for another review.

Camera permission is requested when opening the scanner. The scanner pauses with the app lifecycle, stops on route disposal and reports camera/permission failures with manual entry available. On the iPhone simulator, use manual entry; physical camera capture requires device validation.

Verification: Flutter analysis, 25 Flutter tests, three screen-render checks, and decoding the rendered QR with Apple Vision. The latter confirms the exact reservation-code payload and visual readability. The iOS simulator build is also checked. No Firebase-rule changes are required for the QR UI; existing live rules handle it.
