/// Shared order states for the existing single-listing reservation flow.
bool isOpenReservation(Map<String, dynamic> order) =>
    order['status'] == 'reserved' || order['status'] == 'ready';

String reservationStatusLabel(String status) => switch (status) {
      'reserved' => 'Reserved',
      'ready' => 'Ready for pickup',
      'collected' => 'Collected',
      'cancelled' => 'Cancelled',
      'noshow' => 'Not collected',
      _ => 'Unknown status',
    };

bool reservationMatchesTab(Map<String, dynamic> order, String tab) =>
    tab == 'reserved' ? isOpenReservation(order) : order['status'] == tab;

bool hasUsablePickupPass(Map<String, dynamic> order, int now,
        {int graceMs = 15 * 60 * 1000}) =>
    isOpenReservation(order) && now <= (order['pickupEnd'] as int) + graceMs;

bool canMarkReservationReady(Map<String, dynamic> order, int now,
        {int graceMs = 15 * 60 * 1000}) =>
    order['status'] == 'reserved' &&
    now <= (order['pickupEnd'] as int) + graceMs;

bool canMarkReservationNoShow(Map<String, dynamic> order, int now,
        {int graceMs = 15 * 60 * 1000}) =>
    isOpenReservation(order) && now > (order['pickupEnd'] as int) + graceMs;

String? shortPickupCode(Map<String, dynamic> order) {
  final code = order['pickupCode'];
  return code is String && RegExp(r'^\d{4}$').hasMatch(code) ? code : null;
}
