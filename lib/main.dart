import 'package:flutter/material.dart';
import 'firebase/app.dart';

Future<void> main() async {
  if (const bool.fromEnvironment('DEMO_MODE')) {
    runApp(const FoodieNomsApp());
  } else {
    await launchFirebaseApp();
  }
}

const deepGreen = Color(0xFF153D29);
const primaryGreen = Color(0xFF2D7349);
const cream = Color(0xFFFFFCF5);
const paleGreen = Color(0xFFE8F2E4);

String rm(double price) => 'RM ${price.toStringAsFixed(2)}';

class Deal {
  Deal(
      {required this.id,
      required this.name,
      required this.vendor,
      required this.category,
      required this.description,
      required this.price,
      required this.originalPrice,
      required this.stock,
      required this.pickup,
      required this.emoji});
  final String id, name, vendor, category, description, pickup, emoji;
  final double price, originalPrice;
  int stock;
}

class Booking {
  Booking({required this.code, required this.deal, required this.quantity});
  final String code;
  final Deal deal;
  final int quantity;
  bool collected = false;
}

class DemoStore extends ChangeNotifier {
  final deals = <Deal>[
    Deal(
        id: 'bag',
        name: 'Bakery Surprise Bag',
        vendor: 'Sample Bakery',
        category: 'Bakery',
        description:
            'A delicious selection of freshly baked breads and pastries. The exact contents are a surprise!',
        price: 8,
        originalPrice: 20,
        stock: 4,
        pickup: '5:00 PM – 7:00 PM',
        emoji: '🥐'),
    Deal(
        id: 'lunch',
        name: 'Cafe Lunch Box',
        vendor: 'Sample Bakery',
        category: 'Meals',
        description:
            'A satisfying cafe lunch, freshly prepared and packed for your afternoon.',
        price: 9.90,
        originalPrice: 18,
        stock: 3,
        pickup: '4:00 PM – 6:00 PM',
        emoji: '🍱'),
    Deal(
        id: 'pastry',
        name: 'Pastry Selection',
        vendor: 'Sample Bakery',
        category: 'Pastries',
        description:
            'A box of sweet moments with a selection of remaining daily pastries.',
        price: 6.50,
        originalPrice: 15,
        stock: 5,
        pickup: '6:00 PM – 8:00 PM',
        emoji: '🧁'),
  ];
  final bookings = <Booking>[];
  bool vendorApproved = false;
  int _nextCode = 10001;

  String? reserve(Deal deal, int quantity) {
    if (quantity < 1 || deal.stock < quantity) return null;
    deal.stock -= quantity;
    final code = 'FN-${_nextCode++}';
    bookings.add(Booking(code: code, deal: deal, quantity: quantity));
    notifyListeners();
    return code;
  }

  void approveVendor() {
    vendorApproved = true;
    notifyListeners();
  }

  void addDeal(String title, double price, int quantity) {
    if (!vendorApproved ||
        title.trim().isEmpty ||
        !price.isFinite ||
        price <= 0 ||
        quantity < 1) {
      return;
    }
    deals.add(Deal(
        id: 'new-${deals.length}',
        name: title.trim(),
        vendor: 'Subang Cafe',
        category: 'Meals',
        description: 'Fresh surplus food available for pickup today.',
        price: price,
        originalPrice: price * 1.6,
        stock: quantity,
        pickup: '5:00 PM – 7:00 PM',
        emoji: '🥡'));
    notifyListeners();
  }

  bool collect(String code) {
    for (final booking in bookings) {
      if (booking.code.toUpperCase() == code.trim().toUpperCase() &&
          !booking.collected) {
        booking.collected = true;
        notifyListeners();
        return true;
      }
    }
    return false;
  }
}

class FoodieNomsApp extends StatefulWidget {
  const FoodieNomsApp({super.key});
  @override
  State<FoodieNomsApp> createState() => _FoodieNomsAppState();
}

class _FoodieNomsAppState extends State<FoodieNomsApp> {
  final store = DemoStore();
  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodieNoms',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: cream,
          colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
          appBarTheme: const AppBarTheme(
              backgroundColor: cream, foregroundColor: deepGreen),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)))),
          cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE3E8E1))))),
      home: RoleHome(store: store),
    );
  }
}

class RoleHome extends StatefulWidget {
  const RoleHome({super.key, required this.store});
  final DemoStore store;
  @override
  State<RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends State<RoleHome> {
  int tab = 0;
  String role = 'Student';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('FoodieNoms',
                style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Switch demo role',
                initialValue: role,
                onSelected: (value) => setState(() {
                  role = value;
                  tab = 0;
                }),
                itemBuilder: (_) => ['Student', 'Vendor', 'Admin']
                    .map((value) =>
                        PopupMenuItem(value: value, child: Text('$value demo')))
                    .toList(),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Text('$role demo'),
                      const Icon(Icons.expand_more, size: 18)
                    ])),
              )
            ],
          ),
          body: SafeArea(
              child: role == 'Vendor'
                  ? VendorView(store: widget.store)
                  : role == 'Admin'
                      ? AdminView(store: widget.store)
                      : tab == 0
                          ? StudentView(store: widget.store)
                          : tab == 1
                              ? PickupsView(store: widget.store)
                              : const ProfileView()),
          bottomNavigationBar: role != 'Student'
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (value) => setState(() => tab = value),
                  destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore),
                          label: 'Explore'),
                      NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: 'My Pickups'),
                      NavigationDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: 'Profile'),
                    ]),
        ),
      );
}

class StudentView extends StatefulWidget {
  const StudentView({super.key, required this.store});
  final DemoStore store;
  @override
  State<StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends State<StudentView> {
  String search = '';
  String category = 'All';
  @override
  Widget build(BuildContext context) {
    final results = widget.store.deals
        .where((d) =>
            (category == 'All' || d.category == category) &&
            '${d.name} ${d.category} ${d.vendor}'
                .toLowerCase()
                .contains(search.toLowerCase()))
        .toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Row(children: [
        Icon(Icons.location_on_outlined, color: primaryGreen),
        SizedBox(width: 6),
        Expanded(
            child: Text('Discover in Subang Jaya',
                style: TextStyle(fontWeight: FontWeight.w600)))
      ]),
      const SizedBox(height: 20),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: deepGreen, borderRadius: BorderRadius.circular(24)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Good food.\nA little less waste.',
                style: TextStyle(
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 12),
            const Text('Find surplus favourites at student-friendly prices.',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 16),
            Row(children: [
              Image.asset('assets/foodienoms_logo.png', width: 48, height: 48),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Save a meal. Make your day.',
                      style: TextStyle(color: Colors.white)))
            ])
          ])),
      const SizedBox(height: 24),
      TextField(
          decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search food or vendors',
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
          onChanged: (value) => setState(() => search = value)),
      const SizedBox(height: 12),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: [
            'All',
            ...widget.store.deals.map((d) => d.category).toSet()
          ]
                  .map((value) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          label: Text(value),
                          selected: category == value,
                          onSelected: (_) => setState(() => category = value))))
                  .toList())),
      const SizedBox(height: 20),
      const Text('Find your next pickup',
          style: TextStyle(
              fontSize: 23, fontWeight: FontWeight.bold, color: deepGreen)),
      const SizedBox(height: 6),
      Text('${results.length} demo deals · Pickup times shown on each listing',
          style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 16),
      if (results.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No meals match yet. Try another search or category.')),
      ...results.map((d) => Card(
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          DealDetails(store: widget.store, deal: d))),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: paleGreen,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Text(d.emoji,
                                  style: const TextStyle(fontSize: 34))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(d.vendor,
                                    style: const TextStyle(
                                        color: primaryGreen,
                                        fontWeight: FontWeight.w600)),
                                Text(d.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18))
                              ]))
                        ]),
                        const SizedBox(height: 14),
                        Text('Pickup · ${d.pickup}'),
                        const SizedBox(height: 12),
                        Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(rm(d.price),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      color: primaryGreen,
                                      fontWeight: FontWeight.w800)),
                              Text(rm(d.originalPrice),
                                  style: const TextStyle(
                                      color: Colors.black54,
                                      decoration: TextDecoration.lineThrough)),
                              Text(
                                  d.stock == 0
                                      ? 'Sold out'
                                      : '${d.stock} available',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ])
                      ]))))),
      const Text('Demo experience · Reservations reset when the app restarts.',
          style: TextStyle(color: Colors.black54, fontSize: 12)),
    ]);
  }
}

class PickupsView extends StatelessWidget {
  const PickupsView({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        const Text('My Pickups',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: deepGreen)),
        const SizedBox(height: 8),
        const Text('Your reserved meals, ready when you are.'),
        const SizedBox(height: 24),
        if (store.bookings.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 48, color: primaryGreen),
                    SizedBox(height: 16),
                    Text('Your first rescue starts here',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                        'Visit Explore to find a meal and reserve your pickup.',
                        textAlign: TextAlign.center)
                  ]))),
        ...store.bookings.reversed.map((b) => Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.collected ? 'COLLECTED' : 'RESERVED',
                          style: const TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(b.deal.name,
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.bold)),
                      Text(b.deal.vendor),
                      const SizedBox(height: 12),
                      Text('Pickup · ${b.deal.pickup}'),
                      Text(
                          'Quantity ${b.quantity} · ${rm(b.deal.price * b.quantity)}'),
                      const Divider(height: 28),
                      SelectableText(b.code,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Text(b.collected
                          ? 'Thanks for saving a meal!'
                          : 'Show this code to the vendor at collection.'),
                      const SizedBox(height: 8),
                      const Text('Demo reservation · No payment processed',
                          style: TextStyle(color: Colors.black54)),
                    ])))),
      ]);
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: const [
        Text('Your FoodieNoms',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: deepGreen)),
        SizedBox(height: 24),
        Card(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.person_outline, size: 44, color: primaryGreen),
                      SizedBox(height: 12),
                      Text('Student demo',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                          'Explore FoodieNoms without creating an account. Your activity is stored only for this session.')
                    ]))),
        SizedBox(height: 20),
        Text('How pickup works',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.explore_outlined),
            title: Text('Find a meal'),
            subtitle: Text('Check the price, availability and pickup window.')),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.confirmation_number_outlined),
            title: Text('Reserve your pickup'),
            subtitle: Text('Your pickup code appears in My Pickups.')),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.storefront_outlined),
            title: Text('Collect from the vendor'),
            subtitle: Text('Show your code during the listed pickup window.')),
        SizedBox(height: 16),
        Text('About this prototype',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text(
            'Listings and vendors are examples. Real login, payments, addresses and customer support are not connected yet. Use the top-right menu to preview vendor and admin tools.'),
      ]);
}

class DealDetails extends StatefulWidget {
  const DealDetails({super.key, required this.store, required this.deal});
  final DemoStore store;
  final Deal deal;
  @override
  State<DealDetails> createState() => _DealDetailsState();
}

class _DealDetailsState extends State<DealDetails> {
  int quantity = 1;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final d = widget.deal;
        return Scaffold(
            appBar: AppBar(title: const Text('Food details')),
            body: SafeArea(
                child: ListView(padding: const EdgeInsets.all(20), children: [
              Container(
                  height: 190,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: paleGreen,
                      borderRadius: BorderRadius.circular(24)),
                  child: Text(d.emoji, style: const TextStyle(fontSize: 96))),
              const SizedBox(height: 20),
              Text(d.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 27,
                      color: deepGreen)),
              const SizedBox(height: 8),
              Text(d.vendor),
              const SizedBox(height: 16),
              Text(rm(d.price),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen)),
              Text('Original ${rm(d.originalPrice)}',
                  style:
                      const TextStyle(decoration: TextDecoration.lineThrough)),
              const SizedBox(height: 16),
              Text(d.description),
              const SizedBox(height: 15),
              Text('Pickup window: ${d.pickup}'),
              const SizedBox(height: 12),
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'Before you reserve\n\nSample listing: pickup date and address are not configured. Contents may vary; dietary and allergen details are not verified. Ask the vendor before consuming. This demo creates no real order or payment.'))),
              Text('Stock remaining: ${d.stock}'),
              const SizedBox(height: 20),
              Row(children: [
                const Text('Quantity',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed:
                        quantity > 1 ? () => setState(() => quantity--) : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$quantity'),
                IconButton(
                    onPressed: quantity < d.stock
                        ? () => setState(() => quantity++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline))
              ]),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: d.stock >= quantity
                      ? () {
                          final code = widget.store.reserve(d, quantity);
                          if (code == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'This quantity is no longer available.')));
                            return;
                          }
                          showDialog<void>(
                              context: context,
                              builder: (c) => AlertDialog(
                                      title: const Text('Pickup reserved!'),
                                      content: Text(
                                          'Demo pickup code: $code\nFind it again in My Pickups and show it to the vendor at collection.\n\nNo payment has been processed.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              Navigator.pop(c);
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Done'))
                                      ]));
                        }
                      : null,
                  child: Text(d.stock == 0
                      ? 'Sold out'
                      : 'Reserve · ${rm(d.price * quantity)}')),
            ])));
      });
}

class VendorView extends StatefulWidget {
  const VendorView({super.key, required this.store});
  final DemoStore store;
  @override
  State<VendorView> createState() => _VendorViewState();
}

class _VendorViewState extends State<VendorView> {
  final title = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();
  final code = TextEditingController();
  @override
  void dispose() {
    title.dispose();
    price.dispose();
    stock.dispose();
    code.dispose();
    super.dispose();
  }

  void message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Vendor dashboard',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 24, color: deepGreen)),
        const SizedBox(height: 8),
        const Text('Subang Cafe · Demo account'),
        const SizedBox(height: 12),
        Card(
            child: ListTile(
                title: const Text('Approval status'),
                subtitle: Text(widget.store.vendorApproved
                    ? 'Approved — create listings below'
                    : 'Pending admin approval'),
                trailing: Icon(
                    widget.store.vendorApproved
                        ? Icons.check_circle
                        : Icons.hourglass_empty,
                    color: widget.store.vendorApproved
                        ? primaryGreen
                        : Colors.orange))),
        const SizedBox(height: 20),
        const Text('Publish a surplus listing',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        if (!widget.store.vendorApproved)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child:
                  Text('An admin must approve this vendor before publishing.')),
        TextField(
            controller: title,
            enabled: widget.store.vendorApproved,
            decoration: const InputDecoration(labelText: 'Food name')),
        TextField(
            controller: price,
            enabled: widget.store.vendorApproved,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Discounted price (RM)')),
        TextField(
            controller: stock,
            enabled: widget.store.vendorApproved,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Available quantity')),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: widget.store.vendorApproved
                ? () {
                    final p = double.tryParse(price.text);
                    final q = int.tryParse(stock.text);
                    if (title.text.trim().isEmpty ||
                        p == null ||
                        !p.isFinite ||
                        p <= 0 ||
                        q == null ||
                        q <= 0) {
                      message(
                          'Enter a food name, positive price and quantity.');
                      return;
                    }
                    widget.store.addDeal(title.text, p, q);
                    title.clear();
                    price.clear();
                    stock.clear();
                    message('Demo listing published.');
                  }
                : null,
            child: const Text('Publish listing')),
        const SizedBox(height: 25),
        const Text('Confirm student pickup',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        TextField(
            controller: code,
            decoration: const InputDecoration(
                labelText: 'Pickup code (e.g. FN-10001)')),
        const SizedBox(height: 10),
        FilledButton.tonal(
            onPressed: () {
              final successful = widget.store.collect(code.text);
              message(successful
                  ? 'Pickup confirmed.'
                  : 'Invalid or already-used pickup code.');
            },
            child: const Text('Verify collection')),
      ]);
}

class AdminView extends StatelessWidget {
  const AdminView({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Admin overview',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 24, color: deepGreen)),
        const SizedBox(height: 8),
        const Text('Demo administration · no secure authentication connected'),
        const SizedBox(height: 16),
        Card(
            child: ListTile(
                title: const Text('Vendor application: Subang Cafe'),
                subtitle: Text(
                    store.vendorApproved ? 'Approved' : 'Pending approval'),
                trailing: store.vendorApproved
                    ? const Icon(Icons.verified, color: primaryGreen)
                    : FilledButton(
                        onPressed: store.approveVendor,
                        child: const Text('Approve')))),
        Card(
            child: ListTile(
                title: const Text('Active sample listings'),
                trailing: Text('${store.deals.length}'))),
        Card(
            child: ListTile(
                title: const Text('Total reservations'),
                trailing: Text('${store.bookings.length}'))),
        Card(
            child: ListTile(
                title: const Text('Collected orders'),
                trailing: Text(
                    '${store.bookings.where((b) => b.collected).length}'))),
        const SizedBox(height: 15),
        const Text(
            'In production, admin permissions must be checked on the server, not by these demo tabs.',
            style: TextStyle(color: Colors.black54)),
      ]);
}
