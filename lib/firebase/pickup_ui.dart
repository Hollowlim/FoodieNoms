import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'service.dart';
import 'student_ui.dart';
import 'student_experience.dart';

String? pickupCodeFromQr(String value) {
  final code = value.trim().toUpperCase();
  return RegExp(r'^FN-[A-F0-9]{20}$').hasMatch(code) ? code : null;
}

class PickupPass extends StatelessWidget {
  const PickupPass({super.key, required this.order, this.nowMs});
  final Map<String, dynamic> order;
  final int? nowMs;
  Widget row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 20),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ]),
      );
  @override
  Widget build(BuildContext context) {
    final reserved = isOpenReservation(order);
    final usable = hasUsablePickupPass(
        order, nowMs ?? DateTime.now().millisecondsSinceEpoch);
    final expired = reserved && !usable;
    final ready = order['status'] == 'ready';
    final cancelled = order['status'] == 'cancelled';
    final noShow = order['status'] == 'noshow';
    final code = order['code'] as String;
    final shortCode = shortPickupCode(order);
    return Card(
        color: Colors.white,
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      expired
                          ? 'Pickup window ended'
                          : reservationStatusLabel(order['status'] as String),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: cancelled || noShow
                              ? Colors.red.shade700
                              : studentGreen)),
                  const SizedBox(height: 8),
                  Text(
                      expired
                          ? 'Your pickup time and grace period have ended. Contact the vendor about this reservation.'
                          : reserved
                              ? ready
                                  ? 'Your food is ready. Show your QR or tell the vendor your pickup code.'
                                  : 'Your reservation is confirmed. Show your QR or pickup code when collecting.'
                              : cancelled
                                  ? 'This reservation was cancelled.'
                                  : noShow
                                      ? 'The vendor marked this pickup as not collected. This code is no longer valid.'
                                      : 'Your food has been collected. This code cannot be reused.',
                      textAlign: TextAlign.center),
                  if (usable) ...[
                    if (shortCode != null) ...[
                      const SizedBox(height: 18),
                      const Text('Pickup code', textAlign: TextAlign.center),
                      SelectableText(shortCode,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 7,
                              color: studentGreen)),
                    ],
                    const SizedBox(height: 20),
                    Center(
                        child: Semantics(
                            label: 'Pickup QR code for $code',
                            image: true,
                            child: SizedBox(
                                width: 230,
                                height: 230,
                                child: QrImageView(
                                    data: code,
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.all(16))))),
                    const SizedBox(height: 12),
                    SelectableText(code,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                  const Divider(height: 32),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Text(order['title'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17))),
                    const SizedBox(width: 12),
                    Text('Qty ${order['quantity']}')
                  ]),
                  const SizedBox(height: 10),
                  row('Vendor', order['vendorName'] as String),
                  row('Pickup', friendlyPickupWindow(order)),
                  row('Address', order['address'] as String),
                  DirectionsButton(
                      address: order['address'] as String,
                      latitude: (order['latitude'] as num?)?.toDouble(),
                      longitude: (order['longitude'] as num?)?.toDouble()),
                  row('Total', '${money(order['totalCents'])} · Unpaid'),
                ])));
  }
}

class VendorPickupActions extends StatelessWidget {
  const VendorPickupActions(
      {super.key,
      required this.order,
      required this.onReady,
      required this.onNoShow,
      required this.onCollect,
      this.busy = false,
      this.approved = true,
      this.nowMs});
  final Map<String, dynamic> order;
  final VoidCallback onReady, onNoShow, onCollect;
  final bool busy, approved;
  final int? nowMs;
  @override
  Widget build(BuildContext context) {
    if (!isOpenReservation(order)) return const SizedBox.shrink();
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final missed = canMarkReservationNoShow(order, now);
    final canCollect =
        now >= (order['pickupStart'] as int) - pickupGraceMs && !missed;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 6, children: [
        if (canMarkReservationReady(order, now))
          OutlinedButton.icon(
              key: const ValueKey('mark-pickup-ready'),
              onPressed: busy || !approved ? null : onReady,
              icon: const Icon(Icons.restaurant_outlined, size: 19),
              label: const Text('Mark ready')),
        if (!missed)
          FilledButton.icon(
              onPressed: busy || !approved || !canCollect ? null : onCollect,
              icon: const Icon(Icons.check_circle_outline, size: 19),
              label: const Text('Mark collected')),
        if (missed)
          OutlinedButton.icon(
              key: const ValueKey('mark-pickup-noshow'),
              onPressed: busy || !approved ? null : onNoShow,
              icon: const Icon(Icons.person_off_outlined, size: 19),
              label: const Text('Not collected')),
      ]),
      if (missed)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'Pickup time and its grace period have ended. Mark not collected, or cancel to return the reserved stock.',
                style: TextStyle(fontSize: 12, color: Colors.black54))),
    ]);
  }
}

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen(
      {super.key,
      required this.service,
      required this.reservationId,
      this.confirmed = false});
  final FoodieService service;
  final String reservationId;
  final bool confirmed;
  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late final stream = widget.service.db
      .collection('reservations')
      .doc(widget.reservationId)
      .snapshots();
  Timer? timer;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> cancel() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Cancel reservation?'),
                content: const Text(
                    'Your reserved items will be returned to the listing.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Keep reservation')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Cancel reservation'))
                ]));
    if (yes != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service
          .call('cancelReservation', {'reservationId': widget.reservationId});
    } catch (e) {
      if (mounted) setState(() => error = firebaseMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                widget.confirmed ? 'Reservation confirmed' : 'Order details')),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(firebaseMessage(snapshot.error!)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final order = snapshot.data!.data();
              if (order == null) {
                return const Center(child: Text('Reservation not found.'));
              }
              final canCancel = isOpenReservation(order) &&
                  DateTime.now().millisecondsSinceEpoch <
                      (order['pickupEnd'] as int);
              return SafeArea(
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                if (widget.confirmed) ...[
                  const Icon(Icons.check_circle, color: studentGreen, size: 54),
                  const SizedBox(height: 12),
                  const Text('Reservation confirmed',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20)
                ],
                PickupPass(order: order),
                const SizedBox(height: 16),
                if (canCancel) ...[
                  OutlinedButton(
                      onPressed: busy ? null : cancel,
                      child: Text(busy ? 'Cancelling…' : 'Cancel reservation')),
                  const Text('You can cancel until the pickup window ends.',
                      textAlign: TextAlign.center)
                ],
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                if (widget.confirmed)
                  Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'))),
              ]));
            }),
      );
}

class PickupScannerScreen extends StatefulWidget {
  const PickupScannerScreen({super.key});
  @override
  State<PickupScannerScreen> createState() => _PickupScannerScreenState();
}

class _PickupScannerScreenState extends State<PickupScannerScreen> {
  final controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates);
  bool finished = false;
  String? message;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan pickup QR')),
        body: Column(children: [
          Expanded(
              child: MobileScanner(
                  controller: controller,
                  errorBuilder: (context, error) => Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.no_photography_outlined, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                                'Camera unavailable or permission denied. You can enter the pickup code instead.',
                                textAlign: TextAlign.center),
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Enter code manually'))
                          ]))),
                  onDetect: (capture) {
                    if (finished) return;
                    for (final barcode in capture.barcodes) {
                      final code = pickupCodeFromQr(barcode.rawValue ?? '');
                      if (code != null) {
                        finished = true;
                        Navigator.pop(context, code);
                        return;
                      }
                    }
                    if (message == null) {
                      setState(() =>
                          message = 'This is not a FoodieNoms pickup QR.');
                    }
                  })),
          SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Text(
                        message ??
                            'Point the camera at the customer’s pickup QR code.',
                        textAlign: TextAlign.center),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Type pickup code instead'))
                  ]))),
        ]),
      );
}

class ReservationReview extends StatelessWidget {
  const ReservationReview(
      {super.key, required this.listing, required this.quantity});
  final Map<String, dynamic> listing;
  final int quantity;
  @override
  Widget build(BuildContext context) => SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Check your reservation',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                Text(
                    '${listing['title']} · $quantity × ${money(listing['priceCents'])}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 12),
                Text('Vendor: ${listing['vendorName']}'),
                const SizedBox(height: 8),
                Text('Pickup: ${friendlyPickupWindow(listing)}'),
                const SizedBox(height: 8),
                Text('Address: ${listing['address']}'),
                const SizedBox(height: 8),
                Text('Dietary: ${listing['dietary']}'),
                const Divider(height: 32),
                Text(
                    'Total: ${money((listing['priceCents'] as int) * quantity)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 20)),
                const SizedBox(height: 8),
                Text(
                    'You save: ${money(((listing['originalPriceCents'] as int) - (listing['priceCents'] as int)) * quantity)}'),
                const SizedBox(height: 20),
                const Text(
                    'No payment is taken in the app. You can cancel from Orders until the pickup window ends.'),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm reservation')),
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Go back')),
              ])));
}
