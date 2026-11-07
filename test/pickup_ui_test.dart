import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:foodienoms/firebase/pickup_ui.dart';

Map<String, dynamic> order(String status) => {
      'code': 'FN-0123456789ABCDEF0123',
      'status': status,
      'title': 'Lunch box',
      'vendorName': 'Test Cafe',
      'quantity': 2,
      'pickupStart': 1800000000000,
      'pickupEnd': 1800003600000,
      'address': 'Subang Jaya',
      'totalCents': 1600,
    };
void main() {
  test('scanner accepts only pickup codes, never URLs or arbitrary QR content',
      () {
    expect(pickupCodeFromQr(' fn-0123456789abcdef0123 '),
        'FN-0123456789ABCDEF0123');
    for (final value in [
      '',
      'https://example.com/FN-0123456789ABCDEF0123',
      'FN-123',
      '{"code":"FN-0123456789ABCDEF0123"}'
    ]) {
      expect(pickupCodeFromQr(value), isNull);
    }
  });
  testWidgets(
      'pickup QR is removed when a reservation is cancelled or collected',
      (tester) async {
    for (final status in ['reserved', 'cancelled', 'collected']) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: PickupPass(
                      order: order(status), nowMs: 1800000000000)))));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView),
          status == 'reserved' ? findsOneWidget : findsNothing);
      if (status == 'reserved') {
        expect(find.text('FN-0123456789ABCDEF0123'), findsOneWidget);
      }
      expect(find.text('Total'), findsOneWidget);
    }
  });
  testWidgets('review shows total and savings before creating a reservation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReservationReview(listing: {
      ...order('reserved'),
      'priceCents': 800,
      'originalPriceCents': 2000,
      'dietary': 'Contains soy'
    }, quantity: 2))));
    expect(find.text('Total: RM 16.00'), findsOneWidget);
    expect(find.text('You save: RM 24.00'), findsOneWidget);
    expect(find.text('Confirm reservation'), findsOneWidget);
  });
}
