import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'management_ui.dart';
import 'listing_photo.dart';
import 'reference_assets.dart';
import 'service.dart';
import 'student_experience.dart';
import 'vendor_business.dart';
import 'business_location.dart';

bool vendorListingRemoved(Map<String, dynamic> data) =>
    data.containsKey('removedAt');

String vendorListingStatus(Map<String, dynamic> data, {DateTime? now}) {
  if (vendorListingRemoved(data)) return 'Removed';
  if (data['status'] == 'draft' || data['formData'] is Map) return 'Draft';
  final end = data['pickupEnd'];
  if (end is num && end <= (now ?? DateTime.now()).millisecondsSinceEpoch) {
    return 'Expired';
  }
  if (data['active'] != true || end is! num) return 'Unavailable';
  if ((data['stock'] as num? ?? 0) <= 0) return 'Sold out';
  return 'Active';
}

class VendorPendingScreen extends StatefulWidget {
  const VendorPendingScreen(
      {super.key,
      required this.service,
      required this.email,
      this.revoked = false,
      this.reason});
  final FoodieService service;
  final String email;
  final bool revoked;
  final String? reason;
  @override
  State<VendorPendingScreen> createState() => _VendorPendingScreenState();
}

class _VendorPendingScreenState extends State<VendorPendingScreen> {
  bool checking = false;
  String? message;
  Future<void> check() async {
    setState(() {
      checking = true;
      message = null;
    });
    try {
      final profile = await widget.service.db
          .collection('users')
          .doc(widget.service.auth.currentUser!.uid)
          .get(const GetOptions(source: Source.server));
      if (mounted) {
        setState(() => message = profile.data()?['approved'] == true
            ? 'Approved! Opening your business dashboard…'
            : profile.data()?['revokedAt'] != null
                ? 'Your selling access is revoked. An administrator must approve it again.'
                : 'Your application is still pending. Your dashboard will open automatically once approved.');
      }
    } catch (e) {
      if (mounted) setState(() => message = firebaseMessage(e));
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => VendorPendingContent(
      email: widget.email,
      revoked: widget.revoked,
      reason: widget.reason,
      checking: checking,
      message: message,
      onCheck: check,
      onBusiness: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VendorBusinessScreen(service: widget.service))),
      onSignOut: () async {
        try {
          await widget.service.auth.signOut();
        } catch (e) {
          if (mounted) setState(() => message = firebaseMessage(e));
        }
      });
}

class VendorPendingContent extends StatelessWidget {
  const VendorPendingContent(
      {super.key,
      required this.email,
      required this.onCheck,
      required this.onSignOut,
      this.checking = false,
      this.message,
      this.revoked = false,
      this.reason,
      this.onBusiness});
  final String email;
  final VoidCallback onCheck, onSignOut;
  final bool checking;
  final String? message;
  final bool revoked;
  final String? reason;
  final VoidCallback? onBusiness;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: managementCream,
        appBar: AppBar(
            title: const Text('FoodieNoms · Vendor'),
            backgroundColor: managementGreen,
            foregroundColor: Colors.white),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(24),
                        children: [
                          Icon(
                              revoked
                                  ? Icons.storefront_outlined
                                  : Icons.hourglass_top_rounded,
                              size: 68,
                              color: managementGreen),
                          const SizedBox(height: 24),
                          Text(
                              revoked
                                  ? 'Your selling access is revoked'
                                  : 'Your business is pending approval',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: managementInk)),
                          const SizedBox(height: 16),
                          Text(
                              revoked
                                  ? 'An administrator has paused your selling access. Your shop is hidden from customers and new listings and orders are blocked. Your existing orders are kept.'
                                  : 'Thanks for joining FoodieNoms! An administrator needs to review your vendor account before you can start selling surplus food. You can prepare your shop name and map pin now.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(height: 1.5)),
                          if (revoked && reason?.isNotEmpty == true)
                            ManagementCard(child: Text('Reason: $reason')),
                          const SizedBox(height: 12),
                          Text(email,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 24),
                          if (!revoked)
                            const ManagementCard(
                                child: Column(children: [
                              ListTile(
                                  leading: Icon(Icons.check_circle_outline,
                                      color: managementGreen),
                                  title: Text('Account created'),
                                  subtitle: Text(
                                      'Your vendor registration is complete.')),
                              ListTile(
                                  leading: Icon(Icons.pending_actions,
                                      color: managementGreen),
                                  title: Text('Admin review in progress'),
                                  subtitle: Text(
                                      'You can sign out and return later.')),
                              ListTile(
                                  leading: Icon(Icons.storefront_outlined,
                                      color: managementGreen),
                                  title: Text('Start your food business'),
                                  subtitle: Text(
                                      'After approval, add food, manage stock and collect pickup orders.')),
                            ])),
                          if (onBusiness != null)
                            OutlinedButton.icon(
                                onPressed: onBusiness,
                                icon:
                                    const Icon(Icons.add_location_alt_outlined),
                                label:
                                    const Text('Set up shop name & location')),
                          const SizedBox(height: 8),
                          FilledButton(
                              onPressed: checking ? null : onCheck,
                              child: Text(checking
                                  ? 'Checking…'
                                  : 'Check approval status')),
                          if (message != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(message!,
                                    textAlign: TextAlign.center)),
                          TextButton(
                              onPressed: onSignOut,
                              child: const Text('Sign out')),
                        ])))),
      );
}

class VendorBusinessSummary extends StatelessWidget {
  const VendorBusinessSummary(
      {super.key, required this.service, required this.uid});
  final FoodieService service;
  final String uid;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              service.db.collection('vendorBusinesses').doc(uid).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final ready = ShopMapPin.fromData(uid, data ?? {}) != null;
            return ManagementCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text(
                      ready
                          ? data!['businessName'] as String
                          : 'Set up your business',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(snapshot.hasError
                      ? firebaseMessage(snapshot.error!)
                      : ready
                          ? '${data!['address']}\nMap pin: ${(data['latitude'] as num).toStringAsFixed(5)}, ${(data['longitude'] as num).toStringAsFixed(5)}'
                          : 'Save your shop name, pickup address and a map pin before publishing food.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  VendorBusinessScreen(service: service))),
                      icon: const Icon(Icons.edit_location_alt_outlined),
                      label: Text(ready
                          ? 'Edit business & location'
                          : 'Set up shop name & location')),
                ]));
          });
}

class VendorListingCard extends StatelessWidget {
  const VendorListingCard(
      {super.key,
      required this.listing,
      required this.onEdit,
      required this.onToggle,
      required this.onAdjust,
      this.onDuplicate,
      this.onReservations,
      this.onRemove,
      this.photo,
      this.busy = false});
  final Map<String, dynamic> listing;
  final VoidCallback onEdit, onToggle;
  final ValueChanged<int> onAdjust;
  final VoidCallback? onDuplicate, onReservations;
  final Future<void> Function()? onRemove;
  final Widget? photo;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final status = vendorListingStatus(listing);
    final ended = status == 'Expired';
    return ManagementCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
                width: 96,
                height: 96,
                child: photo ??
                    Stack(fit: StackFit.expand, children: [
                      ReferenceFoodPhoto(index: listingPhotoIndex(listing)),
                      const Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ColoredBox(
                              color: Color(0xEEFFFFFF),
                              child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 3),
                                  child: Text('Illustrative',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 10)))))
                    ]))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(listing['title'] as String,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(money(listing['priceCents']),
              style: const TextStyle(
                  fontSize: 18,
                  color: managementGreen,
                  fontWeight: FontWeight.w700)),
        ])),
      ]),
      const SizedBox(height: 12),
      Align(
          alignment: Alignment.centerLeft,
          child: Chip(
              label: Text(status),
              avatar: Icon(
                  status == 'Active'
                      ? Icons.check_circle_outline
                      : status == 'Sold out'
                          ? Icons.inventory_2_outlined
                          : ended
                              ? Icons.schedule
                              : Icons.pause_circle_outline,
                  size: 18))),
      Text('Pickup ${friendlyPickupWindow(listing)}'),
      const SizedBox(height: 6),
      Text(listing['address'] as String),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(
            child: Text('Available stock',
                style: TextStyle(fontWeight: FontWeight.w700))),
        IconButton(
            tooltip: 'Remove one item',
            onPressed: busy || ended || (listing['stock'] as int) <= 0
                ? null
                : () => onAdjust(-1),
            icon: const Icon(Icons.remove_circle_outline)),
        Text('${listing['stock']}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        IconButton(
            tooltip: 'Add one item',
            onPressed: busy || ended || (listing['stock'] as int) >= 10000
                ? null
                : () => onAdjust(1),
            icon: const Icon(Icons.add_circle_outline)),
      ]),
      if (ended)
        const Text('Extend the pickup window to offer this food again.',
            style: TextStyle(color: Colors.deepOrange)),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: Text(ended ? 'Renew pickup window' : 'Edit listing')),
        TextButton(
            onPressed: busy ||
                    ended ||
                    (listing['active'] != true &&
                        (listing['stock'] as int) == 0)
                ? null
                : onToggle,
            child: Text(listing['active'] == true
                ? 'Mark unavailable'
                : 'Reopen listing')),
        if (onDuplicate != null)
          TextButton.icon(
              onPressed: busy ? null : onDuplicate,
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('List again')),
        if (onReservations != null)
          TextButton.icon(
              onPressed: busy ? null : onReservations,
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('View reservations')),
        if (onRemove != null)
          VendorRemoveListingButton(
              title: listing['title'] as String,
              onRemove: onRemove!,
              busy: busy),
      ]),
      if (busy) const LinearProgressIndicator(),
    ]));
  }
}

class VendorRemoveListingButton extends StatefulWidget {
  const VendorRemoveListingButton(
      {super.key,
      required this.title,
      required this.onRemove,
      this.busy = false});
  final String title;
  final Future<void> Function() onRemove;
  final bool busy;
  @override
  State<VendorRemoveListingButton> createState() =>
      _VendorRemoveListingButtonState();
}

class _VendorRemoveListingButtonState extends State<VendorRemoveListingButton> {
  bool confirming = false, removing = false;

  Future<void> remove() async {
    if (widget.busy || confirming || removing) return;
    setState(() => confirming = true);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Remove this listing?'),
                content: Text(
                    'Remove “${widget.title}” from your listings and stop new orders?\n\n'
                    'Existing reservations stay in Pickups. You can still complete or cancel them.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Keep listing')),
                  FilledButton(
                      key: const ValueKey('remove-listing-confirm'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error),
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Remove listing')),
                ]));
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => confirming = false);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      confirming = false;
      removing = true;
    });
    try {
      await widget.onRemove();
      // The card can disappear from the live stream before this future returns.
      if (messenger.mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text(
                'Listing removed. Existing reservations are kept in Pickups.')));
      }
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(firebaseMessage(error))));
      }
    } finally {
      if (mounted) setState(() => removing = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
      key: const ValueKey('remove-listing-action'),
      onPressed: widget.busy || confirming || removing ? null : remove,
      style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error),
      icon: removing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.delete_outline, size: 19),
      label: Text(removing ? 'Removing…' : 'Remove listing'));
}

class VendorDashboard extends StatefulWidget {
  const VendorDashboard(
      {super.key,
      required this.service,
      required this.uid,
      required this.onAdd,
      required this.onEdit,
      this.onResumeDraft,
      this.onDuplicate,
      this.onReservations});
  final FoodieService service;
  final String uid;
  final VoidCallback onAdd;
  final void Function(String, Map<String, dynamic>) onEdit;
  final void Function(String, Map<String, dynamic>)? onResumeDraft, onDuplicate;
  final VoidCallback? onReservations;
  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  late var listings = widget.service.listings('vendor', widget.uid);
  late final pickups = widget.service.reservations('vendor', widget.uid);
  late var drafts = widget.service.listingDrafts(widget.uid);
  final pending = <String>{};
  String filter = 'All';
  String section = 'published';
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> action(String id, String name, Map<String, dynamic> data) async {
    setState(() => pending.add(id));
    try {
      await widget.service.call(name, {'listingId': id, ...data});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(firebaseMessage(e))));
      }
    } finally {
      if (mounted) setState(() => pending.remove(id));
    }
  }

  Future<void> removeListing(String id) async {
    if (pending.contains(id)) {
      throw StateError(
          'Another change is still saving. Please try again shortly.');
    }
    setState(() => pending.add(id));
    try {
      await widget.service.call('removeListing', {'listingId': id});
    } finally {
      if (mounted) setState(() => pending.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
      stream: listings,
      builder: (context, snapshot) => StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
          stream: drafts,
          builder: (context, savedDrafts) {
            final docs = (snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((doc) => !vendorListingRemoved(doc.data()))
                .toList();
            final visible = docs
                .where((d) =>
                    filter == 'All' || vendorListingStatus(d.data()) == filter)
                .toList()
              ..sort((a, b) => (b.data()['pickupEnd'] as int)
                  .compareTo(a.data()['pickupEnd'] as int));
            return ListView(children: [
              const VendorBanner(),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Vendor dashboard',
                            style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: managementInk)),
                        const SizedBox(height: 16),
                        VendorBusinessSummary(
                            service: widget.service, uid: widget.uid),
                        ManagementCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  snapshot.hasError
                                      ? 'Listings unavailable'
                                      : 'Active listings: ${snapshot.hasData ? docs.where((d) => vendorListingStatus(d.data()) == 'Active').length : '…'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              StreamBuilder<
                                      QuerySnapshot<Map<String, dynamic>>>(
                                  stream: pickups,
                                  builder: (context, orders) => Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(orders.hasError
                                                ? 'Pickup totals unavailable'
                                                : 'Pending pickups: ${orders.hasData ? orders.data!.docs.where((d) => isOpenReservation(d.data())).length : '…'}'),
                                            if (widget.onReservations != null)
                                              TextButton.icon(
                                                  onPressed:
                                                      widget.onReservations,
                                                  icon: const Icon(
                                                      Icons
                                                          .receipt_long_outlined,
                                                      size: 18),
                                                  label: const Text(
                                                      'View reservations')),
                                          ])),
                            ])),
                        FilledButton.icon(
                            onPressed: widget.onAdd,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Surplus Food')),
                        const SizedBox(height: 20),
                        SegmentedButton<String>(
                            segments: [
                              const ButtonSegment(
                                  value: 'published',
                                  label: Text('Published'),
                                  icon: Icon(Icons.storefront_outlined)),
                              ButtonSegment(
                                  value: 'drafts',
                                  label: Text(savedDrafts.hasData
                                      ? 'Drafts (${savedDrafts.data!.docs.length})'
                                      : 'Drafts'),
                                  icon: const Icon(Icons.drafts_outlined)),
                            ],
                            showSelectedIcon: false,
                            selected: {section},
                            onSelectionChanged: (values) =>
                                setState(() => section = values.first)),
                        const SizedBox(height: 20),
                        if (section == 'drafts')
                          VendorDraftList(
                              drafts: [
                                for (final draft in savedDrafts.data?.docs ??
                                    <QueryDocumentSnapshot<
                                        Map<String, dynamic>>>[])
                                  VendorDraftRecord(
                                      id: draft.id, data: draft.data())
                              ],
                              loading:
                                  !savedDrafts.hasData && !savedDrafts.hasError,
                              fromCache:
                                  savedDrafts.data?.metadata.isFromCache ??
                                      false,
                              error: savedDrafts.hasError
                                  ? firebaseMessage(savedDrafts.error!)
                                  : null,
                              onResume: widget.onResumeDraft,
                              onDelete: widget.service.deleteListingDraft,
                              onAdd: widget.onAdd,
                              onRetry: () => setState(() => drafts =
                                  widget.service.listingDrafts(widget.uid))),
                        if (section == 'published') ...[
                          const Text('Your listings',
                              style: TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w800)),
                          SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: [
                                for (final value in [
                                  'All',
                                  'Active',
                                  'Sold out',
                                  'Expired',
                                  'Unavailable'
                                ])
                                  Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                          label: Text(value),
                                          selected: filter == value,
                                          onSelected: (_) =>
                                              setState(() => filter = value)))
                              ])),
                          const SizedBox(height: 12),
                          if (snapshot.hasError)
                            StudentEmptyState(
                                title: 'Unable to load listings',
                                message: firebaseMessage(snapshot.error!),
                                actionLabel: 'Try again',
                                onAction: () => setState(() => listings = widget
                                    .service
                                    .listings('vendor', widget.uid))),
                          if (!snapshot.hasData && !snapshot.hasError)
                            const Center(child: CircularProgressIndicator()),
                          if (snapshot.hasData && visible.isEmpty)
                            StudentEmptyState(
                                title: docs.isEmpty
                                    ? 'Ready to publish your first deal?'
                                    : 'No $filter listings',
                                message: docs.isEmpty
                                    ? 'Add food details, set a pickup window and choose a photo. Your deal will appear for students immediately.'
                                    : 'Choose another status to see more listings.',
                                actionLabel: docs.isEmpty
                                    ? 'Add your first food'
                                    : 'Show all listings',
                                onAction: docs.isEmpty
                                    ? widget.onAdd
                                    : () => setState(() => filter = 'All')),
                          for (final doc in visible)
                            VendorListingCard(
                                key: ValueKey('vendor-listing-${doc.id}'),
                                onRemove: () => removeListing(doc.id),
                                listing: doc.data(),
                                photo: ListingFoodPhoto(
                                    service: widget.service,
                                    listing: doc.data()),
                                busy: pending.contains(doc.id),
                                onEdit: () => widget.onEdit(doc.id, doc.data()),
                                onDuplicate: widget.onDuplicate == null
                                    ? null
                                    : () =>
                                        widget.onDuplicate!(doc.id, doc.data()),
                                onToggle: () => action(
                                    doc.id,
                                    'setListingActive',
                                    {'active': doc.data()['active'] != true}),
                                onAdjust: (delta) => action(doc.id,
                                    'adjustListingStock', {'delta': delta})),
                        ],
                      ])),
            ]);
          }));
}

class VendorDraftRecord {
  const VendorDraftRecord({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  Map get formData => data['formData'] is Map ? data['formData'] as Map : {};
  String get title {
    final value = formData['title'];
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : 'Untitled draft';
  }

  String? get category {
    final value = formData['category'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  DateTime? get savedAt {
    final value = data['updatedAt'] ?? data['createdAt'];
    return value is Timestamp ? value.toDate().toLocal() : null;
  }
}

/// Private saved work, kept separate from published food and reservations.
/// Injected callbacks allow confirmations and error states to be tested locally.
class VendorDraftList extends StatefulWidget {
  const VendorDraftList({
    super.key,
    required this.drafts,
    required this.onDelete,
    this.onResume,
    this.onAdd,
    this.onRetry,
    this.loading = false,
    this.fromCache = false,
    this.error,
  });
  final List<VendorDraftRecord> drafts;
  final Future<void> Function(String draftId) onDelete;
  final void Function(String draftId, Map<String, dynamic> draftRecord)?
      onResume;
  final VoidCallback? onAdd, onRetry;
  final bool loading, fromCache;
  final String? error;

  @override
  State<VendorDraftList> createState() => _VendorDraftListState();
}

class _VendorDraftListState extends State<VendorDraftList> {
  final deleting = <String>{};

  Future<void> deleteDraft(VendorDraftRecord draft) async {
    if (deleting.contains(draft.id)) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete this draft?'),
              content: Text(
                  'Remove “${draft.title}” from saved drafts. Published listings, photos and existing reservations are kept.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep draft')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete draft')),
              ],
            ));
    if (!mounted || confirmed != true) return;
    setState(() => deleting.add(draft.id));
    try {
      await widget.onDelete(draft.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Draft deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(firebaseMessage(error))));
      }
    } finally {
      if (mounted) setState(() => deleting.remove(draft.id));
    }
  }

  String savedLabel(DateTime date) {
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
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return 'Saved ${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Saved drafts',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Private work in progress. Students cannot see drafts.',
            style: TextStyle(color: Colors.black54, height: 1.4)),
        const SizedBox(height: 14),
        if (widget.fromCache && widget.drafts.isNotEmpty)
          const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Showing cached drafts. Updates sync when connected.',
                  style: TextStyle(color: managementGreen, fontSize: 12))),
        if (widget.error != null)
          StudentEmptyState(
              title: 'Unable to load drafts',
              message: widget.error!,
              actionLabel: widget.onRetry == null ? null : 'Try again',
              onAction: widget.onRetry),
        if (widget.loading && widget.drafts.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
        if (!widget.loading && widget.error == null && widget.drafts.isEmpty)
          StudentEmptyState(
              title: 'No saved drafts yet',
              message:
                  'Start a listing and save a draft at any step. Return here when you are ready to finish.',
              actionLabel: widget.onAdd == null ? null : 'Create a listing',
              onAction: widget.onAdd),
        for (final draft in widget.drafts)
          ManagementCard(
              key: ValueKey('vendor-draft-${draft.id}'),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DecoratedBox(
                              decoration: BoxDecoration(
                                  color: Color(0xFFE9F1E4),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(12))),
                              child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(Icons.edit_note_outlined,
                                      color: managementGreen, size: 26))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(draft.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                if (draft.category != null) ...[
                                  const SizedBox(height: 4),
                                  Text(draft.category!,
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                ],
                              ])),
                        ]),
                    const SizedBox(height: 10),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                            label: const Text('Draft'),
                            avatar: const Icon(Icons.edit_outlined, size: 17),
                            backgroundColor: const Color(0xFFF2F0E7),
                            side: BorderSide.none)),
                    if (draft.savedAt != null)
                      Text(savedLabel(draft.savedAt!),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 4, children: [
                      FilledButton.tonalIcon(
                          key: ValueKey('resume-draft-${draft.id}'),
                          onPressed: deleting.contains(draft.id) ||
                                  widget.onResume == null
                              ? null
                              : () => widget.onResume!(draft.id, draft.data),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Resume draft')),
                      TextButton.icon(
                          key: ValueKey('delete-draft-${draft.id}'),
                          onPressed: deleting.contains(draft.id)
                              ? null
                              : () => deleteDraft(draft),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(deleting.contains(draft.id)
                              ? 'Deleting…'
                              : 'Delete draft')),
                    ]),
                    if (deleting.contains(draft.id)) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                  ])),
      ]);
}
