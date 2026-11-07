import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/password_recovery.dart';

Finder emailField() => find.byKey(const ValueKey('recovery-email'));
Finder sendButton() => find.byKey(const ValueKey('recovery-send'));
Widget page(
        {required SendPasswordReset send,
        String initial = '',
        bool readOnly = false,
        VoidCallback? onBack}) =>
    MaterialApp(
        home: Scaffold(
            body: PasswordRecoveryForm(
                onSend: send,
                initialEmail: initial,
                emailReadOnly: readOnly,
                onBack: onBack)));
Future<void> send(WidgetTester t) async {
  await t.ensureVisible(sendButton());
  await t.tap(sendButton());
  await t.pumpAndSettle();
}

void main() {
  test('validates registered email and resolves existing administrator aliases',
      () {
    for (final input in [
      '',
      'wrong',
      'a@@gmail.com',
      'a b@gmail.com',
      'x@gmail',
      'a' * 255
    ]) {
      expect(validateRecoveryEmail(input), isNotNull);
    }
    expect(validateRecoveryEmail(' Customer@Gmail.com '), isNull);
    expect(validateRecoveryEmail('vendor@example.org'), isNull);
    expect(initialRecoveryEmail('Admin123', bootstrapEmail: 'owner@gmail.com'),
        'owner@gmail.com');
    expect(initialRecoveryEmail('Admin123', bootstrapEmail: ''), '');
    expect(initialRecoveryEmail('staff.admin'), 'staff.admin@gmail.com');
    expect(initialRecoveryEmail('customer@gmail.com'), 'customer@gmail.com');
    expect(initialRecoveryEmail('invalid name'), '');
  });
  test(
      'shared request normalizes addresses and does not disclose missing accounts',
      () async {
    String? received;
    await requestPasswordResetEmail(' Vendor@Gmail.com ',
        send: (address) async {
      received = address;
    });
    expect(received, 'vendor@gmail.com');
    await requestPasswordResetEmail('missing@gmail.com', send: (_) async {
      throw FirebaseAuthException(code: 'user-not-found');
    });
    expect(() => requestPasswordResetEmail('invalid', send: (_) async {}),
        throwsStateError);
    await expectLater(
        requestPasswordResetEmail('valid@gmail.com', send: (_) async {
          throw FirebaseAuthException(code: 'network-request-failed');
        }),
        throwsA(isA<FirebaseAuthException>()));
  });
  testWidgets(
      'forgot password works without typing anything into the login screen first',
      (t) async {
    var requests = 0;
    await t.pumpWidget(page(send: (_) async {
      requests++;
    }));
    await send(t);
    expect(find.text('Enter your registered email address.'), findsOneWidget);
    expect(requests, 0);
    await t.enterText(emailField(), 'student@gmail.com');
    await t.pumpAndSettle();
    expect(find.text('Enter your registered email address.'), findsNothing);
    await send(t);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('If an account uses student@gmail.com'),
        findsOneWidget);
    expect(find.text('Resend in 60s'), findsOneWidget);
    expect(requests, 1);
    await t.pumpWidget(const SizedBox());
  });
  for (final role in ['customer', 'vendor', 'admin']) {
    testWidgets(
        '$role can use the same email recovery flow without changing account type',
        (t) async {
      String? target;
      await t.pumpWidget(page(
          send: (email) async {
            target = email;
          },
          initial: '$role@gmail.com'));
      await send(t);
      expect(target, '$role@gmail.com');
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('Check Spam or Junk'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'busy request prevents double sends and failure keeps the email for retry',
      (t) async {
    var requests = 0;
    final pending = Completer<void>();
    await t.pumpWidget(page(
        send: (_) {
          requests++;
          return pending.future;
        },
        initial: 'vendor@gmail.com'));
    await t.ensureVisible(sendButton());
    await t.tap(sendButton());
    await t.pump();
    await t.tap(sendButton());
    expect(requests, 1);
    pending
        .completeError(FirebaseAuthException(code: 'network-request-failed'));
    await t.pumpAndSettle();
    expect(
        find.textContaining('Check your internet connection'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
    expect(t.widget<TextFormField>(emailField()).controller!.text,
        'vendor@gmail.com');
  });
  testWidgets(
      'resend cooldown counts down and returning before it expires cancels the timer',
      (t) async {
    var requests = 0;
    await t.pumpWidget(page(
        send: (_) async {
          requests++;
        },
        initial: 'client@gmail.com'));
    await send(t);
    await t.ensureVisible(sendButton());
    expect(t.widget<FilledButton>(sendButton()).onPressed, isNull);
    await t.tap(sendButton());
    expect(requests, 1);
    await t.pump(const Duration(seconds: 60));
    await t.pump();
    expect(find.text('Resend reset email'), findsOneWidget);
    await send(t);
    expect(requests, 2);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('correcting a mistyped address allows a fresh request',
      (t) async {
    final recipients = <String>[];
    await t.pumpWidget(page(
        send: (email) async {
          recipients.add(email);
        },
        initial: 'wrong@gmail.com'));
    await send(t);
    await t.ensureVisible(find.text('Use a different email address'));
    await t.tap(find.text('Use a different email address'));
    await t.pumpAndSettle();
    await t.enterText(emailField(), 'right@gmail.com');
    await send(t);
    expect(recipients, ['wrong@gmail.com', 'right@gmail.com']);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'account settings use the registered address and provide a return action',
      (t) async {
    var returned = false;
    await t.pumpWidget(page(
        send: (_) async {},
        initial: 'admin@gmail.com',
        readOnly: true,
        onBack: () => returned = true));
    expect(
        t
            .widget<TextField>(find.descendant(
                of: emailField(), matching: find.byType(TextField)))
            .readOnly,
        isTrue);
    await send(t);
    expect(find.text('Use a different email address'), findsNothing);
    await t.ensureVisible(find.text('Back to sign in'));
    await t.tap(find.text('Back to sign in'));
    expect(returned, isTrue);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'recovery content fits a small phone with large text and the keyboard open',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.3),
                viewInsets: EdgeInsets.only(bottom: 250)),
            child:
                Scaffold(body: PasswordRecoveryForm(onSend: (_) async {})))));
    await t.ensureVisible(emailField());
    await t.enterText(emailField(), 'a.very.long.registered.address@gmail.com');
    await send(t);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
