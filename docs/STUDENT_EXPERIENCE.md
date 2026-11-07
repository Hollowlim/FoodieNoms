# Student flow improvements

- Orders: Upcoming, Collected and Cancelled status tabs; upcoming reservations sort by pickup start and retain a direct pickup-QR action. Reserved orders whose window ended remain visible with a warning so they are not silently lost. Empty orders link back to food browsing.
- Pickup details: local Today/Tomorrow/date labels, including overnight windows; directions link from food details and pickup passes. Directions open Apple Maps with the exact pickup address on user action; failures leave the address visible.
- Allowance: the food-detail quantity controls subscribe to the signed-in customer's listing claim document. They show the remaining portion of the five-item allowance, disable excess increments and reservation submission, and refresh after claim changes. Server rules still enforce the limit.
- Discovery: sold-out and ended listings are excluded for customers. Empty search/category results can clear both the filter state and visible search text. An empty catalogue explains the lack of live food while preserving the existing clearly labelled preview examples.

Validation: Flutter analysis, 31 Flutter tests (including local-date boundaries, directions encoding/failure, allowance bounds, order tabs, browse action and clearing empty preview filters), and iOS simulator build. No Firestore-rule changes are required.
