import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import 'service.dart';
import 'customer_preview.dart';
import 'student_ui.dart';
import 'reference_assets.dart';
import 'live_location_map.dart';
import 'admin_preview.dart';
import 'management_ui.dart';

const _adminDemoUsername = String.fromEnvironment('ADMIN_DEMO_USERNAME');
const _adminDemoPassword = String.fromEnvironment('ADMIN_DEMO_PASSWORD');

const _green = Color(0xFF153D29);
const _cream = Color(0xFFFFFCF5);

Future<void> launchFirebaseApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    runApp(const ConnectedFoodieApp());
  } catch (_) {
    runApp(const FirebaseSetupApp());
  }
}

class FirebaseSetupApp extends StatelessWidget {
  const FirebaseSetupApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            backgroundColor: _cream,
            body: SafeArea(
                child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const BrandLogo(width: 160, backgroundColor: _cream),
                    const SizedBox(height: 24),
                    const Text('Connect FoodieNoms to Firebase',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: _green)),
                    const SizedBox(height: 16),
                    const Text(
                        'Firebase setup is incomplete or initialization failed. Create a Firebase project and follow docs/FIREBASE_SETUP.md. Then rebuild the app.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    const Text(
                        'The offline preview is still available with:\nflutter run --dart-define=DEMO_MODE=true',
                        textAlign: TextAlign.center),
                  ])),
            ))),
      );
}

class ConnectedFoodieApp extends StatelessWidget {
  const ConnectedFoodieApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FoodieNoms',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: studentCream,
          colorScheme: ColorScheme.fromSeed(seedColor: _green),
          appBarTheme: const AppBarTheme(
              backgroundColor: studentCream, foregroundColor: studentGreen),
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder()),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48), backgroundColor: _green)),
        ),
        home: const AccountGate(),
      );
}

class AccountGate extends StatefulWidget {
  const AccountGate({super.key});
  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  final service = FoodieService();
  late final users = service.auth.authStateChanges();
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
      stream: users,
      builder: (context, state) {
        if (state.hasError) {
          return _Failure(message: firebaseMessage(state.error!));
        }
        if (state.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final user = state.data;
        if (user == null) return AuthScreen(service: service);
        return ProfileGate(
            key: ValueKey(user.uid), service: service, user: user);
      });
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.service, required this.user});
  final FoodieService service;
  final User user;
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final profile = widget.service.profile(widget.user.uid);
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: profile,
          builder: (context, state) {
            if (state.hasError) {
              return Scaffold(
                  appBar: AppBar(actions: [
                    TextButton(
                        onPressed: widget.service.auth.signOut,
                        child: const Text('Sign out'))
                  ]),
                  body: _Failure(message: firebaseMessage(state.error!)));
            }
            if (!state.hasData) return const _Loading();
            if (!state.data!.exists) {
              return AuthScreen(service: widget.service, completeProfile: true);
            }
            return AccountHome(
                service: widget.service,
                user: widget.user,
                profile: state.data!.data()!);
          });
}

class AuthScreen extends StatefulWidget {
  const AuthScreen(
      {super.key, required this.service, this.completeProfile = false});
  final FoodieService service;
  final bool completeProfile;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  bool register = false;
  bool busy = false;
  String role = 'customer';
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (!register &&
        !widget.completeProfile &&
        _adminDemoUsername.isNotEmpty &&
        _adminDemoPassword.isNotEmpty &&
        email.text.trim() == _adminDemoUsername) {
      if (password.text != _adminDemoPassword) {
        setState(() => error = 'Incorrect admin demo password.');
        return;
      }
      password.clear();
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const AdminPreview()));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.completeProfile) {
        await widget.service.createAccountProfile(name.text, role);
      } else if (register) {
        // AuthGate then opens profile completion. Keeping these two steps
        // separate lets a user retry if the Firestore connection is unavailable.
        await widget.service.auth.createUserWithEmailAndPassword(
            email: email.text.trim(), password: password.text);
      } else {
        await widget.service.auth.signInWithEmailAndPassword(
            email: email.text.trim(), password: password.text);
      }
    } catch (e) {
      if (mounted) setState(() => error = firebaseMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    if (!email.text.contains('@')) {
      setState(() => error = 'Enter your email first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service.auth
          .sendPasswordResetEmail(email: email.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('If an account exists, a reset link will be sent.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = firebaseMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
            key: form,
            child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  const BrandLogo(height: 140),
                  const SizedBox(height: 24),
                  Text(
                      widget.completeProfile
                          ? 'Set up your account'
                          : register
                              ? 'Join FoodieNoms'
                              : 'Welcome back',
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _green)),
                  const SizedBox(height: 12),
                  if (widget.completeProfile) ...[
                    TextFormField(
                        controller: name,
                        enabled: !busy,
                        maxLength: 100,
                        decoration: const InputDecoration(
                            labelText: 'Your name or business name'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter a name.'
                            : null),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration:
                            const InputDecoration(labelText: 'Account type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'customer', child: Text('Customer')),
                          DropdownMenuItem(
                              value: 'vendor', child: Text('Vendor'))
                        ],
                        onChanged:
                            busy ? null : (v) => setState(() => role = v!)),
                    const SizedBox(height: 12),
                    const Text(
                        'Vendors need admin approval before publishing. Account type cannot be changed here.'),
                  ] else ...[
                    TextFormField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                            labelText:
                                register ? 'Email' : 'Email or username'),
                        validator: (v) => !register && _adminDemoUsername.isNotEmpty &&
                                _adminDemoPassword.isNotEmpty &&
                                v?.trim() == _adminDemoUsername
                            ? null
                            : v == null || !v.contains('@')
                                ? 'Enter a valid email.'
                                : null),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: password,
                        enabled: !busy,
                        obscureText: true,
                        autofillHints: register
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                        validator: (v) => v == null ||
                                v.isEmpty ||
                                (register && v.length < 8)
                            ? 'Enter ${register ? 'at least 8 characters' : 'your password'}.'
                            : null),
                  ],
                  const SizedBox(height: 20),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(busy
                          ? 'Please wait…'
                          : widget.completeProfile
                              ? 'Save account'
                              : register
                                  ? 'Create account'
                                  : 'Sign in')),
                  if (!widget.completeProfile) ...[
                    TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  register = !register;
                                  error = null;
                                }),
                        child: Text(register
                            ? 'Already registered? Sign in'
                            : 'New here? Create an account')),
                    if (!register)
                      TextButton(
                          onPressed: busy ? null : resetPassword,
                          child: const Text('Forgot password?')),
                  ] else
                    TextButton(
                        onPressed: busy ? null : widget.service.auth.signOut,
                        child: const Text('Sign out')),
                ])),
      ))));
}

class AccountHome extends StatefulWidget {
  const AccountHome(
      {super.key,
      required this.service,
      required this.user,
      required this.profile});
  final FoodieService service;
  final User user;
  final Map<String, dynamic> profile;
  @override
  State<AccountHome> createState() => _AccountHomeState();
}

class _AccountHomeState extends State<AccountHome> {
  int tab = 0;
  final location = PilotLocation();
  @override
  void dispose() {
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.profile['role'] as String;
    final customer = role == 'customer';
    final lastTab = customer
        ? 3
        : role == 'admin'
            ? 1
            : 2;
    final index = tab.clamp(0, lastTab);
    Widget body;
    if (index == lastTab) {
      body = AccountProfile(
          service: widget.service,
          user: widget.user,
          profile: widget.profile,
          location: location);
    } else if (role == 'admin') {
      body = VendorApprovals(service: widget.service);
    } else if (customer && index == 1) {
      body = CustomerMap(
          service: widget.service, uid: widget.user.uid, location: location);
    } else if ((customer && index == 2) || (!customer && index == 1)) {
      body = CloudPickups(
          service: widget.service,
          uid: widget.user.uid,
          role: role,
          approved: widget.profile['approved'] == true);
    } else {
      body = CloudListings(
          service: widget.service,
          uid: widget.user.uid,
          role: role,
          approved: widget.profile['approved'] == true,
          location: location);
    }
    if (role == 'admin') {
      return AdminLayout(
          labels: const ['Vendors', 'Profile'],
          selected: index,
          onSelected: (value) => setState(() => tab = value),
          onSignOut: widget.service.auth.signOut,
          child: body);
    }
    final discover = customer && index == 0;
    return Scaffold(
        backgroundColor: discover ? studentGreen : studentCream,
        appBar: discover
            ? null
            : AppBar(
                title: const Text('FoodieNoms',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                backgroundColor: role == 'vendor' ? managementGreen : null,
                foregroundColor: role == 'vendor' ? Colors.white : null,
                actions: customer
                    ? null
                    : [
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(role == 'vendor' ? 'Vendor' : 'Admin'))
                      ]),
        body: SafeArea(
            bottom: false, child: ColoredBox(color: studentCream, child: body)),
        bottomNavigationBar: FoodieNavigation(
            role: role,
            selectedIndex: index,
            onSelected: (value) => setState(() => tab = value)));
  }
}

class FoodieNavigation extends StatelessWidget {
  const FoodieNavigation(
      {super.key,
      required this.role,
      required this.selectedIndex,
      required this.onSelected});
  final String role;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    final items = role == 'customer'
        ? [
            ('Home', Icons.home_outlined),
            ('Map', Icons.map_outlined),
            ('Orders', Icons.receipt_long_outlined),
            ('Profile', Icons.person_outline)
          ]
        : role == 'vendor'
            ? [
                ('Listings', Icons.storefront_outlined),
                ('Pickups', Icons.receipt_long_outlined),
                ('Profile', Icons.person_outline)
              ]
            : [
                ('Vendors', Icons.admin_panel_settings_outlined),
                ('Profile', Icons.person_outline)
              ];
    return NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: studentPale,
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: items
            .map((item) =>
                NavigationDestination(icon: Icon(item.$2), label: item.$1))
            .toList());
  }
}

class AccountProfile extends StatelessWidget {
  const AccountProfile(
      {super.key,
      required this.service,
      required this.user,
      required this.profile,
      this.location});
  final PilotLocation? location;
  final FoodieService service;
  final User user;
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) {
    if (profile['role'] == 'customer') {
      void showInfo(String title, Widget child) => Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(title)),
                  body: SafeArea(child: child))));
      Future<void> signOut() async {
        try {
          await service.auth.signOut();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(firebaseMessage(e))));
          }
        }
      }

      return StudentProfilePanel(
          name: profile['name'] as String,
          email: user.email ?? '',
          onPersonalInfo: () => showInfo(
              'Personal information',
              ListView(padding: const EdgeInsets.all(24), children: [
                const Text('Your account',
                    style:
                        TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ListTile(
                    title: const Text('Full name'),
                    subtitle: Text(profile['name'] as String)),
                ListTile(
                    title: const Text('Email address'),
                    subtitle: Text(user.email ?? '')),
                const ListTile(
                    title: Text('Account type'),
                    subtitle: Text('Student / Customer')),
                const SizedBox(height: 16),
                const Text(
                    'Contact details are shown as registered. Profile editing is not available yet.'),
              ])),
          onReviews: () => showInfo(
              'My reviews',
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'No reviews yet. Ratings and reviews will be available in a future update.')))),
          onNotifications: () => showInfo('Notifications',
              CustomerNotifications(service: service, uid: user.uid)),
          onLocation: () {
            if (location != null) openLocation(context, location!);
          },
          onSettings: () => showInfo('Account settings',
              PasswordSettings(service: service, email: user.email ?? '')),
          onLogout: signOut);
    }
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(profile['name'] as String,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text(user.email ?? ''),
      Text('Account: ${profile['role']}'),
      if (profile['role'] == 'vendor')
        Text(profile['approved'] == true
            ? 'Vendor approved'
            : 'Waiting for admin approval'),
      const SizedBox(height: 24),
      const Text(
          'Reservations are saved to your account. All orders are unpaid; online payments and cancellation are not available.'),
      const SizedBox(height: 24),
      OutlinedButton(
          onPressed: () async {
            try {
              await service.auth.signOut();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(firebaseMessage(e))));
              }
            }
          },
          child: const Text('Sign out')),
    ]);
  }
}

typedef CloudDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

class Records extends StatelessWidget {
  const Records(
      {super.key,
      required this.stream,
      required this.empty,
      this.emptyView,
      required this.builder});
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String empty;
  final Widget? emptyView;
  final Widget Function(List<CloudDoc>) builder;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Failure(message: firebaseMessage(snapshot.error!));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.docs.isEmpty) {
              if (emptyView != null) return emptyView!;
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24), child: Text(empty)));
            }
            return builder(snapshot.data!.docs);
          });
}

class CloudListings extends StatefulWidget {
  const CloudListings(
      {super.key,
      required this.service,
      required this.uid,
      required this.role,
      required this.approved,
      this.location});
  final PilotLocation? location;
  final FoodieService service;
  final String uid, role;
  final bool approved;
  @override
  State<CloudListings> createState() => _CloudListingsState();
}

class _CloudListingsState extends State<CloudListings> {
  late final stream = widget.service.listings(widget.role, widget.uid);
  String search = '';
  String category = 'All';
  final pending = <String>{};
  @override
  Widget build(BuildContext context) {
    final vendor = widget.role == 'vendor';
    return Column(children: [
      if (vendor)
        ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.56),
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                          ManagementCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>>(
                                    stream: stream,
                                    builder: (context, snapshot) => Text(
                                        snapshot.hasError
                                            ? 'Listings unavailable'
                                            : 'Active listings: ${snapshot.hasData ? snapshot.data!.docs.where((d) => d.data()['active'] == true).length : '…'}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17))),
                                const SizedBox(height: 8),
                                StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>>(
                                    stream: widget.service
                                        .reservations('vendor', widget.uid),
                                    builder: (context, snapshot) => Text(snapshot
                                            .hasError
                                        ? 'Reservations unavailable'
                                        : 'Pending reservations: ${snapshot.hasData ? snapshot.data!.docs.where((d) => d.data()['status'] == 'reserved').length : '…'}')),
                              ])),
                          Text(widget.approved
                              ? 'Approved · Ready to publish'
                              : 'Waiting for admin approval'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                              onPressed: !widget.approved
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => PublishScreen(
                                              service: widget.service))),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Surplus Food')),
                          const SizedBox(height: 18),
                          const Text('Your listings',
                              style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: managementInk)),
                        ],
                      )),
                ])))
      else
        StudentDiscoverHeader(
            location: widget.location!,
            onSearch: (value) =>
                setState(() => search = value.trim().toLowerCase())),
      if (!vendor)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                    children: ['All', 'Bakery', 'Meals', 'Pastries', 'Other']
                        .map((value) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: Text(value),
                                selected: category == value,
                                onSelected: (_) =>
                                    setState(() => category = value))))
                        .toList()))),
      Expanded(
          child: Records(
              stream: stream,
              emptyView: vendor
                  ? null
                  : CustomerPreview(search: search, category: category),
              empty: vendor
                  ? 'No listings yet. Publish your first surplus meal once approved.'
                  : 'No food available yet. Check back soon.',
              builder: (docs) {
                final results = docs.where((doc) {
                  final d = doc.data();
                  return vendor ||
                      ((d['pickupEnd'] as int) >
                              DateTime.now().millisecondsSinceEpoch &&
                          (category == 'All' || category == d['category']) &&
                          '${d['title']} ${d['vendorName']}'
                              .toLowerCase()
                              .contains(search));
                }).toList()
                  ..sort((a, b) => (a.data()['pickupStart'] as int)
                      .compareTo(b.data()['pickupStart'] as int));
                if (results.isEmpty) {
                  return const Center(
                      child: Text('No matching food. Try another filter.'));
                }
                if (!vendor) {
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    const Text("Today's rescue deals",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: studentDark)),
                    const SizedBox(height: 14),
                    ...results.map((doc) {
                      final d = doc.data();
                      return StudentDealTile(
                          title: d['title'] as String,
                          price: money(d['priceCents']),
                          original: money(d['originalPriceCents']),
                          subtitle: '${d['stock']} left · ${d['vendorName']}',
                          emoji: d['category'] == 'Meals'
                              ? '🍱'
                              : d['category'] == 'Pastries'
                                  ? '🧁'
                                  : '🥐',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ReservationScreen(
                                      service: widget.service,
                                      listingId: doc.id))));
                    }),
                  ]);
                }
                return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final doc = results[i];
                      final d = doc.data();
                      return Card(
                          child: InkWell(
                              onTap: vendor
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ReservationScreen(
                                              service: widget.service,
                                              listingId: doc.id))),
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(d['vendorName'] as String,
                                            style:
                                                const TextStyle(color: _green)),
                                        Text(d['title'] as String,
                                            style: const TextStyle(
                                                fontSize: 21,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Text(pickupWindow(d)),
                                        Text(d['address'] as String),
                                        const SizedBox(height: 8),
                                        Wrap(spacing: 12, children: [
                                          Text(money(d['priceCents']),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20)),
                                          Text(money(d['originalPriceCents']),
                                              style: const TextStyle(
                                                  decoration: TextDecoration
                                                      .lineThrough)),
                                          Text('${d['stock']} left')
                                        ]),
                                        if (vendor)
                                          TextButton(
                                              onPressed: pending
                                                      .contains(doc.id)
                                                  ? null
                                                  : () async {
                                                      setState(() =>
                                                          pending.add(doc.id));
                                                      try {
                                                        await widget.service.call(
                                                            'setListingActive',
                                                            {
                                                              'listingId':
                                                                  doc.id,
                                                              'active':
                                                                  d['active'] !=
                                                                      true
                                                            });
                                                      } catch (e) {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(SnackBar(
                                                                  content: Text(
                                                                      firebaseMessage(
                                                                          e))));
                                                        }
                                                      } finally {
                                                        if (mounted) {
                                                          setState(() => pending
                                                              .remove(doc.id));
                                                        }
                                                      }
                                                    },
                                              child: Text(d['active'] == true
                                                  ? 'Pause listing'
                                                  : 'Reopen listing')),
                                      ]))));
                    });
              })),
    ]);
  }
}

class ReservationScreen extends StatefulWidget {
  const ReservationScreen(
      {super.key, required this.service, required this.listingId});
  final FoodieService service;
  final String listingId;
  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  late final stream = widget.service.db
      .collection('listings')
      .doc(widget.listingId)
      .snapshots();
  int quantity = 1;
  bool busy = false;
  String? error;
  late String requestId = widget.service.requestId();
  int? attemptedQuantity;
  Future<void> reserve() async {
    if (attemptedQuantity != null && attemptedQuantity != quantity) {
      requestId = widget.service.requestId();
    }
    attemptedQuantity = quantity;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.call('reserveListing', {
        'listingId': widget.listingId,
        'quantity': quantity,
        'requestId': requestId
      });
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
                  title: const Text('Pickup reserved'),
                  content: Text(
                      'Your code: ${result['code']}\n\nFind the code, pickup time and address in My Pickups. No payment was processed.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Done'))
                  ]));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = firebaseMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Food details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Failure(message: firebaseMessage(snapshot.error!));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = snapshot.data!.data();
            if (d == null) {
              return const Center(
                  child: Text('This listing is no longer available.'));
            }
            final available = d['active'] == true &&
                (d['stock'] as int) >= quantity &&
                (d['pickupEnd'] as int) > DateTime.now().millisecondsSinceEpoch;
            return SafeArea(
                child: ListView(padding: const EdgeInsets.all(24), children: [
              Text(d['title'] as String,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: _green)),
              Text(d['vendorName'] as String),
              const SizedBox(height: 20),
              Text(money(d['priceCents']),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              Text('Original ${money(d['originalPriceCents'])}',
                  style:
                      const TextStyle(decoration: TextDecoration.lineThrough)),
              const SizedBox(height: 20),
              Text(d['description'] as String),
              const SizedBox(height: 20),
              const Text('Pickup',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(pickupWindow(d)),
              Text(d['address'] as String),
              const SizedBox(height: 20),
              const Text('Dietary & allergen information',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(d['dietary'] as String),
              const SizedBox(height: 20),
              Text('${d['stock']} available'),
              Row(children: [
                const Text('Quantity'),
                const Spacer(),
                IconButton(
                    onPressed: busy || quantity <= 1
                        ? null
                        : () => setState(() => quantity--),
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$quantity'),
                IconButton(
                    onPressed: busy ||
                            quantity >= (d['stock'] as int) ||
                            quantity >= 100
                        ? null
                        : () => setState(() => quantity++),
                    icon: const Icon(Icons.add_circle_outline))
              ]),
              const SizedBox(height: 12),
              const Text(
                  'This reserves food for collection. Online payments and cancellation are not available. Please reserve only if you can collect.'),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: busy || !available ? null : reserve,
                  child: Text(busy
                      ? 'Reserving…'
                      : available
                          ? 'Reserve · ${money((d['priceCents'] as int) * quantity)}'
                          : 'Unavailable')),
            ]));
          }));
}

class CloudPickups extends StatefulWidget {
  const CloudPickups(
      {super.key,
      required this.service,
      required this.uid,
      required this.role,
      required this.approved});
  final FoodieService service;
  final String uid, role;
  final bool approved;
  @override
  State<CloudPickups> createState() => _CloudPickupsState();
}

class _CloudPickupsState extends State<CloudPickups> {
  late final stream = widget.service.reservations(widget.role, widget.uid);
  final code = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> collect() async {
    setState(() => busy = true);
    try {
      await widget.service
          .call('collectReservation', {'code': code.text.trim()});
      code.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pickup confirmed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(firebaseMessage(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        if (widget.role == 'vendor')
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                    controller: code,
                    enabled: !busy && widget.approved,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Customer pickup code')),
                const SizedBox(height: 8),
                FilledButton(
                    onPressed: busy || !widget.approved ? null : collect,
                    child: Text(busy ? 'Verifying…' : 'Confirm collection')),
              ])),
        Expanded(
            child: Records(
                stream: stream,
                empty: 'No reservations yet.',
                builder: (docs) {
                  docs.sort((a, b) => (b.data()['pickupStart'] as int)
                      .compareTo(a.data()['pickupStart'] as int));
                  return ListView(
                      padding: const EdgeInsets.all(16),
                      children: docs.map((doc) {
                        final d = doc.data();
                        return Card(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          (d['status'] as String).toUpperCase(),
                                          style: const TextStyle(
                                              color: _green,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(d['title'] as String,
                                          style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold)),
                                      Text(d['vendorName'] as String),
                                      Text(pickupWindow(d)),
                                      Text(d['address'] as String),
                                      const SizedBox(height: 12),
                                      Text(
                                          'Qty ${d['quantity']} · ${money(d['totalCents'])} · Unpaid'),
                                      if (widget.role == 'customer') ...[
                                        const Divider(height: 24),
                                        SelectableText(d['code'] as String,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 19)),
                                        const Text(
                                            'Show this code to your vendor when collecting.')
                                      ],
                                    ])));
                      }).toList());
                })),
      ]);
}

class VendorApprovals extends StatefulWidget {
  const VendorApprovals({super.key, required this.service});
  final FoodieService service;
  @override
  State<VendorApprovals> createState() => _VendorApprovalsState();
}

class _VendorApprovalsState extends State<VendorApprovals> {
  late final stream = widget.service.db
      .collection('users')
      .where('role', isEqualTo: 'vendor')
      .snapshots();
  final pending = <String>{};
  @override
  Widget build(BuildContext context) => Records(
      stream: stream,
      empty: 'No vendor applications yet.',
      builder: (docs) => ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Vendor applications',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...docs.map((doc) {
              final d = doc.data();
              return Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(d['name'] as String,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(d['approved'] == true
                                ? 'Approved'
                                : 'Pending approval'),
                            if (d['approved'] != true)
                              FilledButton(
                                  onPressed: pending.contains(doc.id)
                                      ? null
                                      : () async {
                                          setState(() => pending.add(doc.id));
                                          try {
                                            await widget.service
                                                .approveVendor(doc.id);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          firebaseMessage(e))));
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(
                                                  () => pending.remove(doc.id));
                                            }
                                          }
                                        },
                                  child: const Text('Approve vendor')),
                          ])));
            }),
          ]));
}

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key, required this.service});
  final FoodieService service;
  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      address = TextEditingController(),
      dietary = TextEditingController(),
      price = TextEditingController(),
      original = TextEditingController(),
      stock = TextEditingController();
  String category = 'Meals';
  DateTime? start, end;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in [
      title,
      description,
      address,
      dietary,
      price,
      original,
      stock
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? cents(String text) {
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text.trim())) return null;
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite) return null;
    return (value * 100).round();
  }

  Future<void> pick(bool first) async {
    final now = DateTime.now();
    final day = await showDatePicker(
        context: context,
        initialDate: first ? start ?? now : end ?? start ?? now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 30)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(first
            ? start ?? now.add(const Duration(hours: 1))
            : end ?? now.add(const Duration(hours: 2))));
    if (time == null || !mounted) return;
    setState(() {
      final value =
          DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (first) {
        start = value;
      } else {
        end = value;
      }
    });
  }

  Future<void> publish() async {
    if (!form.currentState!.validate()) return;
    if (start == null ||
        end == null ||
        !start!.isAfter(DateTime.now()) ||
        !end!.isAfter(start!)) {
      setState(
          () => error = 'Choose a future pickup start and a later end time.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service.call('publishListing', {
        'title': title.text.trim(),
        'description': description.text.trim(),
        'address': address.text.trim(),
        'dietary': dietary.text.trim(),
        'category': category,
        'priceCents': cents(price.text),
        'originalPriceCents': cents(original.text),
        'stock': int.parse(stock.text),
        'pickupStart': start!.millisecondsSinceEpoch,
        'pickupEnd': end!.millisecondsSinceEpoch
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = firebaseMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController controller, String label, int max,
          {int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: controller,
              enabled: !busy,
              maxLength: max,
              maxLines: lines,
              decoration: InputDecoration(labelText: label),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'This field is required.'
                  : null));
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: managementCream,
      appBar: AppBar(
          title: const Text('FoodieNoms'),
          backgroundColor: managementGreen,
          foregroundColor: Colors.white),
      body: Theme(
          data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD0DFD3))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD0DFD3))),
          )),
          child: SafeArea(
              child: Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    const Text('Create surplus listing',
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: managementInk)),
                    const SizedBox(height: 24),
                    field(title, 'Food name', 100),
                    field(description, 'What is included?', 1000, lines: 3),
                    DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: ['Bakery', 'Meals', 'Pastries', 'Other']
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged:
                            busy ? null : (v) => setState(() => category = v!)),
                    const SizedBox(height: 16),
                    field(address, 'Full pickup address', 300, lines: 2),
                    field(dietary,
                        'Ingredients, allergens and dietary information', 500,
                        lines: 3),
                    ...[
                      (price, 'Discounted price (RM)'),
                      (original, 'Original price (RM)')
                    ].map((pair) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                            controller: pair.$1,
                            enabled: !busy,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(labelText: pair.$2),
                            validator: (v) {
                              final amount = cents(v ?? '');
                              if (amount == null ||
                                  amount < 1 ||
                                  amount > 1000000) {
                                return 'Enter RM 0.01 to RM 10,000.00 (up to 2 decimals).';
                              }
                              if (pair.$1 == original &&
                                  amount < (cents(price.text) ?? 0)) {
                                return 'Original price must be at least the discounted price.';
                              }
                              return null;
                            }))),
                    TextFormField(
                        controller: stock,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Available quantity'),
                        validator: (v) {
                          final value = int.tryParse(v ?? '');
                          return value == null || value < 1 || value > 10000
                              ? 'Enter a quantity from 1 to 10,000.'
                              : null;
                        }),
                    const SizedBox(height: 16),
                    OutlinedButton(
                        onPressed: busy ? null : () => pick(true),
                        child: Text(start == null
                            ? 'Choose pickup start'
                            : 'Start: ${start!.toLocal()}')),
                    OutlinedButton(
                        onPressed: busy ? null : () => pick(false),
                        child: Text(end == null
                            ? 'Choose pickup end'
                            : 'End: ${end!.toLocal()}')),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: busy ? null : publish,
                        child: Text(busy ? 'Publishing…' : 'Publish listing')),
                  ])))));
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center)));
}

class CustomerMap extends StatefulWidget {
  const CustomerMap(
      {super.key,
      required this.service,
      required this.uid,
      required this.location});
  final FoodieService service;
  final String uid;
  final PilotLocation location;
  @override
  State<CustomerMap> createState() => _CustomerMapState();
}

class _CustomerMapState extends State<CustomerMap> {
  late final stream = widget.service.listings('customer', widget.uid);
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(22), children: [
        const Text('Deals near you',
            style: TextStyle(
                fontSize: 27, fontWeight: FontWeight.w800, color: studentDark)),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.location_on_outlined, color: studentGreen, size: 18),
          const SizedBox(width: 6),
          Expanded(
              child: AnimatedBuilder(
                  animation: widget.location,
                  builder: (_, __) => Text(widget.location.area))),
          TextButton(
              onPressed: () => openLocation(context, widget.location),
              child: const Text('Change'))
        ]),
        const SizedBox(height: 12),
        LiveLocationMap(location: widget.location),
        const SizedBox(height: 8),
        const Text(
            'Use the location button to show where you are. Vendor addresses are listed below; vendor pins are not available yet.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 20),
        Records(
            stream: stream,
            empty: 'No food available yet.',
            emptyView: Column(children: [
              const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Sample vendors · preview only',
                      style: TextStyle(color: Colors.black54))),
              ...sampleFoods.map((food) => StudentDealTile(
                  title: food.name,
                  price: food.formattedPrice,
                  original: food.formattedOriginal,
                  subtitle: food.vendor,
                  emoji: food.emoji,
                  preview: true,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SampleFoodDetails(food: food))))),
            ]),
            builder: (docs) {
              final available = docs
                  .where((doc) =>
                      (doc.data()['pickupEnd'] as int) >
                      DateTime.now().millisecondsSinceEpoch)
                  .toList();
              if (available.isEmpty) {
                return const Text(
                    'No current pickups. Check back for new listings.');
              }
              return Column(
                  children: available.map((doc) {
                final d = doc.data();
                return Card(
                    color: Colors.white,
                    child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(d['vendorName'] as String),
                        subtitle: Text(
                            '${d['title']} · ${money(d['priceCents'])}\n${d['address']}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ReservationScreen(
                                    service: widget.service,
                                    listingId: doc.id)))));
              }).toList());
            }),
      ]);
}

class PasswordSettings extends StatefulWidget {
  const PasswordSettings(
      {super.key, required this.service, required this.email});
  final FoodieService service;
  final String email;
  @override
  State<PasswordSettings> createState() => _PasswordSettingsState();
}

class _PasswordSettingsState extends State<PasswordSettings> {
  bool busy = false;
  String? message;
  Future<void> reset() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.service.auth.sendPasswordResetEmail(email: widget.email);
      if (mounted) {
        setState(
            () => message = 'Password reset email sent. Check your inbox.');
      }
    } catch (e) {
      if (mounted) setState(() => message = firebaseMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Password & security',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Text(widget.email),
        const SizedBox(height: 20),
        const Text(
            'Reset your password using the link sent to your registered email address.'),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: busy || widget.email.isEmpty ? null : reset,
            child: Text(busy ? 'Sending…' : 'Send reset link')),
        if (message != null)
          Padding(
              padding: const EdgeInsets.only(top: 16), child: Text(message!)),
      ]);
}

class CustomerNotifications extends StatefulWidget {
  const CustomerNotifications(
      {super.key, required this.service, required this.uid});
  final FoodieService service;
  final String uid;
  @override
  State<CustomerNotifications> createState() => _CustomerNotificationsState();
}

class _CustomerNotificationsState extends State<CustomerNotifications> {
  late final stream = widget.service.reservations('customer', widget.uid);
  @override
  Widget build(BuildContext context) => Records(
      stream: stream,
      empty: 'No notifications yet. Your reservation updates will appear here.',
      builder: (docs) => ListView(padding: const EdgeInsets.all(22), children: [
            const Text('Your updates',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            ...docs.map((doc) {
              final d = doc.data();
              return Card(
                  color: Colors.white,
                  child: ListTile(
                      leading: Icon(
                          d['status'] == 'collected'
                              ? Icons.check_circle_outline
                              : Icons.receipt_long_outlined,
                          color: studentGreen),
                      title: Text(d['status'] == 'collected'
                          ? 'Your pickup was collected'
                          : 'Your reservation is confirmed'),
                      subtitle: Text('${d['title']}\n${pickupWindow(d)}'),
                      isThreeLine: true));
            }),
          ]));
}
