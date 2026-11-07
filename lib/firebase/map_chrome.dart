import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _mapGreen = Color(0xFF247553);
const _mapInk = Color(0xFF243C30);

/// Style raster tiles only; location dots, shop pins and labels stay untouched.
/// This keeps the same OpenStreetMap provider and its readable road labels.
class CleanMapTiles extends StatelessWidget {
  const CleanMapTiles({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColorFiltered(
      // Saturation .48, contrast .96, with a small brightness lift.
      colorFilter: const ColorFilter.matrix([
        .56693,
        .35703,
        .03604,
        0,
        10.2,
        .10613,
        .81783,
        .03604,
        0,
        10.2,
        .10613,
        .35703,
        .49684,
        0,
        10.2,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: child);
}

class MapControlStack extends StatelessWidget {
  const MapControlStack(
      {super.key,
      required this.onZoomIn,
      required this.onZoomOut,
      this.onLocate,
      this.locating = false,
      this.zoomInLabel = 'Zoom in',
      this.zoomOutLabel = 'Zoom out',
      this.locateLabel = 'Show my location'});
  final VoidCallback onZoomIn, onZoomOut;
  final VoidCallback? onLocate;
  final bool locating;
  final String zoomInLabel, zoomOutLabel, locateLabel;

  Widget surface(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x180E3525), blurRadius: 16, offset: Offset(0, 4)),
          ]),
      child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE9EEEA))),
          clipBehavior: Clip.antiAlias,
          child: child));

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            surface(SizedBox(
                width: 46,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      tooltip: zoomInLabel,
                      onPressed: onZoomIn,
                      color: _mapInk,
                      iconSize: 22,
                      constraints:
                          const BoxConstraints.tightFor(width: 46, height: 43),
                      icon: const Icon(Icons.add_rounded)),
                  const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 12,
                      endIndent: 12,
                      color: Color(0xFFEDF1ED)),
                  IconButton(
                      tooltip: zoomOutLabel,
                      onPressed: onZoomOut,
                      color: _mapInk,
                      iconSize: 22,
                      constraints:
                          const BoxConstraints.tightFor(width: 46, height: 43),
                      icon: const Icon(Icons.remove_rounded)),
                ]))),
            const SizedBox(height: 10),
            surface(SizedBox(
                width: 46,
                height: 46,
                child: IconButton(
                    tooltip: locateLabel,
                    onPressed: locating ? null : onLocate,
                    color: _mapGreen,
                    iconSize: 22,
                    icon: locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _mapGreen))
                        : const Icon(Icons.my_location_rounded)))),
          ]);
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  Future<void> open(BuildContext context) async {
    try {
      final opened = await launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {
      // Keep the attribution available even if the external browser fails.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('OpenStreetMap attribution: openstreetmap.org/copyright')));
    }
  }

  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xF5FFFFFF),
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(7)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: () => open(context),
          child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Text('© OpenStreetMap contributors',
                  style: TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF50685A),
                      fontWeight: FontWeight.w500)))));
}

/// A shop pin drawn in Flutter so it stays sharp at every device scale.
class ShopPinMarker extends StatelessWidget {
  const ShopPinMarker(
      {super.key, required this.selected, this.draggable = false});
  final bool selected, draggable;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: selected ? 50 : 43,
      height: selected ? 59 : 51,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
            child: CustomPaint(painter: _ShopPinPainter(selected: selected))),
        Align(
            alignment: const Alignment(0, -.3),
            child: Icon(Icons.storefront_rounded,
                color: Colors.white, size: selected ? 23 : 20)),
        if (draggable)
          Positioned(
              right: -2,
              top: -2,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDCE8E0))),
                  child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.open_with_rounded,
                          color: _mapGreen, size: 11)))),
      ]));
}

class _ShopPinPainter extends CustomPainter {
  const _ShopPinPainter({required this.selected});
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final pin = Path()
      ..moveTo(width / 2, height - 2)
      ..cubicTo(width * .36, height * .82, 2, height * .55, 2, height * .39)
      ..cubicTo(2, height * .15, width * .2, 2, width / 2, 2)
      ..cubicTo(width * .8, 2, width - 2, height * .15, width - 2, height * .39)
      ..cubicTo(width - 2, height * .55, width * .64, height * .82, width / 2,
          height - 2)
      ..close();
    canvas.drawShadow(pin, const Color(0x66204734), 4, true);
    canvas.drawPath(
        pin,
        Paint()
          ..color =
              selected ? const Color(0xFF153F2F) : const Color(0xFF2A8861));
    canvas.drawPath(
        pin,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _ShopPinPainter oldDelegate) =>
      oldDelegate.selected != selected;
}
