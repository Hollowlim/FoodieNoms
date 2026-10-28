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
