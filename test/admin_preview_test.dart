import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/admin_preview.dart';

void main() {
  testWidgets('admin preview records a vendor review in local activity',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminPreview()));
    expect(find.byType(Drawer), findsNothing);
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Vendors')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();
    expect(find.text('Approved'), findsNWidgets(2));
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Subang Cafe · Approved'), findsOneWidget);
  });
  testWidgets('demo directs live approvals back to real admin sign-in',
      (tester) async {
    bool? live;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      live = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminPreview()));
                    },
                    child: const Text('Open demo'))))));
    await tester.tap(find.text('Open demo'));
    await tester.pumpAndSettle();
    expect(find.text('This demo does not show registered vendors.'),
        findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sign in to live admin'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to live admin'));
    await tester.pumpAndSettle();
    expect(live, isTrue);
    expect(find.text('Open demo'), findsOneWidget);
  });
}
