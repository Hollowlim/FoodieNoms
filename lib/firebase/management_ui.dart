import 'package:flutter/material.dart';

const managementGreen = Color(0xFF153F2F);
const managementCream = Color(0xFFFBFAF5);
const managementInk = Color(0xFF20372B);

class ManagementCard extends StatelessWidget {
  const ManagementCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD0DFD3))),
      child: Material(type: MaterialType.transparency, child: child));
}

class VendorBanner extends StatelessWidget {
  const VendorBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      color: managementGreen,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vendor Center • Subang Jaya',
            style: TextStyle(color: Color(0xFFC7DFCE))),
        SizedBox(height: 22),
        Text('Good afternoon, partner!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800)),
      ]));
}

/// Bottom navigation for admin sections, with overflow in a More sheet.
class AdminLayout extends StatelessWidget {
  const AdminLayout(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onSelected,
      required this.onSignOut,
      required this.child});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;
  final Widget child;

  IconData iconFor(String label) => switch (label) {
        'Overview' => Icons.dashboard_outlined,
        'Students' => Icons.people_outline,
        'Vendors' => Icons.storefront_outlined,
        'Listings' => Icons.restaurant_menu,
        'Reservations' => Icons.receipt_long_outlined,
        'Reports' => Icons.bar_chart_outlined,
        'Notifications' => Icons.notifications_outlined,
        'Settings' => Icons.settings_outlined,
        'Profile' => Icons.person_outline,
        _ => Icons.history,
      };

  List<int> get primaryIndices => labels.length <= 5
      ? List.generate(labels.length, (i) => i)
      : ['Overview', 'Vendors', 'Listings', 'Reservations']
          .map(labels.indexOf)
          .where((i) => i >= 0)
          .toList();

  Future<void> showMore(BuildContext context, List<int> primary) async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: managementCream,
      builder: (context) => SafeArea(
          child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('More admin tools',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
          for (var i = 0; i < labels.length; i++)
            if (!primary.contains(i))
              ListTile(
                leading: Icon(iconFor(labels[i]), color: managementGreen),
                title: Text(labels[i]),
                selected: selected == i,
                selectedColor: managementGreen,
                trailing: selected == i ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, i),
              ),
        ]),
      )),
    );
    if (choice != null && context.mounted) onSelected(choice);
  }

  @override
  Widget build(BuildContext context) {
    final primary = primaryIndices;
    final overflow = primary.length < labels.length;
    final primarySelection = primary.indexOf(selected);
    return Scaffold(
      backgroundColor: managementCream,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FoodieNoms',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('Admin console',
                  style: TextStyle(fontSize: 11, color: Color(0xFFC7DFCE))),
            ]),
        actions: [
          IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout))
        ],
        backgroundColor: managementGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE2EEDB),
        selectedIndex:
            primarySelection >= 0 ? primarySelection : primary.length,
        onDestinationSelected: (index) {
          if (index == primary.length) {
            showMore(context, primary);
          } else {
            onSelected(primary[index]);
          }
        },
        destinations: [
          for (final index in primary)
            NavigationDestination(
                icon: Icon(iconFor(labels[index])), label: labels[index]),
          if (overflow)
            const NavigationDestination(
                icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
