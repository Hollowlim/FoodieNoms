import 'package:flutter/material.dart';

/// The prototype treats one collected listing item as one saved meal.
/// This is an item count, not an estimate of weight or nutritional portions.
int collectedMealsSaved(Iterable<Map<String, dynamic>> reservations) =>
    reservations.fold(0, (total, reservation) {
      final quantity = reservation['quantity'];
      return reservation['status'] == 'collected' &&
              quantity is int &&
              quantity > 0
          ? total + quantity
          : total;
    });

class MealsSavedSection extends StatelessWidget {
  const MealsSavedSection({super.key, this.reservations});

  /// Omit only for an empty, offline preview. Live profiles supply their own
  /// authenticated reservation history, including older completed pickups.
  final Stream<Iterable<Map<String, dynamic>>>? reservations;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<Iterable<Map<String, dynamic>>>(
          key: ObjectKey(reservations),
          stream: reservations,
          builder: (context, snapshot) {
            final loading = reservations != null &&
                !snapshot.hasData &&
                snapshot.connectionState != ConnectionState.done;
            final total = collectedMealsSaved(snapshot.data ?? const []);
            final unavailable = snapshot.hasError;
            final value = unavailable || loading
                ? '—'
                : '$total ${total == 1 ? 'meal' : 'meals'}';
            final explanation = unavailable
                ? 'Couldn’t load your completed pickups. Reopen your profile to try again.'
                : loading
                    ? 'Loading your completed pickups…'
                    : 'Completed pickups only. Each collected item counts as one saved meal.';
            const green = Color(0xFF205F45);
            return Semantics(
                liveRegion: true,
                child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF0F6ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD7E6D4))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.eco_outlined, color: green, size: 21),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text('Meals Saved',
                                    style: TextStyle(color: green))),
                          ]),
                          const SizedBox(height: 10),
                          Text(value,
                              style: const TextStyle(
                                  color: green,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(explanation,
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12)),
                        ])));
          });
}
