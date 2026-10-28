import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/admin_preview.dart';

void main() {
  testWidgets('admin preview records a vendor review in local activity',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminPreview()));
    expect(find.byType(Drawer), findsNothing);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Vendors')));
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
}
