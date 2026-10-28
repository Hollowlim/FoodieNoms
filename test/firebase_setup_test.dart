import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodienoms/firebase/app.dart';
import 'package:foodienoms/firebase/service.dart';

void main() {
  testWidgets('customers see food exploration and their pickups',
      (tester) async {
    int selected = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: FoodieNavigation(
                role: 'customer',
                selectedIndex: 0,
                onSelected: (value) => selected = value))));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Listings'), findsNothing);
    await tester.tap(find.text('Orders'));
    expect(selected, 2);
  });
  testWidgets('vendors see listings and pickup management', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: FoodieNavigation(
                role: 'vendor', selectedIndex: 0, onSelected: (_) {}))));
    expect(find.text('Listings'), findsOneWidget);
    expect(find.text('Pickups'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });
  testWidgets('admins see vendor approval navigation', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: FoodieNavigation(
                role: 'admin', selectedIndex: 0, onSelected: (_) {}))));
    expect(find.text('Vendors'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Orders'), findsNothing);
  });
  testWidgets(
      'unconfigured Firebase explains setup without exposing demo roles',
      (tester) async {
    await tester.pumpWidget(const FirebaseSetupApp());
    expect(find.text('Connect FoodieNoms to Firebase'), findsOneWidget);
    expect(find.textContaining('docs/FIREBASE_SETUP.md'), findsOneWidget);
    expect(find.text('Student demo'), findsNothing);
  });
  test('auth failures provide an actionable message', () {
    expect(firebaseMessage(FirebaseAuthException(code: 'invalid-credential')),
        'Email or password is incorrect.');
    expect(
        firebaseMessage(FirebaseAuthException(code: 'network-request-failed')),
        'Check your connection and try again.');
  });
  test('integer cents format without changing the order price', () {
    expect(money(990), 'RM 9.90');
    expect(money(1), 'RM 0.01');
    expect(money(800 * 3), 'RM 24.00');
  });
}
