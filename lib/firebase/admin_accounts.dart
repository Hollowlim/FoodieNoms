import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'service.dart';
import 'admin_identity.dart';
import 'management_ui.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key, required this.service});
  final FoodieService service;
  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  late final stream = widget.service.db
      .collection('users')
      .where('role', isEqualTo: 'admin')
      .snapshots();
  final sending = <String>{};
  Future<void> resend(String email) async {
    setState(() => sending.add(email));
    try {
      await widget.service.auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Password setup email sent. Ask the administrator to check their inbox.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(firebaseMessage(e))));
      }
    } finally {
      if (mounted) setState(() => sending.remove(email));
    }
  }

  Future<void> add() async {
    final result = await Navigator.push<AdminCreationResult>(
        context,
        MaterialPageRoute(
            builder: (_) => AddAdministratorScreen(service: widget.service)));
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.setupEmailSent
              ? 'Administrator created. A password setup email has been sent.'
              : 'Administrator created, but the setup email failed. Use Send password setup to retry.')));
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Administrators',
            style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: managementInk)),
        const SizedBox(height: 8),
        const Text(
            'Add a separate account for each person who manages FoodieNoms.'),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: add,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Add administrator')),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(firebaseMessage(snapshot.error!));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(children: [
                for (final doc in snapshot.data!.docs)
                  Builder(builder: (context) {
                    final data = doc.data();
                    final own = doc.id == widget.service.auth.currentUser?.uid;
                    final email = data['email'] as String? ??
                        (own ? widget.service.auth.currentUser?.email : null);
                    return ManagementCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('${data['name']}${own ? ' (you)' : ''}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          if (email != null) ...[
                            Text(email),
                            const SizedBox(height: 6),
                            Text(
                                'Username: ${own && adminBootstrapEmail.isNotEmpty && email.toLowerCase() == adminBootstrapEmail.toLowerCase() ? 'Admin123' : adminUsernameForEmail(email)}'),
                            TextButton.icon(
                                onPressed: sending.contains(email)
                                    ? null
                                    : () => resend(email),
                                icon: const Icon(Icons.mail_outline),
                                label: const Text('Send password setup')),
                          ],
                          const Text(
                              'Can review vendors and add administrators.',
                              style: TextStyle(color: Colors.black54)),
                        ]));
                  })
              ]);
            }),
      ]);
}

class AddAdministratorScreen extends StatefulWidget {
  const AddAdministratorScreen({super.key, required this.service});
  final FoodieService service;
  @override
  State<AddAdministratorScreen> createState() => _AddAdministratorScreenState();
}

class _AddAdministratorScreenState extends State<AddAdministratorScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      temporary = TextEditingController(),
      current = TextEditingController();
  bool showTemporary = false, showCurrent = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    temporary.text = 'Fn!${widget.service.requestId().substring(0, 20)}';
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    temporary.dispose();
    current.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Give administrator access?'),
                content: Text(
                    '${email.text.trim()} will be able to approve vendors and create other administrators.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Go back')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Create administrator'))
                ]));
    if (yes != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.createAdministrator(
          name: name.text,
          email: email.text,
          temporaryPassword: temporary.text,
          currentPassword: current.text);
      current.clear();
      temporary.clear();
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => error = firebaseMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget password(TextEditingController controller, String label, bool visible,
          VoidCallback toggle,
          {int minimum = 1}) =>
      TextFormField(
        controller: controller,
        enabled: !busy,
        obscureText: !visible,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
            labelText: label,
            suffixIcon: IconButton(
                tooltip: visible ? 'Hide password' : 'Show password',
                onPressed: busy ? null : toggle,
                icon: Icon(visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined))),
        validator: (v) => v == null || v.length < minimum
            ? 'Enter ${minimum > 1 ? 'at least $minimum characters' : 'your password'}.'
            : null,
      );
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Scaffold(
          appBar: AppBar(title: const Text('Add administrator')),
          body: SafeArea(
              child: Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    const Text('Create a separate admin account',
                        style: TextStyle(
                            fontSize: 25, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    const Text(
                        'Use a new email address. Existing vendor and customer accounts will not be converted. The new administrator will receive an email to choose their own password.'),
                    const SizedBox(height: 24),
                    TextFormField(
                        controller: name,
                        enabled: !busy,
                        maxLength: 100,
                        decoration: const InputDecoration(
                            labelText: 'Administrator name'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter a name.'
                            : null),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            labelText: 'New administrator email',
                            helperText:
                                'For Gmail, the part before @ is their username.'),
                        validator: (v) => v == null ||
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(v.trim())
                            ? 'Enter a valid email.'
                            : null),
                    const SizedBox(height: 16),
                    password(temporary, 'Temporary password', showTemporary,
                        () => setState(() => showTemporary = !showTemporary),
                        minimum: 12),
                    const SizedBox(height: 8),
                    TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  temporary.text =
                                      'Fn!${widget.service.requestId().substring(0, 20)}';
                                  showTemporary = false;
                                }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Generate another password')),
                    const Divider(height: 32),
                    password(
                        current,
                        'Confirm your admin password',
                        showCurrent,
                        () => setState(() => showCurrent = !showCurrent)),
                    const SizedBox(height: 16),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    FilledButton(
                        onPressed: busy ? null : submit,
                        child: Text(busy
                            ? 'Creating administrator…'
                            : 'Create administrator')),
                  ])))));
}
