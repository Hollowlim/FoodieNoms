import 'package:flutter/material.dart';
import 'reference_assets.dart';
import 'location_state.dart';
import 'live_location_map.dart';
export 'location_state.dart';

const studentGreen = Color(0xFF205F45);
const studentDark = Color(0xFF263D30);
const studentCream = Color(0xFFFAF9F3);
const studentPale = Color(0xFFEBF2DD);

void openLocation(BuildContext context, PilotLocation location) =>
    Navigator.push<void>(context,
        MaterialPageRoute(builder: (_) => LocationScreen(location: location)));

class StudentDiscoverHeader extends StatelessWidget {
  const StudentDiscoverHeader(
      {super.key, required this.location, required this.onSearch});
  final PilotLocation location;
  final ValueChanged<String> onSearch;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            color: studentGreen,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                    child: Text('FoodieNoms',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800))),
                const ClipOval(
                    child: SizedBox(
                        width: 60,
                        height: 60,
                        child: ColoredBox(
                            color: Colors.white,
                            child: Padding(
                                padding: EdgeInsets.all(3),
                                child: BrandLogo(
                                    width: 54,
                                    height: 54,
                                    backgroundColor: Colors.white)))))
              ]),
              const SizedBox(height: 22),
              const Text('Rescue delicious food.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Spend less. Waste less. Eat better.',
                  style: TextStyle(color: Color(0xFFD5E8D9))),
              const SizedBox(height: 18),
              AnimatedBuilder(
                  animation: location,
                  builder: (context, _) => Material(
                      color: const Color(0xFF34775B),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => openLocation(context, location),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 11),
                              child: Row(children: [
                                const Icon(Icons.location_on_outlined,
                                    color: Colors.white, size: 17),
                                const SizedBox(width: 7),
                                Expanded(
                                    child: Text(location.area,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600))),
                                const Icon(Icons.keyboard_arrow_down,
                                    color: Colors.white, size: 20),
                              ]))))),
              const SizedBox(height: 12),
              TextField(
                  onChanged: onSearch,
                  decoration: InputDecoration(
                      hintText: 'Search meals, bakeries, cafes…',
                      prefixIcon: const Icon(Icons.search, size: 21),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none))),
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                    color: const Color(0xFFD6EBAA),
                    borderRadius: BorderRadius.circular(18)),
                child: const Text(
                    '✦ SAVE MORE   ·   RESCUE FOOD   ·   SUBANG JAYA',
                    style: TextStyle(
                        color: studentGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: .4)))),
      ]);
}

class PilotMap extends StatelessWidget {
  const PilotMap({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label:
          'Illustrative Subang Jaya area map. Markers are examples, not live vendor positions.',
      child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(referenceMap,
              width: double.infinity,
              fit: BoxFit.contain,
              excludeFromSemantics: true)));
}

class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key, required this.location});
  final PilotLocation location;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: studentCream,
      appBar: AppBar(title: const Text('FoodieNoms')),
      body: SafeArea(
          child: AnimatedBuilder(
              animation: location,
              builder: (context, _) =>
                  ListView(padding: const EdgeInsets.all(24), children: [
                    const Text('Find food near you',
                        style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: studentDark)),
                    const SizedBox(height: 24),
                    LiveLocationMap(location: location),
                    const SizedBox(height: 8),
                    const Text(
                        'Interactive map · use location to show your blue marker',
                        style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 24),
                    Text('Browsing: ${location.area}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Text(
                        'Choose device location or browse our Subang Jaya pilot manually. Listing addresses are shown before you reserve.'),
                    if (location.position != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                              'Device coordinates: ${location.position!.latitude.toStringAsFixed(4)}, ${location.position!.longitude.toStringAsFixed(4)}')),
                    if (location.message != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(location.message!)),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed:
                            location.busy ? null : location.useDeviceLocation,
                        child: Text(location.busy
                            ? 'Finding your location…'
                            : 'Use My Location')),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                        onPressed: location.busy
                            ? null
                            : () {
                                location.useManual();
                                Navigator.pop(context);
                              },
                        child: const Text('Browse Subang Jaya Manually')),
                    const SizedBox(height: 20),
                    const Text(
                        'Location is optional. Updates stop when you leave the map or background the app. OpenStreetMap receives the map area you view. Coordinates are not saved to Firebase. Vendor distances and turn-by-turn navigation are not available.',
                        style: TextStyle(
                            color: Colors.black54, fontSize: 12, height: 1.5)),
                  ]))));
}

class StudentProfilePanel extends StatelessWidget {
  const StudentProfilePanel(
      {super.key,
      required this.name,
      required this.email,
      required this.onPersonalInfo,
      required this.onReviews,
      required this.onNotifications,
      required this.onLocation,
      required this.onSettings,
      required this.onLogout});
  final String name, email;
  final VoidCallback onPersonalInfo,
      onReviews,
      onNotifications,
      onLocation,
      onSettings,
      onLogout;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(22), children: [
        const Text('My profile',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: studentDark)),
        const SizedBox(height: 24),
        Row(children: [
          CircleAvatar(
              radius: 27,
              backgroundColor: studentPale,
              child: Text(
                  name.trim().isEmpty
                      ? 'F'
                      : name.trim().substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: studentGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(email,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 4),
                const Text('Student account',
                    style: TextStyle(color: studentGreen, fontSize: 12)),
              ]))
        ]),
        const SizedBox(height: 24),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: studentPale, borderRadius: BorderRadius.circular(14)),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated savings',
                      style: TextStyle(color: studentGreen)),
                  SizedBox(height: 10),
                  Text('RM 0.00',
                      style: TextStyle(
                          color: studentGreen,
                          fontSize: 30,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('Savings tracking coming soon',
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                ])),
        const SizedBox(height: 20),
        _ProfileRow(
            'Personal information', Icons.person_outline, onPersonalInfo),
        _ProfileRow('My reviews', Icons.star_border, onReviews),
        _ProfileRow('Notifications', Icons.notifications_none, onNotifications),
        _ProfileRow(
            'Privacy & location', Icons.location_on_outlined, onLocation),
        _ProfileRow('Account settings', Icons.settings_outlined, onSettings),
        _ProfileRow('Log out', Icons.logout, onLogout),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFE3F1E4),
                borderRadius: BorderRadius.circular(10)),
            child: const Text('FoodieNoms · Good food. Less waste.',
                style: TextStyle(
                    color: studentGreen, fontWeight: FontWeight.w600))),
      ]);
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
          dense: true,
          leading: Icon(icon, color: studentGreen, size: 21),
          title: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onTap));
}

class StudentDealTile extends StatelessWidget {
  const StudentDealTile(
      {super.key,
      required this.title,
      required this.price,
      required this.original,
      required this.subtitle,
      required this.emoji,
      required this.onTap,
      this.preview = false});
  final String title, price, original, subtitle, emoji;
  final VoidCallback onTap;
  final bool preview;
  @override
  Widget build(BuildContext context) => Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEBEEE7))),
      child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                SizedBox(
                    width: 76,
                    height: 82,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(fit: StackFit.expand, children: [
                          ReferenceFoodPhoto(
                              index: referencePhotoForEmoji(emoji)),
                          if (!preview)
                            const Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: ColoredBox(
                                    color: Color(0x99000000),
                                    child: Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Text('Illustrative',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9))))),
                        ]))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: studentDark)),
                      const SizedBox(height: 6),
                      Text(price,
                          style: const TextStyle(
                              color: studentGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('$original original · $subtitle',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 11)),
                      if (preview)
                        const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('PREVIEW ONLY',
                                style: TextStyle(
                                    color: studentGreen,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                    letterSpacing: .5))),
                    ])),
              ]))));
}
