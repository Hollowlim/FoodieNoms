import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/demo_store.dart';

void main(){
  late DemoStore store;
  setUp(()=>store=DemoStore());
  tearDown(()=>store.dispose());
  test('reservation snapshots prices and prevents overselling',(){
    final order=store.reserve('bag',4);
    expect(order.total,32);expect(order.saving,48);expect(store.listing('bag').quantity,0);
    expect(()=>store.reserve('bag',1),throwsStateError);
    expect(order.code, matches(RegExp(r'^\d{6}$')));
  });
  test('invalid quantities do not mutate stock',(){
    expect(()=>store.reserve('bag',0),throwsStateError);
    expect(()=>store.reserve('bag',-2),throwsStateError);
    expect(store.listing('bag').quantity,4);expect(store.reservations,isEmpty);
  });
  test('cancel restores stock once',(){
    final order=store.reserve('bag',2);store.cancel(order);
    expect(order.status,'Cancelled');expect(store.listing('bag').quantity,4);
    expect(()=>store.cancel(order),throwsStateError);
    expect(store.listing('bag').quantity,4);
  });
  test('pickup requires correct code and is single-use',(){
    final order=store.reserve('bag',1);
    expect(()=>store.collect(order,'wrong'),throwsStateError);
    expect(order.status,'Reserved');store.collect(order,order.code);
    expect(order.status,'Collected');expect(()=>store.collect(order,order.code),throwsStateError);
    expect(()=>store.cancel(order),throwsStateError);
  });
  test('vendor approval gates listing publication',(){
    void publish()=>store.saveListing(title:'Demo Bag',description:'Today’s bake',category:'Bakery',price:7,original:20,quantity:3,pickup:'5–7 PM');
    expect(publish,throwsStateError);store.approveVendor('cafe');publish();
    expect(store.available.first.title,'Demo Bag');expect(store.available.first.vendorId,'cafe');
  });
  test('moderation removes deals from discovery and blocks reservation',(){
    final listing=store.listing('bag');store.moderate(listing);
    expect(store.available.contains(listing),isFalse);expect(()=>store.reserve('bag',1),throwsStateError);
    store.moderate(listing);expect(store.available.contains(listing),isTrue);
  });
  test('price validation and historic totals survive listing edits',(){
    final order=store.reserve('bag',1);
    void edit(double price)=>store.saveListing(id:'bag',title:'Updated bag',description:'Fresh pastries',category:'Bakery',price:price,original:20,quantity:3,pickup:'5–7 PM');
    expect(()=>edit(double.nan),throwsStateError);expect(()=>edit(20),throwsStateError);
    edit(9);expect(order.total,8);expect(order.saving,12);
  });
  test('profile validation and reset',(){
    expect(()=>store.saveProfile('','bad'),throwsStateError);
    expect(store.studentName,'Student Account');
    store.saveProfile('Demo Student','demo@example.com');
    store.toggleFavourite('bag');store.reserve('bag',1);store.reset();
    expect(store.reservations,isEmpty);expect(store.favourites,isEmpty);
    expect(store.listing('bag').quantity,4);expect(store.vendor('cafe').status,'pending');
    expect(store.studentName,'Student Account');
  });
}
