import 'dart:async';
import 'package:flutter/material.dart';
import 'password_reset.dart';
export 'password_reset.dart';
import 'reference_assets.dart';

class PasswordRecoveryScreen extends StatelessWidget {
  const PasswordRecoveryScreen(
      {super.key, required this.onSend, this.initialEmail = ''});
  final SendPasswordReset onSend;
  final String initialEmail;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
          child: PasswordRecoveryForm(
              initialEmail: initialEmail,
              onSend: onSend,
              onBack: () => Navigator.maybePop(context))));
}

/// Shared by public customer/vendor/admin login and signed-in account settings.
class PasswordRecoveryForm extends StatefulWidget {
  const PasswordRecoveryForm(
      {super.key,
      required this.onSend,
      this.initialEmail = '',
      this.onBack,
      this.backLabel = 'Back to sign in',
      this.emailReadOnly = false,
      this.resendDelay = const Duration(seconds: 60)});
  final SendPasswordReset onSend;
  final String initialEmail, backLabel;
  final VoidCallback? onBack;
  final bool emailReadOnly;
  final Duration resendDelay;
  @override
  State<PasswordRecoveryForm> createState() => _PasswordRecoveryFormState();
}

class _PasswordRecoveryFormState extends State<PasswordRecoveryForm> {
  late final email = TextEditingController(text: widget.initialEmail);
  final form = GlobalKey<FormState>();
  Timer? timer;
  String? sentTo, error;
  bool busy = false;
  int seconds = 0;

  void cooldown() {
    timer?.cancel();
    seconds = widget.resendDelay.inSeconds;
    if (seconds <= 0) return;
    timer = Timer.periodic(const Duration(seconds: 1), (current) {
      if (!mounted) return current.cancel();
      setState(() => seconds--);
      if (seconds <= 0) current.cancel();
    });
  }

  Future<void> send() async {
    if (busy || seconds > 0) return;
    if (sentTo == null && !form.currentState!.validate()) return;
    final target = sentTo ?? email.text.trim().toLowerCase();
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSend(target);
      if (!mounted) return;
      setState(() {
        sentTo = target;
        cooldown();
      });
    } catch (failure) {
      if (mounted) setState(() => error = passwordRecoveryError(failure));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
              key: form,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandLogo(height: 86),
                        const SizedBox(height: 24),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFE8F1DF),
                                child: Icon(
                                    sentTo == null
                                        ? Icons.lock_reset_rounded
                                        : Icons.mark_email_unread_outlined,
                                    color: const Color(0xFF205F45),
                                    size: 28))),
                        const SizedBox(height: 18),
                        Text(
                            sentTo == null
                                ? 'Forgot your password?'
                                : 'Check your email',
                            style: const TextStyle(
                                color: Color(0xFF153D29),
                                fontSize: 28,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        if (sentTo == null) ...[
                          const Text(
                              'Customers, vendors and administrators can reset their password using their registered email address.'),
                          const SizedBox(height: 22),
                          TextFormField(
                              key: const ValueKey('recovery-email'),
                              controller: email,
                              enabled: !busy,
                              readOnly: widget.emailReadOnly,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.email],
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: validateRecoveryEmail,
                              onChanged: (_) {
                                if (error != null) setState(() => error = null);
                              },
                              onFieldSubmitted: (_) => send(),
                              decoration: InputDecoration(
                                  labelText: 'Registered email address',
                                  hintText: 'name@gmail.com',
                                  helperText: widget.emailReadOnly
                                      ? 'Your current account’s email address.'
                                      : 'Use the same email as your FoodieNoms account.',
                                  helperMaxLines: 3,
                                  errorMaxLines: 3,
                                  prefixIcon:
                                      const Icon(Icons.email_outlined))),
                        ] else ...[
                          Text(
                              'If an account uses $sentTo, a password reset link will arrive in its inbox.'),
                          const SizedBox(height: 20),
                          Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF0F5E9),
                                  borderRadius: BorderRadius.circular(16)),
                              child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('1. Open your Gmail or email inbox.'),
                                    SizedBox(height: 10),
                                    Text(
                                        '2. Open the FoodieNoms reset email and tap the reset link.'),
                                    SizedBox(height: 10),
                                    Text(
                                        '3. Choose a new password, then return to FoodieNoms to sign in.'),
                                  ])),
                          const SizedBox(height: 16),
                          const Text(
                              'Check Spam or Junk if the email has not arrived. If a link has expired or was already used, request another email.',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                        ],
                        if (error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Semantics(
                                  liveRegion: true,
                                  child: Text(error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)))),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                            key: const ValueKey('recovery-send'),
                            onPressed: busy || seconds > 0 ? null : send,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                backgroundColor: const Color(0xFF153D29)),
                            icon: busy
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.send_outlined, size: 19),
                            label: Text(
                                busy
                                    ? 'Sending…'
                                    : sentTo == null
                                        ? 'Send password reset link'
                                        : seconds > 0
                                            ? 'Resend in ${seconds}s'
                                            : 'Resend reset email',
                                textAlign: TextAlign.center)),
                        if (sentTo != null && !widget.emailReadOnly)
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                        timer?.cancel();
                                        seconds = 0;
                                        sentTo = null;
                                        error = null;
                                      }),
                              child:
                                  const Text('Use a different email address')),
                        if (widget.onBack != null)
                          TextButton(
                              onPressed: busy ? null : widget.onBack,
                              child: Text(widget.backLabel)),
                      ])))));
}
