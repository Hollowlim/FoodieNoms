import 'dart:math' as math;
import 'package:flutter/material.dart';

const referenceFoodSheet = 'assets/reference/food_photography_sheet.png';
const referenceMap = 'assets/reference/map_illustration.png';

/// Displays one original quadrant of the supplied photography sheet.
/// The source PNG is kept intact; cover cropping happens only during layout.
class ReferenceFoodPhoto extends StatelessWidget {
  const ReferenceFoodPhoto(
      {super.key,
      required this.index,
      this.label = 'Example food photography'});
  final int index;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: LayoutBuilder(builder: (context, bounds) {
        final scale = math.max(bounds.maxWidth / 768, bounds.maxHeight / 512);
        final width = 1536 * scale;
        final height = 1024 * scale;
        final column = index % 2;
        final row = index ~/ 2;
        final left = (bounds.maxWidth - width / 2) / 2 - column * width / 2;
        final top = (bounds.maxHeight - height / 2) / 2 - row * height / 2;
        return ClipRect(
            child: Stack(children: [
          Positioned(
              left: left,
              top: top,
              width: width,
              height: height,
              child: Image.asset(referenceFoodSheet, fit: BoxFit.fill))
        ]));
      })));
}

int referencePhotoForEmoji(String emoji) => emoji == '🍱'
    ? 1
    : emoji == '🧁'
        ? 2
        : 0;

/// Blends the supplied logo's white matte into its surrounding surface.
/// The original artwork file and opaque iOS app icons are preserved.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width, this.height, this.backgroundColor});
  final double? width, height;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => ClipRect(
      child: ColorFiltered(
          colorFilter: ColorFilter.mode(
              backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
              BlendMode.modulate),
          child: Image.asset('assets/foodienoms_logo.png',
              width: width,
              height: height,
              fit: BoxFit.contain,
              semanticLabel: 'FoodieNoms logo')));
}

int listingPhotoIndex(Map<String, dynamic> listing) {
  final key = listing['imageKey'];
  if (key is String && RegExp(r'^photo-[0-3]$').hasMatch(key)) {
    return int.parse(key.substring(6));
  }
  return listing['category'] == 'Meals'
      ? 1
      : listing['category'] == 'Pastries'
          ? 2
          : 0;
}

class ListingPhotoPicker extends StatelessWidget {
  const ListingPhotoPicker(
      {super.key, required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  static const labels = [
    'Pastry box',
    'Rice meal',
    'Pastry basket',
    'Bakery counter'
  ];
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Photo (optional)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Students see this as an illustrative photo.'),
        const SizedBox(height: 12),
        GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: [
              for (var i = 0; i < 4; i++)
                Semantics(
                  selected: selected == i,
                  button: true,
                  label: labels[i],
                  child: InkWell(
                      onTap: () => onSelected(i),
                      child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: selected == i
                                      ? const Color(0xFF205F45)
                                      : Colors.transparent,
                                  width: 3)),
                          child: Stack(fit: StackFit.expand, children: [
                            ReferenceFoodPhoto(index: i),
                            Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: ColoredBox(
                                    color: Colors.black54,
                                    child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(labels[i],
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12))))),
                            if (selected == i)
                              const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(Icons.check_circle,
                                      color: Colors.white)),
                          ]))),
                ),
            ]),
      ]);
}
