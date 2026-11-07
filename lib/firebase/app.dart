import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import 'service.dart';
import 'customer_preview.dart';
import 'student_ui.dart';
import 'reference_assets.dart';
import 'listing_editor.dart';
import 'listing_photo.dart';
import 'live_location_map.dart';
import 'customer_map_panel.dart';
import 'management_ui.dart';
import 'pickup_ui.dart';
import 'student_experience.dart';
import 'vendor_ui.dart';
import 'password_recovery.dart';
import 'admin_accounts.dart';
import 'vendor_business.dart';
import 'vendor_management.dart';

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
  bool showPassword = false;
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
      } else if (!email.text.contains('@')) {
        await widget.service.signInAdministrator(email.text, password.text);
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
    if (busy) return;
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => PasswordRecoveryScreen(
                onSend: widget.service.requestPasswordReset,
                initialEmail: initialRecoveryEmail(email.text))));
    if (mounted) {
      setState(() {
        password.clear();
        showPassword = false;
        error = null;
      });
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
                        'Vendor accounts need approval before publishing. Account type cannot be changed here.'),
                  ] else ...[
                    TextFormField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: register
                            ? const [AutofillHints.email]
                            : const [AutofillHints.username],
                        decoration: InputDecoration(
                            labelText:
                                register ? 'Email' : 'Email or username'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? register
                                ? 'Enter your email address.'
                                : 'Enter your email or username.'
                            : register && !v.contains('@')
                                ? 'Enter a valid email.'
                                : null),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: password,
                        enabled: !busy,
                        obscureText: !showPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: register
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                                tooltip: showPassword
                                    ? 'Hide password'
                                    : 'Show password',
                                onPressed: busy
                                    ? null
                                    : () => setState(
                                        () => showPassword = !showPassword),
                                icon: Icon(showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined))),
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
                                  showPassword = false;
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
    if (role == 'vendor' && widget.profile['approved'] != true) {
      return VendorPendingScreen(
          service: widget.service,
          email: widget.user.email ?? '',
          revoked: widget.profile['revokedAt'] != null,
          reason: widget.profile['revocationReason'] as String?);
    }
    final lastTab = role == 'vendor' ? 2 : 3;
    final index = tab.clamp(0, lastTab);
    Widget body;
    if (index == lastTab) {
      body = AccountProfile(
          service: widget.service,
          user: widget.user,
          profile: widget.profile,
          location: location);
    } else if (role == 'admin') {
      body = index == 0
          ? AdminOverviewScreen(
              service: widget.service,
              onReviewVendors: () => setState(() => tab = 1),
              onAdministrators: () => setState(() => tab = 2))
          : index == 1
              ? VendorManagementScreen(service: widget.service)
              : AdminAccountsScreen(service: widget.service);
    } else if (customer && index == 1) {
      body = CustomerMap(
          service: widget.service, uid: widget.user.uid, location: location);
    } else if ((customer && index == 2) || (!customer && index == 1)) {
      body = CloudPickups(
          service: widget.service,
          uid: widget.user.uid,
          role: role,
          onBrowse: () => setState(() => tab = 0),
          approved: widget.profile['approved'] == true);
    } else {
      body = CloudListings(
          service: widget.service,
          uid: widget.user.uid,
          role: role,
          approved: widget.profile['approved'] == true,
          location: location,
          onReservations: () => setState(() => tab = 1));
    }
    if (role == 'admin') {
      return AdminLayout(
          labels: const ['Overview', 'Vendors', 'Administrators', 'Profile'],
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

class AccountProfile extends StatefulWidget {
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
  State<AccountProfile> createState() => _AccountProfileState();
}

class _AccountProfileState extends State<AccountProfile> {
  Stream<Iterable<Map<String, dynamic>>>? _reservations;
  FoodieService get service => widget.service;
  User get user => widget.user;
  Map<String, dynamic> get profile => widget.profile;
  PilotLocation? get location => widget.location;

  void _loadHistory() {
    _reservations = profile['role'] == 'customer'
        ? service.reservations('customer', user.uid).map((snapshot) =>
            snapshot.docs.map((doc) => doc.data()).toList(growable: false))
        : null;
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant AccountProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != service ||
        oldWidget.user.uid != user.uid ||
        oldWidget.profile['role'] != profile['role']) {
      _loadHistory();
    }
  }

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
          reservations: _reservations,
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
      const SizedBox(height: 16),
      if (profile['role'] == 'vendor')
        VendorBusinessSummary(service: service, uid: user.uid),
      ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Password & security'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Account settings')),
                      body: PasswordSettings(
                          service: service, email: user.email ?? ''))))),
      const SizedBox(height: 24),
      Text(profile['role'] == 'admin'
          ? 'Review vendor applications, approve or revoke selling access, and manage separate administrator accounts.'
          : 'Manage food listings, remaining stock and pickup reservations from your vendor dashboard. Orders are unpaid; collect payment at pickup. Reserved orders can be cancelled to return stock.'),
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

/// Customer catalogues use public approval records; private user data stays private.
class ApprovedVendorRecords extends StatefulWidget {
  const ApprovedVendorRecords(
      {super.key,
      required this.service,
      required this.stream,
      required this.empty,
      this.emptyView,
      required this.builder});
  final FoodieService service;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String empty;
  final Widget? emptyView;
  final Widget Function(List<CloudDoc>) builder;
  @override
  State<ApprovedVendorRecords> createState() => _ApprovedVendorRecordsState();
}

class _ApprovedVendorRecordsState extends State<ApprovedVendorRecords> {
  late final businesses = widget.service.db
      .collection('vendorBusinesses')
      .where('approved', isEqualTo: true)
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: businesses,
          builder: (context, state) {
            if (state.hasError) {
              return _Failure(message: firebaseMessage(state.error!));
            }
            if (!state.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final approved = state.data!.docs
                .where((doc) => ShopMapPin.fromData(doc.id, doc.data()) != null)
                .map((doc) => doc.id)
                .toSet();
            return Records(
                stream: widget.stream,
                empty: widget.empty,
                emptyView: widget.emptyView,
                builder: (docs) {
                  final visible = docs.where((doc) {
                    final data = doc.data();
                    final hasCoordinates = data.containsKey('latitude') ||
                        data.containsKey('longitude');
                    return approved.contains(data['vendorId']) &&
                        (!hasCoordinates ||
                            ShopMapPin.fromData(doc.id, {
                                  'configured': true,
                                  'businessName': data['vendorName'],
                                  'address': data['address'],
                                  'latitude': data['latitude'],
                                  'longitude': data['longitude'],
                                }) !=
                                null);
                  }).toList();
                  if (visible.isEmpty) {
                    return widget.emptyView ??
                        Center(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(widget.empty)));
                  }
                  return widget.builder(visible);
                });
          });
}

class CloudListings extends StatefulWidget {
  const CloudListings(
      {super.key,
      required this.service,
      required this.uid,
      required this.role,
      required this.approved,
      this.location,
      this.onReservations});
  final VoidCallback? onReservations;
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
  final searchController = TextEditingController();
  void clearFilters() {
    searchController.clear();
    setState(() {
      search = '';
      category = 'All';
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> openListing(
      {String? id,
      Map<String, dynamic>? initial,
      String? draftId,
      Map<String, dynamic>? draftData,
      bool duplicate = false}) async {
    Map<String, dynamic>? business;
    try {
      if (draftId != null && id != null) {
        final source = await widget.service.db
            .collection('listings')
            .doc(id)
            .get(const GetOptions(source: Source.server));
        initial = source.data();
        if (initial == null || initial['vendorId'] != widget.uid) {
          throw StateError(
              'The original listing is unavailable. Your saved draft is still kept.');
        }
      }
      final ref =
          widget.service.db.collection('vendorBusinesses').doc(widget.uid);
      business =
          (await ref.get(const GetOptions(source: Source.server))).data();
      if (!mounted) return;
      if (ShopMapPin.fromData(widget.uid, business ?? {}) == null) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => VendorBusinessScreen(service: widget.service)));
        if (!mounted) return;
        business =
            (await ref.get(const GetOptions(source: Source.server))).data();
      }
      if (!mounted || ShopMapPin.fromData(widget.uid, business ?? {}) == null) {
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(firebaseMessage(e))));
      }
      return;
    }
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => ListingEditorScreen(
                service: widget.service,
                business: business!,
                listingId: id,
                initial: initial,
                draftId: draftId,
                draftData: draftData,
                duplicate: duplicate)));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(id == null || duplicate
              ? 'Food published! Students can reserve it now.'
              : 'Listing updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'vendor') {
      return VendorDashboard(
          service: widget.service,
          uid: widget.uid,
          onAdd: () => openListing(),
          onEdit: (id, data) => openListing(id: id, initial: data),
          onResumeDraft: (id, record) => openListing(
              id: record['sourceListingId'] as String?,
              draftId: id,
              draftData: Map<String, dynamic>.from(record['formData'] as Map)),
          onDuplicate: (id, data) =>
              openListing(id: id, initial: data, duplicate: true),
          onReservations: widget.onReservations);
    }
    return Column(children: [
      StudentDiscoverHeader(
          searchController: searchController,
          location: widget.location!,
          onSearch: (value) =>
              setState(() => search = value.trim().toLowerCase())),
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
          child: ApprovedVendorRecords(
              service: widget.service,
              stream: stream,
              emptyView: CustomerPreview(
                  search: search,
                  category: category,
                  onClearFilters: clearFilters),
              empty: 'No food available yet. Check back soon.',
              builder: (docs) {
                final results = docs.where((doc) {
                  final d = doc.data();
                  return (d['stock'] as int) > 0 &&
                      (d['pickupEnd'] as int) >
                          DateTime.now().millisecondsSinceEpoch &&
                      (category == 'All' || category == d['category']) &&
                      '${d['title']} ${d['vendorName']}'
                          .toLowerCase()
                          .contains(search);
                }).toList()
                  ..sort((a, b) => (a.data()['pickupStart'] as int)
                      .compareTo(b.data()['pickupStart'] as int));
                if (results.isEmpty) {
                  return StudentEmptyState(
                      title: search.isNotEmpty || category != 'All'
                          ? 'No matching food'
                          : 'No food available right now',
                      message: search.isNotEmpty || category != 'All'
                          ? 'Try another food category or clear your search.'
                          : 'Today’s deals may have sold out or ended. Check back for new food from nearby vendors.',
                      actionLabel: 'Clear filters',
                      onAction: search.isNotEmpty || category != 'All'
                          ? clearFilters
                          : null);
                }
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
                        photoWidget: ListingFoodPhoto(
                            service: widget.service, listing: d),
                        price: money(d['priceCents']),
                        original: money(d['originalPriceCents']),
                        subtitle:
                            '${d['stock']} left · ${d['vendorName']} · Pickup ${friendlyPickupWindow(d)}',
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

class _VendorAvailability extends StatefulWidget {
  const _VendorAvailability(
      {required this.service, required this.vendorId, required this.child});
  final FoodieService service;
  final String vendorId;
  final Widget child;
  @override
  State<_VendorAvailability> createState() => _VendorAvailabilityState();
}

class _VendorAvailabilityState extends State<_VendorAvailability> {
  late final approval = widget.service.db
      .collection('vendorBusinesses')
      .where('approved', isEqualTo: true)
      .where(FieldPath.documentId, isEqualTo: widget.vendorId)
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: approval,
          builder: (context, state) {
            if (state.hasError) {
              return _Failure(message: firebaseMessage(state.error!));
            }
            if (!state.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!state.data!.docs.any(
                (doc) => ShopMapPin.fromData(doc.id, doc.data()) != null)) {
              return StudentEmptyState(
                  title: 'This vendor is currently unavailable',
                  message:
                      'New reservations are paused. Your existing reservations are still in Orders.',
                  actionLabel: 'Back to food',
                  onAction: () {
                    Navigator.maybePop(context);
                  });
            }
            return widget.child;
          });
}

class _ReservationScreenState extends State<ReservationScreen> {
  late final stream = widget.service.db
      .collection('listings')
      .doc(widget.listingId)
      .snapshots();
  late final allowanceStream = widget.service.db
      .collection('listings')
      .doc(widget.listingId)
      .collection('claims')
      .doc(widget.service.auth.currentUser!.uid)
      .snapshots();
  int quantity = 1;
  bool busy = false;
  String? error;
  late String requestId = widget.service.requestId();
  int? attemptedQuantity;
  Future<void> reserve(Map<String, dynamic> reviewed) async {
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
        'requestId': requestId,
        'expectedPriceCents': reviewed['priceCents'],
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => OrderDetailsScreen(
              service: widget.service,
              reservationId: result['id'] as String,
              confirmed: true)));
    } catch (e) {
      if (mounted) {
        setState(() => error = e is FirebaseException &&
                e.code == 'permission-denied'
            ? 'This deal is no longer available. Existing reservations are still in Orders.'
            : firebaseMessage(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(Map<String, dynamic> listing) async {
    final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            ReservationReview(listing: listing, quantity: quantity));
    if (confirmed == true && mounted) await reserve(listing);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Food details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              if (snapshot.error
                  case FirebaseException(code: 'permission-denied')) {
                return StudentEmptyState(
                    title: 'Listing unavailable',
                    message:
                        'This deal is no longer available to reserve. You can still manage existing reservations in Orders.',
                    actionLabel: 'Back to browse',
                    onAction: () => Navigator.maybePop(context));
              }
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
            return _VendorAvailability(
                service: widget.service,
                vendorId: d['vendorId'] as String,
                child: SafeArea(
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                          height: 210,
                          child: ListingFoodPhoto(
                              service: widget.service, listing: d))),
                  const SizedBox(height: 20),
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
                      style: const TextStyle(
                          decoration: TextDecoration.lineThrough)),
                  const SizedBox(height: 20),
                  Text(d['description'] as String),
                  if ((d['foodDescription'] as String? ?? '').trim().isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(d['foodDescription'] as String)),
                  const SizedBox(height: 20),
                  const Text('Pickup',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(friendlyPickupWindow(d)),
                  Text(d['address'] as String),
                  if ((d['pickupInstructions'] as String? ?? '')
                      .trim()
                      .isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(d['pickupInstructions'] as String)),
                  DirectionsButton(
                      address: d['address'] as String,
                      latitude: (d['latitude'] as num?)?.toDouble(),
                      longitude: (d['longitude'] as num?)?.toDouble()),
                  const SizedBox(height: 20),
                  const Text('Dietary & allergen information',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if (d.containsKey('ingredients') ||
                      d.containsKey('allergens') ||
                      d.containsKey('halalStatus')) ...[
                    if ((d['ingredients'] as String? ?? '').trim().isNotEmpty)
                      Text('Ingredients: ${d['ingredients']}'),
                    Text((d['allergens'] as String? ?? '').trim().isEmpty
                        ? 'Allergens not declared. Ask the vendor before consuming.'
                        : 'Allergens: ${d['allergens']}'),
                    if ((d['dietaryTags'] as List? ?? []).isNotEmpty)
                      Text(
                          'Vendor declares: ${(d['dietaryTags'] as List).join(', ')}'),
                    Text(d['halalStatus'] == 'vendor_declared'
                        ? 'Halal: vendor declared; certification not verified.'
                        : 'Halal status not declared.'),
                  ] else
                    Text(d['dietary'] as String),
                  const SizedBox(height: 20),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: allowanceStream,
                      builder: (context, claim) {
                        if (claim.hasError) {
                          return const Text(
                              'Unable to check your reservation allowance. Reopen this listing to retry.');
                        }
                        if (!claim.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final remaining = remainingReservationAllowance(
                            (claim.data!.data()?['quantity'] as int?) ?? 0,
                            limit: maxPerCustomer);
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('${d['stock']} available'),
                              Row(children: [
                                const Text('Quantity'),
                                const Spacer(),
                                IconButton(
                                    onPressed: busy || quantity <= 1
                                        ? null
                                        : () => setState(() => quantity--),
                                    icon: const Icon(
                                        Icons.remove_circle_outline)),
                                Text('$quantity'),
                                IconButton(
                                    onPressed: busy ||
                                            quantity >= (d['stock'] as int) ||
                                            quantity >= remaining
                                        ? null
                                        : () => setState(() => quantity++),
                                    icon: const Icon(Icons.add_circle_outline))
                              ]),
                              const SizedBox(height: 12),
                              Text(remaining == 0
                                  ? 'You have reached the 5-item limit for this listing. Cancel an eligible order to free your allowance.'
                                  : 'You can reserve $remaining more ${remaining == 1 ? 'item' : 'items'} from this listing.'),
                              if (quantity > remaining && remaining > 0)
                                const Text(
                                    'Reduce the quantity to fit your remaining allowance.'),
                              const SizedBox(height: 8),
                              const Text(
                                  'Reserve up to 5 items per listing across your orders. You can cancel before the pickup window ends. Pay at pickup.'),
                              if (error != null)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Text(error!,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error))),
                              const SizedBox(height: 16),
                              FilledButton(
                                  onPressed:
                                      busy || !available || quantity > remaining
                                          ? null
                                          : () => review(d),
                                  child: Text(busy
                                      ? 'Reserving…'
                                      : available && quantity <= remaining
                                          ? 'Reserve · ${money((d['priceCents'] as int) * quantity)}'
                                          : remaining == 0
                                              ? 'Limit reached'
                                              : 'Unavailable')),
                            ]);
                      }),
                ])));
          }));
}

class CloudPickups extends StatefulWidget {
  const CloudPickups(
      {super.key,
      required this.service,
      required this.uid,
      required this.role,
      required this.approved,
      this.onBrowse});
  final VoidCallback? onBrowse;
  final FoodieService service;
  final String uid, role;
  final bool approved;
  @override
  State<CloudPickups> createState() => _CloudPickupsState();
}

class _CloudPickupsState extends State<CloudPickups> {
  late final stream = widget.service.reservations(widget.role, widget.uid);
  final code = TextEditingController();
  String statusTab = 'reserved';
  bool busy = false;
  Timer? ticker;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    code.dispose();
    super.dispose();
  }

  Future<void> collect() async {
    if (busy) return;
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

  Future<void> collectOrder(Map<String, dynamic> order) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Confirm food handover?'),
                content: Text(
                    'Mark ${order['quantity']} × ${order['title']} as collected? Only confirm after handing over the food.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Go back')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirm collection'))
                ]));
    if (yes != true || !mounted) return;
    code.text = order['code'] as String;
    await collect();
  }

  Future<void> scan() async {
    final scanned = await Navigator.push<String>(context,
        MaterialPageRoute(builder: (_) => const PickupScannerScreen()));
    if (!mounted || scanned == null) return;
    code.text = scanned;
    await collect();
  }

  Future<void> cancel(String reservationId) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Cancel reservation?'),
              content: const Text(
                  'The reserved quantity will be returned to the listing. This cannot undo a completed pickup.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep reservation')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cancel reservation'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.service
          .call('cancelReservation', {'reservationId': reservationId});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(firebaseMessage(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeStatus(String id, String status) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (status == 'noshow') {
        final yes = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
                    title: const Text('Mark as not collected?'),
                    content: const Text(
                        'The pickup time has ended. This closes the reservation without returning stock. Choose Cancel reservation instead if you want to return the reserved quantity.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Go back')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Not collected')),
                    ]));
        if (yes != true || !mounted) return;
      }
      await widget.service.call(
          status == 'ready' ? 'markOrderReady' : 'markOrderNoShow',
          {'reservationId': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(status == 'ready'
                ? 'Food marked ready. The customer can see the update in Orders.'
                : 'Reservation marked as not collected.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(firebaseMessage(error))));
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
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: busy || !widget.approved ? null : scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan pickup QR'))),
                const SizedBox(height: 12),
                TextField(
                    controller: code,
                    enabled: !busy && widget.approved,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText:
                            '4-digit pickup code or reservation reference',
                        helperText: 'Older FN-… references still work.',
                        helperMaxLines: 2)),
                const SizedBox(height: 8),
                FilledButton(
                    onPressed: busy || !widget.approved ? null : collect,
                    child: Text(busy ? 'Please wait…' : 'Confirm collection')),
              ])),
        OrderStatusTabs(
            upcomingLabel: widget.role == 'vendor' ? 'Pending' : 'Upcoming',
            selected: statusTab,
            onSelected: (value) => setState(() => statusTab = value)),
        Expanded(
            child: Records(
                stream: stream,
                empty: 'No reservations yet.',
                emptyView: widget.role == 'customer'
                    ? StudentEmptyState(
                        title: 'No orders yet',
                        message:
                            'Find a deal nearby and reserve your first pickup.',
                        actionLabel: 'Browse food',
                        onAction: widget.onBrowse)
                    : null,
                builder: (docs) {
                  final visible = docs
                      .where(
                          (doc) => reservationMatchesTab(doc.data(), statusTab))
                      .toList();
                  visible.sort((a, b) => statusTab == 'reserved'
                      ? (a.data()['pickupStart'] as int)
                          .compareTo(b.data()['pickupStart'] as int)
                      : (b.data()['pickupStart'] as int)
                          .compareTo(a.data()['pickupStart'] as int));
                  if (visible.isEmpty) {
                    return StudentEmptyState(
                        title: statusTab == 'reserved'
                            ? 'No upcoming pickups'
                            : statusTab == 'collected'
                                ? 'No collected orders'
                                : statusTab == 'noshow'
                                    ? 'No uncollected orders'
                                    : 'No cancelled orders',
                        message: statusTab == 'reserved'
                            ? 'Your next reservation and pickup QR will appear here.'
                            : 'Orders will appear here when their status changes.',
                        actionLabel:
                            statusTab == 'reserved' ? 'Browse food' : null,
                        onAction:
                            statusTab == 'reserved' ? widget.onBrowse : null);
                  }
                  return ListView(
                      padding: const EdgeInsets.all(16),
                      children: visible.map((doc) {
                        final d = doc.data();
                        return Card(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          reservationStatusLabel(
                                              d['status'] as String),
                                          style: const TextStyle(
                                              color: _green,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(d['title'] as String,
                                          style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold)),
                                      Text(d['vendorName'] as String),
                                      if (widget.role == 'customer' &&
                                          isOpenReservation(d) &&
                                          shortPickupCode(d) != null)
                                        Text(
                                            'Pickup code: ${shortPickupCode(d)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                      Text(widget.role == 'customer'
                                          ? friendlyPickupWindow(d)
                                          : pickupWindow(d)),
                                      if (widget.role == 'customer' &&
                                          isOpenReservation(d) &&
                                          (d['pickupEnd'] as int) <
                                              DateTime.now()
                                                  .millisecondsSinceEpoch)
                                        const Text(
                                            'Pickup window ended — contact the vendor.',
                                            style: TextStyle(
                                                color: Colors.deepOrange)),
                                      Text(d['address'] as String),
                                      const SizedBox(height: 12),
                                      Text(
                                          'Qty ${d['quantity']} · ${money(d['totalCents'])} · Unpaid'),
                                      if (widget.role == 'vendor' &&
                                          isOpenReservation(d))
                                        VendorPickupActions(
                                            order: d,
                                            busy: busy,
                                            approved: widget.approved,
                                            onReady: () =>
                                                changeStatus(doc.id, 'ready'),
                                            onNoShow: () =>
                                                changeStatus(doc.id, 'noshow'),
                                            onCollect: () => collectOrder(d)),
                                      if (isOpenReservation(d) &&
                                          ((widget.role == 'vendor' &&
                                                  widget.approved) ||
                                              (widget.role == 'customer' &&
                                                  DateTime.now()
                                                          .millisecondsSinceEpoch <
                                                      (d['pickupEnd'] as int))))
                                        TextButton.icon(
                                            onPressed: busy
                                                ? null
                                                : () => cancel(doc.id),
                                            icon: const Icon(
                                                Icons.cancel_outlined),
                                            label: const Text(
                                                'Cancel reservation')),
                                      if (widget.role == 'customer') ...[
                                        const Divider(height: 24),
                                        FilledButton.tonalIcon(
                                            onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        OrderDetailsScreen(
                                                            service:
                                                                widget.service,
                                                            reservationId:
                                                                doc.id))),
                                            icon: Icon(isOpenReservation(d)
                                                ? Icons.qr_code
                                                : Icons.receipt_long_outlined),
                                            label: Text(isOpenReservation(d)
                                                ? 'View pickup QR'
                                                : 'View order')),
                                      ],
                                    ])));
                      }).toList());
                })),
      ]);
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
  late final listings = widget.service.listings('customer', widget.uid);
  late final businesses = widget.service.db
      .collection('vendorBusinesses')
      .where('approved', isEqualTo: true)
      .snapshots();
  ShopMapPin? focused;

  void showShop(ShopMapPin pin) {
    setState(() => focused = pin);
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: studentCream,
        builder: (sheet) => SafeArea(
            child: FractionallySizedBox(
                heightFactor: .68,
                child: ListView(padding: const EdgeInsets.all(22), children: [
                  Text(pin.name,
                      style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: studentDark)),
                  const SizedBox(height: 8),
                  Text(pin.address),
                  DirectionsButton(
                      address: pin.address,
                      latitude: pin.latitude,
                      longitude: pin.longitude),
                  const SizedBox(height: 18),
                  const Text('Available food',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ApprovedVendorRecords(
                      service: widget.service,
                      stream: listings,
                      empty: 'No food available at this shop right now.',
                      builder: (docs) {
                        final available = docs.where((doc) {
                          final data = doc.data();
                          return data['vendorId'] == pin.id &&
                              (data['stock'] as int) > 0 &&
                              (data['pickupEnd'] as int) >
                                  DateTime.now().millisecondsSinceEpoch;
                        }).toList();
                        if (available.isEmpty) {
                          return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                  'No food available at this shop right now.'));
                        }
                        return Column(
                            children: available.map((doc) {
                          final data = doc.data();
                          return Card(
                              child: ListTile(
                                  title: Text(data['title'] as String),
                                  subtitle: Text(
                                      '${money(data['priceCents'])} · ${data['stock']} left\n${friendlyPickupWindow(data)}'),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pop(sheet);
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => ReservationScreen(
                                                service: widget.service,
                                                listingId: doc.id)));
                                  }));
                        }).toList());
                      }),
                ]))));
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: businesses,
          builder: (context, state) {
            final shops = <ShopMapPin>[
              for (final doc in state.data?.docs ?? <CloudDoc>[])
                if (ShopMapPin.fromData(doc.id, doc.data()) case final pin?)
                  pin,
            ]..sort((a, b) => a.name.compareTo(b.name));
            final currentFocus =
                shops.where((pin) => pin.id == focused?.id).firstOrNull;
            return CustomerMapPanel(
                location: widget.location,
                shops: shops,
                focusShop: currentFocus,
                onShopTap: showShop,
                onChangeLocation: () => openLocation(context, widget.location),
                loading: !state.hasData && !state.hasError,
                error: state.hasError ? firebaseMessage(state.error!) : null);
          });
}

class PasswordSettings extends StatelessWidget {
  const PasswordSettings(
      {super.key, required this.service, required this.email});
  final FoodieService service;
  final String email;
  @override
  Widget build(BuildContext context) => SafeArea(
      child: PasswordRecoveryForm(
          initialEmail: email,
          emailReadOnly: true,
          onSend: service.requestPasswordReset,
          backLabel: 'Back to profile',
          onBack: () => Navigator.maybePop(context)));
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
                      title: Text(switch (d['status']) {
                        'ready' => 'Your food is ready for pickup',
                        'collected' => 'Your pickup was collected',
                        'cancelled' => 'Your reservation was cancelled',
                        'noshow' => 'Your pickup was not collected',
                        _ => 'Your reservation is confirmed',
                      }),
                      subtitle: Text('${d['title']}\n${pickupWindow(d)}'),
                      isThreeLine: true));
            }),
          ]));
}
