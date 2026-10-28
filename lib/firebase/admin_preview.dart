import 'package:flutter/material.dart';
import 'management_ui.dart';

/// Local UI preview only. This route never grants Firebase permissions.
class AdminPreview extends StatefulWidget {
  const AdminPreview({super.key});
  @override
  State<AdminPreview> createState() => _AdminPreviewState();
}

class _AdminPreviewState extends State<AdminPreview> {
  int tab = 0;
  static const labels = [
    'Overview',
    'Students',
    'Vendors',
    'Listings',
    'Reservations',
    'Reports',
    'Notifications',
    'Settings',
    'Activity'
  ];
  static const titles = [
    'Dashboard Overview',
    'Student Management',
    'Vendor Approvals',
    'Food Listing Moderation',
    'Reservation Oversight',
    'Reports & Insights',
    'Notifications',
    'Platform Settings',
    'Activity Log'
  ];
  final vendors = <String, String>{
    'Subang Cafe': 'Pending',
    'Sample Bakery': 'Approved',
    'Campus Bistro': 'Pending'
  };
  final activity = <String>[];
  final hidden = <String>{};
  void review(String vendor, String status) => setState(() {
        vendors[vendor] = status;
        activity.insert(0, '$vendor · $status');
      });
  Widget entry(String title, String subtitle, {VoidCallback? onTap}) =>
      ManagementCard(
          child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(subtitle),
              trailing: onTap == null ? null : const Icon(Icons.chevron_right),
              onTap: onTap));
  Widget status(String value) {
    final pending = value == 'Pending';
    final rejected = value == 'Rejected' || value == 'Hidden';
    final color = pending
        ? const Color(0xFF8A610B)
        : rejected
            ? const Color(0xFF9C3E35)
            : managementGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(20)),
      child: Text(value,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget metric(String title, String value) => ManagementCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF64766A))),
        const SizedBox(height: 12),
        Text(value,
            style: const TextStyle(
                fontSize: 30,
                color: Color(0xFF236D4E),
                fontWeight: FontWeight.w800)),
      ]));
  Widget metrics() => LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, children: [
          SizedBox(width: width, child: metric('Students', '3')),
          SizedBox(width: width, child: metric('Vendors', '${vendors.length}')),
          SizedBox(
              width: width,
              child: metric('Active deals', '${3 - hidden.length}')),
          SizedBox(width: width, child: metric('Reservations', '3')),
        ]);
      });
  List<Widget> content() {
    switch (tab) {
      case 0:
        return [
          metrics(),
          ManagementCard(
              child: Row(children: [
            const Icon(Icons.pending_actions, color: managementGreen),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    '${vendors.values.where((v) => v == 'Pending').length} vendors awaiting review',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            TextButton(
                onPressed: () => setState(() => tab = 2),
                child: const Text('Review')),
          ])),
          const SizedBox(height: 20),
          const Text('Platform overview',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          entry('Vendor approvals', 'Pending business applications',
              onTap: () => setState(() => tab = 2)),
          entry('Listings moderation', 'Review food offers',
              onTap: () => setState(() => tab = 3)),
          entry('Reservation oversight', 'Review order status',
              onTap: () => setState(() => tab = 4)),
          entry('Reports and activity', 'Track platform operations',
              onTap: () => setState(() => tab = 5)),
          FilledButton(
              onPressed: () => setState(() => tab = 2),
              child: const Text('Review vendor applications')),
        ];
      case 1:
        return [
          for (final student in ['Student 001', 'Student 002', 'Student 003'])
            entry(student, 'Active · Sample student account')
        ];
      case 2:
        return [
          for (final v in vendors.entries)
            ManagementCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(v.key,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  status(v.value),
                  const SizedBox(height: 8),
                  const Text('Subang Jaya • Food vendor',
                      style: TextStyle(color: Color(0xFF64766A))),
                  const SizedBox(height: 12),
                  if (v.value == 'Pending')
                    Wrap(spacing: 8, children: [
                      FilledButton(
                          onPressed: () => review(v.key, 'Approved'),
                          child: const Text('Approve')),
                      OutlinedButton(
                          onPressed: () => review(v.key, 'Rejected'),
                          child: const Text('Reject'))
                    ]),
                ]))
        ];
      case 3:
        return [
          for (final name in [
            'Bakery Surprise Bag',
            'Lunch Box',
            'Pastry Selection'
          ])
            ManagementCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  status(hidden.contains(name) ? 'Hidden' : 'Active'),
                  TextButton(
                      onPressed: () => setState(() {
                            if (!hidden.remove(name)) {
                              hidden.add(name);
                            }
                            activity.insert(0,
                                '$name · ${hidden.contains(name) ? 'Hidden' : 'Restored'}');
                          }),
                      child: Text(hidden.contains(name)
                          ? 'Restore listing'
                          : 'Hide listing'))
                ]))
        ];
      case 4:
        return [
          entry('FN-001 · Bakery Bag', 'Reserved · Sample Bakery'),
          entry('FN-002 · Lunch Box', 'Collected · Sample Bakery'),
          entry('FN-003 · Pastry Pack', 'Cancelled · Sample Bakery')
        ];
      case 5:
        return [
          metric('Reservations', '3'),
          metric('Collected orders', '1'),
          entry('Food listings by category', 'Bakery 1 · Meals 1 · Pastries 1'),
          entry('Report data',
              'Illustrative sample figures for this demo session.')
        ];
      case 6:
        return [
          entry('Vendor applications',
              '${vendors.values.where((v) => v == 'Pending').length} awaiting review',
              onTap: () => setState(() => tab = 2)),
          entry('Listing moderation', '${hidden.length} sample listings hidden',
              onTap: () => setState(() => tab = 3))
        ];
      case 7:
        return [
          entry('Service area', 'Subang Jaya, Selangor'),
          entry('Vendor approval', 'Required before publishing'),
          entry('Pickup policy', 'Reserve online · Pay at pickup'),
          entry('Demo session', 'These settings are a read-only preview.')
        ];
      default:
        return activity.isEmpty
            ? [
                entry('No demo actions yet',
                    'Review a vendor to see activity here.')
              ]
            : [
                for (final event in activity)
                  entry(event, 'Demo administrator · This session')
              ];
    }
  }

  @override
  Widget build(BuildContext context) => AdminLayout(
      labels: labels,
      selected: tab,
      onSelected: (i) => setState(() => tab = i),
      onSignOut: () => Navigator.pop(context),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('ADMIN WORKSPACE',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                color: Color(0xFF64766A),
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(titles[tab],
            style: const TextStyle(
                fontSize: 28,
                color: managementInk,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Subang Jaya pilot • Sample data'),
        const SizedBox(height: 12),
        const Align(
            alignment: Alignment.centerLeft,
            child: Chip(
                avatar: Icon(Icons.science_outlined, size: 16),
                label: Text('Demo workspace · Sample data'))),
        const SizedBox(height: 24),
        ...content(),
      ]));
}
