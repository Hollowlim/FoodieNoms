import 'package:firebase_auth/firebase_auth.dart';
import 'admin_identity.dart';

typedef SendPasswordReset = Future<void> Function(String email);

String? validateRecoveryEmail(String? input) {
  final value = input?.trim() ?? '';
  if (value.isEmpty) return 'Enter your registered email address.';
  if (value.length > 254 ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
    return 'Enter a valid email address, for example name@gmail.com.';
  }
  return null;
}

String initialRecoveryEmail(String input,
    {String bootstrapEmail = adminBootstrapEmail}) {
  if (input.trim().isEmpty) return '';
  try {
    final value = adminEmailForLogin(input, bootstrapEmail: bootstrapEmail);
    return validateRecoveryEmail(value) == null ? value : '';
  } on StateError {
    return '';
  }
}

/// Firebase sends a secure link to the registered address for every role.
/// A missing account has the same public result as an existing account.
Future<void> requestPasswordResetEmail(String input,
    {required SendPasswordReset send}) async {
  final validation = validateRecoveryEmail(input);
  if (validation != null) throw StateError(validation);
  try {
    await send(input.trim().toLowerCase());
  } on FirebaseAuthException catch (error) {
    if (error.code != 'user-not-found') rethrow;
  }
}

String passwordRecoveryError(Object error) {
  if (error is StateError) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid registered email address.',
      'network-request-failed' =>
        'Check your internet connection and try sending again.',
      'too-many-requests' ||
      'quota-exceeded' =>
        'Too many reset requests. Please wait and try again later.',
      _ => 'Unable to send the reset email right now. Please try again later.',
    };
  }
  return 'Unable to send the reset email. Check your connection and try again.';
}
