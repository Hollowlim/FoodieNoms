import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'management_ui.dart';
import 'service.dart';
import 'business_location.dart';

enum VendorStatus {
  pending('Pending'),
  approved('Approved'),
  revoked('Revoked');

  const VendorStatus(this.label);
  final String label;
}

VendorStatus vendorStatusFor(Map<String, dynamic> profile) {
  if (profile['approved'] == true) return VendorStatus.approved;
  if (profile['revokedAt'] != null) return VendorStatus.revoked;
  return VendorStatus.pending;
}

class ManagedVendor {
  const ManagedVendor(
      {required this.id, required this.profile, this.business = const {}});
  final String id;
  final Map<String, dynamic> profile, business;
  VendorStatus get status => vendorStatusFor(profile);
  String get name => _nonEmpty(profile['name']) ?? 'Vendor account';
  String? get email => _nonEmpty(profile['email']);
  String? get businessName => _nonEmpty(business['businessName']);
  String? get address => _nonEmpty(business['address']);
  bool get hasMapPin {
    final latitude = business['latitude'], longitude = business['longitude'];
    return business['configured'] == true &&
        latitude is num &&
        longitude is num &&
        latitude.isFinite &&
        longitude.isFinite &&
        isPilotShopLocation(latitude.toDouble(), longitude.toDouble());
  }

  bool get visibleOnMap =>
      status == VendorStatus.approved &&
      business['approved'] == true &&
      hasMapPin;
  static String? _nonEmpty(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}

class VendorSummary {
  VendorSummary(Iterable<ManagedVendor> records) {
    for (final vendor in records) {
      switch (vendor.status) {
        case VendorStatus.pending:
          pending++;
        case VendorStatus.approved:
          approved++;
        case VendorStatus.revoked:
          revoked++;
      }
      if (vendor.hasMapPin) shopsWithMapPin++;
    }
  }
  int pending = 0, approved = 0, revoked = 0, shopsWithMapPin = 0;
  int get total => pending + approved + revoked;
}

List<ManagedVendor> filterManagedVendors(Iterable<ManagedVendor> records,
    {VendorStatus? status, String search = ''}) {
  final query = search.trim().toLowerCase();
  final result = records
      .where((vendor) =>
          (status == null || vendor.status == status) &&
          '${vendor.name} ${vendor.businessName ?? ''} ${vendor.email ?? ''}'
              .toLowerCase()
              .contains(query))
      .toList();
  result.sort((a, b) {
    final statusOrder = a.status.index.compareTo(b.status.index);
    if (statusOrder != 0) return statusOrder;
    final nameOrder = (a.businessName ?? a.name)
        .toLowerCase()
        .compareTo((b.businessName ?? b.name).toLowerCase());
    return nameOrder != 0 ? nameOrder : a.id.compareTo(b.id);
  });
  return result;
}

/// Both sources are live; account status comes from the private vendor profile.
class _VendorData extends StatefulWidget {
  const _VendorData({required this.service, required this.builder});
  final FoodieService service;
  final Widget Function(BuildContext, List<ManagedVendor>) builder;
  @override
  State<_VendorData> createState() => _VendorDataState();
}

class _VendorDataState extends State<_VendorData> {
  late final accounts = widget.service.db
      .collection('users')
      .where('role', isEqualTo: 'vendor')
      .snapshots();
  late final businesses =
      widget.service.db.collection('vendorBusinesses').snapshots();
  Widget failure(Object error) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: managementGreen, size: 40),
              const SizedBox(height: 12),
              const Text('Unable to load live vendor information',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(firebaseMessage(error), textAlign: TextAlign.center),
            ],
          )));
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: accounts,
          builder: (context, users) {
            if (users.hasError) return failure(users.error!);
            if (!users.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: businesses,
                builder: (context, shops) {
                  if (shops.hasError) return failure(shops.error!);
                  if (!shops.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final byId = {
                    for (final shop in shops.data!.docs) shop.id: shop.data()
                  };
                  return widget.builder(context, [
                    for (final user in users.data!.docs)
                      ManagedVendor(
                          id: user.id,
                          profile: user.data(),
                          business: byId[user.id] ?? const {}),
                  ]);
                });
          });
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final VendorStatus status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VendorStatus.pending => const Color(0xFF8A610B),
      VendorStatus.approved => managementGreen,
      VendorStatus.revoked => const Color(0xFF9C3E35),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(20)),
        child: Text(status.label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)));
  }
}

class VendorApprovalDialog extends StatefulWidget {
  const VendorApprovalDialog(
      {super.key,
      required this.vendorName,
      required this.approve,
      this.reapproval = false});
  final String vendorName;
  final bool approve, reapproval;
  @override
  State<VendorApprovalDialog> createState() => _VendorApprovalDialogState();
}

class _VendorApprovalDialogState extends State<VendorApprovalDialog> {
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.approve
            ? widget.reapproval
                ? 'Approve this vendor again?'
                : 'Approve vendor?'
            : 'Revoke vendor approval?'),
        content: SingleChildScrollView(
            child: Form(
                key: form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.vendorName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text(widget.approve
                          ? 'This vendor can publish food and accept new reservations. Their shop can appear on the customer map once its location is configured.'
                          : 'This stops new listings and new reservations and removes the shop from the customer map. Existing orders are kept.'),
                      if (!widget.approve) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: reason,
                            maxLength: 300,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                                labelText: 'Reason for revoking',
                                hintText:
                                    'Explain why approval is being revoked.'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter a reason.'
                                    : value.trim().length > 300
                                        ? 'Use 300 characters or fewer.'
                                        : null),
                      ],
                    ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go back')),
          FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(
                      context, widget.approve ? '' : reason.text.trim());
                }
              },
              child:
                  Text(widget.approve ? 'Approve vendor' : 'Revoke approval')),
        ],
      );
}

class VendorManagementScreen extends StatefulWidget {
  const VendorManagementScreen({super.key, required this.service});
  final FoodieService service;
  @override
  State<VendorManagementScreen> createState() => _VendorManagementScreenState();
}

class _VendorManagementScreenState extends State<VendorManagementScreen> {
  final search = TextEditingController();
  final busy = <String>{};
  VendorStatus? filter;
  String query = '';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> changeApproval(ManagedVendor vendor, bool approve) async {
    final reason = await showDialog<String>(
        context: context,
        builder: (_) => VendorApprovalDialog(
            vendorName: vendor.businessName ?? vendor.name,
            approve: approve,
            reapproval: vendor.status == VendorStatus.revoked));
    if (reason == null || !mounted) return;
    setState(() => busy.add(vendor.id));
    try {
      await widget.service
          .setVendorApproval(vendor.id, approved: approve, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve
                ? 'Vendor approved.'
                : 'Approval revoked. Existing orders are kept.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(firebaseMessage(error))));
      }
    } finally {
      if (mounted) setState(() => busy.remove(vendor.id));
    }
  }

  void showDetails(ManagedVendor vendor) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: managementCream,
        builder: (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .75,
            minChildSize: .4,
            maxChildSize: .95,
            builder: (context, controller) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      Text(vendor.businessName ?? vendor.name,
                          style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: managementInk)),
                      const SizedBox(height: 12),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: _StatusBadge(vendor.status)),
                      const SizedBox(height: 20),
                      ManagementCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _detail('Account name', vendor.name),
                            _detail('Email', vendor.email ?? 'Not provided'),
                            _detail('Business name',
                                vendor.businessName ?? 'Not provided'),
                            _detail('Pickup address',
                                vendor.address ?? 'Not provided'),
                            if (vendor.hasMapPin) ...[
                              _detail(
                                  'Latitude',
                                  (vendor.business['latitude'] as num)
                                      .toStringAsFixed(6)),
                              _detail(
                                  'Longitude',
                                  (vendor.business['longitude'] as num)
                                      .toStringAsFixed(6)),
                            ] else
                              _detail('Map location', 'Not configured'),
                            _detail(
                                'Customer map',
                                vendor.visibleOnMap
                                    ? 'Shop is visible on the map.'
                                    : 'Shop is not visible. Approval and a configured location are required.'),
                            if (vendor.status == VendorStatus.revoked)
                              _detail(
                                  'Revocation reason',
                                  ManagedVendor._nonEmpty(
                                          vendor.profile['revocationReason']) ??
                                      'Not provided'),
                          ])),
                      const Text(
                          'Revoking approval stops new listings and reservations. Existing order records are kept.',
                          style: TextStyle(height: 1.5)),
                      const SizedBox(height: 20),
                      OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close')),
                    ])),
      );
  Widget _detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value),
      ]));
  @override
  Widget build(BuildContext context) => _VendorData(
      service: widget.service,
      builder: (context, records) {
        final summary = VendorSummary(records);
        final visible =
            filterManagedVendors(records, status: filter, search: query);
        return ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Vendor management',
              style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: managementInk)),
          const SizedBox(height: 8),
          const Text('Review applications and manage vendor access.'),
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                  avatar: const Icon(Icons.cloud_done_outlined, size: 18),
                  label: Text('LIVE · ${summary.total} vendors'))),
          const SizedBox(height: 8),
          TextField(
              controller: search,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                  labelText: 'Search name, shop or email',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            search.clear();
                            setState(() => query = '');
                          }))),
          const SizedBox(height: 12),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text('All (${summary.total})'),
                        selected: filter == null,
                        onSelected: (_) => setState(() => filter = null))),
                for (final status in VendorStatus.values)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          label: Text('${status.label} (${switch (status) {
                            VendorStatus.pending => summary.pending,
                            VendorStatus.approved => summary.approved,
                            VendorStatus.revoked => summary.revoked
                          }})'),
                          selected: filter == status,
                          onSelected: (_) => setState(() => filter = status))),
              ])),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            ManagementCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      records.isEmpty
                          ? 'No vendor applications yet'
                          : 'No matching vendors',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(records.isEmpty
                      ? 'Registered vendors will appear here automatically after completing their account setup.'
                      : 'Try another status or clear your search.'),
                  if (records.isNotEmpty)
                    TextButton(
                        onPressed: () {
                          search.clear();
                          setState(() {
                            query = '';
                            filter = null;
                          });
                        },
                        child: const Text('Clear filters')),
                ])),
          for (final vendor in visible)
            ManagementCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text(vendor.businessName ?? vendor.name,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: managementInk)),
                  if (vendor.businessName != null) Text(vendor.name),
                  if (vendor.email != null) Text(vendor.email!),
                  const SizedBox(height: 10),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusBadge(vendor.status)),
                  const SizedBox(height: 8),
                  Text(vendor.address ??
                      'Business pickup details not provided yet.'),
                  if (vendor.status == VendorStatus.revoked &&
                      ManagedVendor._nonEmpty(
                              vendor.profile['revocationReason']) !=
                          null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            'Reason: ${vendor.profile['revocationReason']}')),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    OutlinedButton.icon(
                        onPressed: () => showDetails(vendor),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('View details')),
                    if (vendor.status == VendorStatus.approved)
                      OutlinedButton(
                          onPressed: busy.contains(vendor.id)
                              ? null
                              : () => changeApproval(vendor, false),
                          child: const Text('Revoke approval'))
                    else
                      FilledButton(
                          onPressed: busy.contains(vendor.id)
                              ? null
                              : () => changeApproval(vendor, true),
                          child: Text(vendor.status == VendorStatus.revoked
                              ? 'Approve again'
                              : 'Approve vendor')),
                  ]),
                  if (busy.contains(vendor.id))
                    const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator()),
                ])),
        ]);
      });
}

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen(
      {super.key,
      required this.service,
      required this.onReviewVendors,
      required this.onAdministrators});
  final FoodieService service;
  final VoidCallback onReviewVendors, onAdministrators;
  @override
  Widget build(BuildContext context) => _VendorData(
      service: service,
      builder: (context, records) => AdminOverviewContent(
          summary: VendorSummary(records),
          onReviewVendors: onReviewVendors,
          onAdministrators: onAdministrators));
}

class AdminOverviewContent extends StatelessWidget {
  const AdminOverviewContent(
      {super.key,
      required this.summary,
      required this.onReviewVendors,
      required this.onAdministrators});
  final VendorSummary summary;
  final VoidCallback onReviewVendors, onAdministrators;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Dashboard overview',
            style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: managementInk)),
        const SizedBox(height: 8),
        const Text('Manage your vendors and administration team.'),
        const SizedBox(height: 12),
        const Align(
            alignment: Alignment.centerLeft,
            child: Chip(
                avatar: Icon(Icons.cloud_done_outlined, size: 18),
                label: Text('LIVE · Firebase data'))),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 700 ? 2 : 4;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(spacing: 12, children: [
            for (final metric in [
              ('Pending review', summary.pending),
              ('Approved vendors', summary.approved),
              ('Revoked vendors', summary.revoked),
              ('Shops with map pin', summary.shopsWithMapPin)
            ])
              SizedBox(
                  width: width,
                  child: ManagementCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(metric.$1,
                            style: const TextStyle(color: Color(0xFF64766A))),
                        const SizedBox(height: 14),
                        Text('${metric.$2}',
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: managementGreen)),
                      ]))),
          ]);
        }),
        const SizedBox(height: 12),
        ManagementCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              summary.pending == 0
                  ? 'Vendor applications are up to date'
                  : '${summary.pending} vendors awaiting review',
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
              'Review business details, approve applications or revoke access when necessary.'),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: onReviewVendors,
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Review vendors')),
        ])),
        ManagementCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Administration team',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
              'Manage separate administrator accounts for the people who review your vendors.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: onAdministrators,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Manage administrators')),
        ])),
      ]);
}
