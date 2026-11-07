// Verifies Firebase password reset end to end without sending any real emails.
// Run: sh tool/run_password_reset_check.sh
// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:foodienoms/firebase/service.dart';

const project = 'demo-foodienoms';
const options = FirebaseOptions(
    apiKey: 'demo',
    appId: '1:1:web:1',
    messagingSenderId: '1',
    projectId: project);

Future<void> checkRole(String role) async {
  final auth = FirebaseAuth.instance;
  final service = FoodieService(authEmulatorHost: '127.0.0.1');
  final email = '$role-reset@example.test';
  const oldPassword = 'Emulator-before!123';
  const newPassword = 'Emulator-after!456';
  final user = (await auth.createUserWithEmailAndPassword(
          email: email, password: oldPassword))
      .user!;
  final uid = user.uid;
  await auth.signOut();
  // The production service works while signed out and requires no role lookup.
  await service.requestPasswordReset(email.toUpperCase());
  final response = await http.get(Uri.parse(
      'http://127.0.0.1:9099/emulator/v1/projects/$project/oobCodes'));
  if (response.statusCode != 200) {
    throw StateError('Could not inspect emulator email outbox.');
  }
  final records = (jsonDecode(response.body) as Map)['oobCodes'] as List;
  final record = records.cast<Map>().lastWhere((value) =>
      value['email'] == email && value['requestType'] == 'PASSWORD_RESET');
  final code = record['oobCode'] as String;
  final verified = await auth.verifyPasswordResetCode(code);
  if (verified != email) {
    throw StateError('Reset link was addressed to the wrong account.');
  }
  // This is the same Firebase operation used by the hosted reset-email page.
  await auth.confirmPasswordReset(code: code, newPassword: newPassword);
  try {
    await auth.confirmPasswordReset(
        code: code, newPassword: 'Unexpected-reuse!789');
    throw StateError('The reset link was reusable.');
  } on FirebaseAuthException catch (error) {
    if (error.code != 'invalid-action-code') rethrow;
  }
  try {
    await auth.signInWithEmailAndPassword(email: email, password: oldPassword);
    throw StateError('The old password still works.');
  } on FirebaseAuthException catch (error) {
    if (!['invalid-credential', 'wrong-password'].contains(error.code)) rethrow;
  }
  final changed = (await auth.signInWithEmailAndPassword(
          email: email, password: newPassword))
      .user!;
  if (changed.uid != uid || changed.email != email) {
    throw StateError('Reset changed the account identity.');
  }
  // A signed-in user can also request recovery without switching their session.
  await service.requestPasswordReset(email);
  if (auth.currentUser?.uid != uid) {
    throw StateError('Sending reset email switched the active user.');
  }
  await auth.signOut();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: options);
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  var failures = 0;
  for (final role in ['customer', 'vendor', 'admin']) {
    try {
      await checkRole(role);
      print(
          'CLIENT_CHECK pass: $role email reset, one-time link and new-password login');
    } catch (error) {
      failures++;
      print('CLIENT_CHECK FAIL: $role: $error');
    }
  }
  try {
    await FoodieService().requestPasswordReset('unregistered@example.test');
    print(
        'CLIENT_CHECK pass: unregistered address has the same neutral public response');
  } catch (error) {
    failures++;
    print('CLIENT_CHECK FAIL: missing account: $error');
  }
  print('CLIENT_CHECK_DONE failed=$failures');
}
