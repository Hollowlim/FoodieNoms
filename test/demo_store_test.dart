import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/main.dart';

void main() {
  test('student reservation decrements stock and creates one booking', () {
    final store = DemoStore();
    final listing = store.deals.first;
    final before = listing.stock;
    final code = store.reserve(listing, 2);
    expect(code, isNotNull);
    expect(listing.stock, before - 2);
    expect(store.bookings.single.quantity, 2);
  });
  test('insufficient inventory never creates booking', () {
    final store = DemoStore();
    expect(store.reserve(store.deals.first, 100), isNull);
    expect(store.bookings, isEmpty);
  });
  test('vendor must be approved before publishing', () {
    final store = DemoStore();
    final initial = store.deals.length;
    store.addDeal('Fresh Rice', 4, 3);
    expect(store.deals.length, initial);
    store.approveVendor();
    store.addDeal('Fresh Rice', 4, 3);
    expect(store.deals.length, initial + 1);
  });
  test('pickup code is single-use', () {
    final store = DemoStore();
    final code = store.reserve(store.deals.first, 1)!;
    expect(store.collect(code), isTrue);
    expect(store.collect(code), isFalse);
  });
}
