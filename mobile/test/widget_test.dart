import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/main.dart';
import 'package:foodienoms/demo_store.dart';

void main(){
  testWidgets('role selector opens student discovery and switches experience',(tester)async{
    await tester.binding.setSurfaceSize(const Size(430,1000));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const FoodieNomsApp());
    expect(find.text('Choose your experience'),findsOneWidget);
    await tester.tap(find.text('Student'));await tester.pumpAndSettle();
    expect(find.text('Rescue delicious food.'),findsOneWidget);
    expect(find.text('Bakery Surprise Bag'),findsOneWidget);
    await tester.tap(find.byTooltip('Demo menu'));await tester.pumpAndSettle();
    await tester.tap(find.text('Switch experience'));await tester.pumpAndSettle();
    expect(find.text('Choose your experience'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('native student flow reserves and displays pickup code',(tester)async{
    await tester.binding.setSurfaceSize(const Size(430,1000));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    final store=DemoStore();addTearDown(store.dispose);
    await tester.pumpWidget(FoodieNomsApp(store:store));
    await tester.tap(find.text('Student'));await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bakery Surprise Bag'));await tester.tap(find.text('Bakery Surprise Bag'));await tester.pumpAndSettle();
    final reserve=find.text('Reserve for Pickup · RM 8.00');
    await tester.ensureVisible(reserve);await tester.tap(reserve);await tester.pumpAndSettle();
    final confirm=find.text('Confirm Reservation');
    await tester.ensureVisible(confirm);await tester.tap(confirm);await tester.pumpAndSettle();
    expect(find.text('Reservation confirmed!'),findsOneWidget);
    expect(store.reservations.length,1);expect(store.listing('bag').quantity,3);
    expect(find.text(store.reservations.single.code),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('admin approval updates pending vendor in mobile layout',(tester)async{
    await tester.binding.setSurfaceSize(const Size(390,844));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    final store=DemoStore();addTearDown(store.dispose);
    await tester.pumpWidget(FoodieNomsApp(store:store));
    await tester.tap(find.text('Administrator'));await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));await tester.pumpAndSettle();
    await tester.tap(find.text('Vendors').last);await tester.pumpAndSettle();
    final approve=find.text('Approve');await tester.ensureVisible(approve);await tester.tap(approve);await tester.pumpAndSettle();
    expect(store.vendor('cafe').status,'approved');expect(tester.takeException(),isNull);
  });
}
