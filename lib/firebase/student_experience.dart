import 'package:flutter/material.dart';
export 'order_state.dart';
import 'package:url_launcher/url_launcher.dart';

int remainingReservationAllowance(int held, {int limit = 5}) =>
    (limit - held).clamp(0, limit);

String friendlyPickupWindow(Map<String, dynamic> data, {DateTime? now}) {
  final start = DateTime.fromMillisecondsSinceEpoch(data['pickupStart'] as int);
  final end = DateTime.fromMillisecondsSinceEpoch(data['pickupEnd'] as int);
  final today = now ?? DateTime.now();
  final date = DateTime(today.year, today.month, today.day);
  String day(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    if (d == date) return 'Today';
    if (d == DateTime(date.year, date.month, date.day + 1)) return 'Tomorrow';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${value.day} ${months[value.month - 1]}${value.year == today.year ? '' : ' ${value.year}'}';
  }

  String time(DateTime value) =>
      '${value.hour % 12 == 0 ? 12 : value.hour % 12}:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? 'AM' : 'PM'}';
  final sameDay = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  return '${day(start)}, ${time(start)} – ${sameDay ? '' : '${day(end)}, '}${time(end)}';
}

class DirectionsButton extends StatelessWidget {
  const DirectionsButton(
      {super.key,
      required this.address,
      this.latitude,
      this.longitude,
      this.openUri});
  final String address;
  final double? latitude, longitude;
  final Future<bool> Function(Uri)? openUri;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.directions_outlined),
        label: const Text('Open directions'),
        onPressed: address.trim().isEmpty
            ? null
            : () async {
                final hasPin = latitude != null &&
                    longitude != null &&
                    latitude!.isFinite &&
                    longitude!.isFinite;
                final uri = Uri.https('maps.apple.com', '/', {
                  'daddr': hasPin ? '$latitude,$longitude' : address.trim(),
                });
                try {
                  final opened = await (openUri?.call(uri) ??
                      launchUrl(uri, mode: LaunchMode.externalApplication));
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Unable to open Maps. Use the pickup address above.')));
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Unable to open Maps. Use the pickup address above.')));
                  }
                }
              },
      );
}

class StudentEmptyState extends StatelessWidget {
  const StudentEmptyState(
      {super.key,
      required this.title,
      required this.message,
      this.actionLabel,
      this.onAction});
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.restaurant_outlined,
                size: 44, color: Color(0xFF205F45)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null && actionLabel != null)
              Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FilledButton(
                      onPressed: onAction, child: Text(actionLabel!))),
          ])));
}

class OrderStatusTabs extends StatelessWidget {
  const OrderStatusTabs(
      {super.key,
      required this.selected,
      required this.onSelected,
      this.upcomingLabel = 'Upcoming'});
  final String selected;
  final String upcomingLabel;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(
              value: 'reserved',
              label: Text(upcomingLabel),
              icon: Icon(Icons.qr_code)),
          ButtonSegment(value: 'collected', label: Text('Collected')),
          ButtonSegment(value: 'cancelled', label: Text('Cancelled')),
          ButtonSegment(value: 'noshow', label: Text('Not collected'))
        ],
        selected: {selected},
        onSelectionChanged: (value) => onSelected(value.single),
      ));
}
