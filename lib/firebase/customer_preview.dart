import 'package:flutter/material.dart';
import 'student_ui.dart';
import 'reference_assets.dart';

const _green = Color(0xFF153D29);

class SampleFood {
  const SampleFood(this.name, this.vendor, this.category, this.emoji,
      this.price, this.originalPrice, this.description, this.pickup);
  final String name, vendor, category, emoji, description, pickup;
  final int price, originalPrice;
  String get formattedPrice => 'RM ${(price / 100).toStringAsFixed(2)}';
  String get formattedOriginal =>
      'RM ${(originalPrice / 100).toStringAsFixed(2)}';
}

const sampleFoods = [
  SampleFood(
      'Bakery Surprise Bag',
      'Sample Bakery',
      'Bakery',
      '🥐',
      800,
      2000,
      'A surprise selection of breads and pastries. A simple way to give good food a second chance.',
      '5:00 PM – 7:00 PM'),
  SampleFood(
      'Cafe Lunch Box',
      'Sample Cafe',
      'Meals',
      '🍱',
      990,
      1800,
      'A filling lunch box with a main dish and sides. Actual meals will depend on what each vendor publishes.',
      '4:00 PM – 6:00 PM'),
  SampleFood(
      'Pastry Selection',
      'Sample Patisserie',
      'Pastries',
      '🧁',
      650,
      1500,
      'A little box of sweet favourites, shown here as an example of a surplus food deal.',
      '6:00 PM – 8:00 PM'),
];

/// Local presentation examples only. This screen has no database or order API.
class CustomerPreview extends StatelessWidget {
  const CustomerPreview({super.key, this.search = '', this.category = 'All'});
  final String search, category;
  @override
  Widget build(BuildContext context) {
    final matches = sampleFoods
        .where((food) =>
            (category == 'All' || food.category == category) &&
            '${food.name} ${food.vendor} ${food.category}'
                .toLowerCase()
                .contains(search.toLowerCase()))
        .toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text("Today's rescue deals",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: studentDark)),
          const SizedBox(height: 8),
          const Text('Sample deals · Preview only until vendors publish food',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 14),
          if (matches.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                    'No preview examples match. Try another search or category.')),
          ...matches.map((food) => StudentDealTile(
              title: food.name,
              price: food.formattedPrice,
              original: food.formattedOriginal,
              subtitle: 'Pickup ${food.pickup}',
              emoji: food.emoji,
              preview: true,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => SampleFoodDetails(food: food))))),
          const SizedBox(height: 12),
          const Text('Save food. Save money.',
              style:
                  TextStyle(color: studentGreen, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Tap a sample to explore. Real listings replace these examples automatically.',
              style: TextStyle(color: Colors.black54, height: 1.5)),
        ]);
  }
}

class SampleFoodDetails extends StatelessWidget {
  const SampleFoodDetails({super.key, required this.food});
  final SampleFood food;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Food preview')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                  height: 210,
                  child: ReferenceFoodPhoto(
                      index: referencePhotoForEmoji(food.emoji)))),
          const SizedBox(height: 8),
          const Text('Example food photography',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 24),
          const Text('PREVIEW ONLY',
              style: TextStyle(color: _green, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(food.name,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: _green)),
          Text(food.vendor),
          const SizedBox(height: 20),
          Text('${food.formattedPrice} · Example price',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(food.description, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 20),
          Text('Example pickup window: ${food.pickup}'),
          const SizedBox(height: 20),
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'This is a design example, not a live listing. It cannot be reserved. A real listing will show the vendor’s pickup date, address, stock and dietary information.'))),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Explore')),
        ])),
      );
}
