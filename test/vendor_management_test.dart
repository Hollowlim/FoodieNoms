import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/vendor_management.dart';

ManagedVendor vendor(String id,
        {bool approved = false,
        bool revoked = false,
        String? email,
        Map<String, dynamic> business = const {}}) =>
    ManagedVendor(
        id: id,
        profile: {
          'name': 'Vendor $id',
          'approved': approved,
          if (revoked) 'revokedAt': 1,
          if (email != null) 'email': email
        },
        business: business);

void main() {
  test(
      'vendor status distinguishes waiting accounts and revoked accounts, including reapproval',
      () {
    expect(vendor('pending').status, VendorStatus.pending);
    expect(vendor('revoked', revoked: true).status, VendorStatus.revoked);
    expect(vendor('approved', approved: true).status, VendorStatus.approved);
    expect(vendor('reapproved', approved: true, revoked: true).status,
        VendorStatus.approved);
    expect(vendor('without-email').email, isNull);
  });
  test('live summary counts accounts and only configured, valid shop pins', () {
    final records = [
      vendor('a'),
      vendor('b', approved: true, business: {
        'configured': true,
        'approved': true,
        'latitude': 3.0567,
        'longitude': 101.5851
      }),
      vendor('c', revoked: true, business: {
        'configured': true,
        'approved': false,
        'latitude': 3.05,
        'longitude': 101.58
      }),
      vendor('d',
          approved: true,
          business: {'configured': true, 'latitude': 91, 'longitude': 101}),
      vendor('e',
          business: {'configured': false, 'latitude': 3, 'longitude': 101}),
    ];
    final summary = VendorSummary(records);
    expect(summary.total, 5);
    expect(summary.pending, 2);
    expect(summary.approved, 2);
    expect(summary.revoked, 1);
    expect(summary.shopsWithMapPin, 2);
    expect(records[1].visibleOnMap, isTrue);
    expect(records[2].visibleOnMap, isFalse);
    expect(
        vendor('invalid', business: {
          'configured': true,
          'latitude': double.nan,
          'longitude': 101
        }).hasMapPin,
        isFalse);
  });
  test(
      'vendor search joins account name, saved email and business name, pending first',
      () {
    final records = [
      vendor('approved', approved: true),
      vendor('pending',
          email: 'owner@example.test',
          business: {'businessName': 'Subang Bakery'}),
      vendor('revoked', revoked: true)
    ];
    expect(filterManagedVendors(records).map((v) => v.id),
        ['pending', 'approved', 'revoked']);
    expect(
        filterManagedVendors(records, search: ' SUBANG ').single.id, 'pending');
    expect(
        filterManagedVendors(records, search: 'OWNER@EXAMPLE.TEST').single.id,
        'pending');
    expect(
        filterManagedVendors(records, status: VendorStatus.approved).single.id,
        'approved');
    expect(filterManagedVendors(records, search: 'not saved'), isEmpty);
    expect(records.first.id, 'approved');
  });
  testWidgets('revoking requires a reason and returns only after confirmation',
      (tester) async {
    String? decision;
    var completed = false;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () async {
                      decision = await showDialog<String>(
                          context: context,
                          builder: (_) => const VendorApprovalDialog(
                              vendorName: 'Subang Bakery', approve: false));
                      completed = true;
                    },
                    child: const Text('Review'))))));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'This stops new listings and new reservations and removes the shop from the customer map. Existing orders are kept.'),
        findsOneWidget);
    await tester.tap(find.text('Revoke approval'));
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(find.text('Enter a reason.'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField), '  Pickup location needs review.  ');
    await tester.tap(find.text('Revoke approval'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(decision, 'Pickup location needs review.');
  });
  testWidgets('approval can be cancelled without an action', (tester) async {
    String? decision = 'unchanged';
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () async {
                      decision = await showDialog<String>(
                          context: context,
                          builder: (_) => const VendorApprovalDialog(
                              vendorName: 'Subang Bakery',
                              approve: true,
                              reapproval: true));
                    },
                    child: const Text('Review'))))));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Approve this vendor again?'), findsOneWidget);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(decision, isNull);
  });
  testWidgets(
      'overview links open real vendor review and administrator management',
      (tester) async {
    var reviewed = false, administrators = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminOverviewContent(
                summary: VendorSummary([vendor('pending')]),
                onReviewVendors: () => reviewed = true,
                onAdministrators: () => administrators = true))));
    expect(find.text('1 vendors awaiting review'), findsOneWidget);
    await tester.ensureVisible(find.text('Review vendors'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review vendors'));
    expect(reviewed, isTrue);
    await tester.scrollUntilVisible(find.text('Manage administrators'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage administrators'));
    expect(administrators, isTrue);
  });
}
