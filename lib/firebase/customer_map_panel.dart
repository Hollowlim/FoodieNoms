import 'package:flutter/material.dart';
import 'live_location_map.dart';
import 'location_state.dart';

const _panelGreen = Color(0xFF205F45);
const _panelInk = Color(0xFF263D30);
const _panelMuted = Color(0xFF718075);

class CustomerMapPanel extends StatefulWidget {
  const CustomerMapPanel(
      {super.key,
      required this.location,
      required this.shops,
      this.focusShop,
      required this.onShopTap,
      required this.onChangeLocation,
      this.loading = false,
      this.error});
  final PilotLocation location;
  final List<ShopMapPin> shops;
  final ShopMapPin? focusShop;
  final ValueChanged<ShopMapPin> onShopTap;
  final VoidCallback onChangeLocation;
  final bool loading;
  final String? error;

  @override
  State<CustomerMapPanel> createState() => _CustomerMapPanelState();
}

class _CustomerMapPanelState extends State<CustomerMapPanel> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void clear() {
    search.clear();
    setState(() => query = '');
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.shops
        .where((shop) => '${shop.name} ${shop.address}'
            .toLowerCase()
            .contains(query.trim().toLowerCase()))
        .toList();
    final focused =
        visible.where((shop) => shop.id == widget.focusShop?.id).firstOrNull;
    final mapHeight = (MediaQuery.sizeOf(context).height * .46)
        .clamp(300.0, 430.0)
        .toDouble();
    return ListView(
        key: const ValueKey('customer-map-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text('Find your next pickup',
              style: TextStyle(
                  color: _panelInk,
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          AnimatedBuilder(
              animation: widget.location,
              builder: (context, _) => Material(
                  color: const Color(0xFFEAF2EC),
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap: widget.onChangeLocation,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          child: Row(children: [
                            const Icon(Icons.location_on_outlined,
                                color: _panelGreen, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(widget.location.area,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _panelGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            const SizedBox(width: 8),
                            const Text('Change',
                                style: TextStyle(
                                    color: _panelGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 3),
                            const Icon(Icons.expand_more_rounded,
                                size: 17, color: _panelGreen),
                          ]))))),
          const SizedBox(height: 12),
          TextField(
              key: const ValueKey('pickup-spot-search'),
              controller: search,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              onChanged: (value) => setState(() => query = value),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(fontSize: 14, color: _panelInk),
              decoration: InputDecoration(
                  hintText: 'Search pickup spots',
                  hintStyle: const TextStyle(color: _panelMuted, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _panelMuted, size: 21),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear pickup spot search',
                          onPressed: clear,
                          icon: const Icon(Icons.close_rounded, size: 18)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFFE4EAE3))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFFE4EAE3))))),
          const SizedBox(height: 14),
          LiveLocationMap(
              location: widget.location,
              height: mapHeight,
              shops: visible,
              focusShop: focused,
              onShopTap: widget.onShopTap),
          const SizedBox(height: 10),
          const Text('Tap a pin to see available food.',
              style: TextStyle(color: _panelMuted, fontSize: 11.5)),
          AnimatedBuilder(
              animation: widget.location,
              builder: (_, __) => widget.location.outsideServiceArea
                  ? _OutsideAreaNotice(onBrowse: widget.location.useManual)
                  : const SizedBox.shrink()),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(
                child: Text('Pickup spots',
                    style: TextStyle(
                        color: _panelInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w800))),
            Text('${visible.length}',
                style: const TextStyle(
                    color: _panelMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          if (widget.loading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _panelGreen)),
                  SizedBox(height: 10),
                  Text('Finding pickup spots…',
                      style: TextStyle(color: _panelMuted, fontSize: 13)),
                ]))
          else if (widget.error != null)
            _MapEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Pickup spots could not load',
                message: widget.error!)
          else if (visible.isEmpty)
            _MapEmptyState(
                icon: query.trim().isEmpty
                    ? Icons.storefront_outlined
                    : Icons.search_off_rounded,
                title: query.trim().isEmpty
                    ? 'Pickup spots are coming soon'
                    : 'No matching pickup spots',
                message: query.trim().isEmpty
                    ? 'Approved shops appear here after saving their pickup location.'
                    : 'Try a shop name or address in Subang Jaya.',
                action: query.trim().isEmpty ? null : clear)
          else
            for (final shop in visible)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: shop.id == focused?.id
                                  ? const Color(0xFFA9C9B5)
                                  : const Color(0xFFE8ECE5))),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                          key: ValueKey('pickup-spot-${shop.id}'),
                          onTap: () => widget.onShopTap(shop),
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFEAF3EC),
                                        borderRadius:
                                            BorderRadius.circular(13)),
                                    child: const Icon(Icons.storefront_outlined,
                                        color: _panelGreen, size: 21)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(shop.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: _panelInk,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(shop.address,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: _panelMuted,
                                              height: 1.35,
                                              fontSize: 11.5)),
                                    ])),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded,
                                    color: Color(0xFF92A398), size: 21),
                              ]))))),
        ]);
  }
}

class _OutsideAreaNotice extends StatelessWidget {
  const _OutsideAreaNotice({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF4E2),
              borderRadius: BorderRadius.circular(13)),
          child: Row(children: [
            const Icon(Icons.location_off_outlined,
                color: Color(0xFFA26C27), size: 19),
            const SizedBox(width: 9),
            const Expanded(
                child: Text(
                    'Outside service area. You can still browse Subang Jaya.',
                    style: TextStyle(
                        color: Color(0xFF805B2E),
                        height: 1.35,
                        fontSize: 11.5))),
            const SizedBox(width: 4),
            TextButton(
                onPressed: onBrowse,
                child: const Text('Browse here',
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700))),
          ])));
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState(
      {required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title, message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(children: [
        Icon(icon, color: const Color(0xFF9BAFA0), size: 30),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _panelInk, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 6),
        Text(message,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: _panelMuted, height: 1.4, fontSize: 12)),
        if (action != null)
          TextButton(onPressed: action, child: const Text('Clear search')),
      ]));
}
