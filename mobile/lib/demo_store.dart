import 'dart:math';
import 'package:flutter/foundation.dart';

class FoodVendor {
  FoodVendor(this.id, this.name, this.address, {this.status = 'pending'});
  final String id, name, address;
  String status;
}

class FoodListing {
  FoodListing({required this.id, required this.vendorId, required this.title,
    required this.description, required this.category, required this.price,
    required this.original, required this.quantity, this.pickup = '5–7 PM',
    this.status = 'active'});
  final String id, vendorId;
  String title, description, category, pickup, status;
  double price, original;
  int quantity;
  String get emoji => switch (category) {
    'Meals' => '🍱', 'Pastries' => '🧁', 'Drinks' => '☕', _ => '🥐',
  };
}

class Reservation {
  Reservation({required this.id, required this.listingId, required this.vendorId,
    required this.title, required this.quantity, required this.total,
    required this.saving, required this.pickup, required this.code});
  final String id, listingId, vendorId, title, pickup, code;
  final int quantity;
  final double total, saving;
  String status = 'Reserved';
}

String money(num amount) => 'RM ${amount.toStringAsFixed(2)}';

class DemoStore extends ChangeNotifier {
  final List<FoodVendor> vendors = [];
  final List<FoodListing> listings = [];
  final List<Reservation> reservations = [];
  final Set<String> favourites = {};
  final List<String> activity = [];
  String studentName = 'Student Account';
  String studentEmail = 'student@example.com';
  int _nextListing = 1;
  int _nextReservation = 1;
  DemoStore() { reset(); }

  FoodVendor vendor(String id) => vendors.firstWhere((v) => v.id == id);
  FoodListing listing(String id) => listings.firstWhere((v) => v.id == id);
  List<FoodListing> get available => listings.where((l) =>
    l.status == 'active' && l.quantity > 0 && vendor(l.vendorId).status == 'approved').toList();

  void reset() {
    vendors..clear()..addAll([
      FoodVendor('bakery', 'Sample Bakery', 'SS15, Subang Jaya', status: 'approved'),
      FoodVendor('cafe', 'Subang Cafe', 'SS15, Subang Jaya'),
    ]);
    listings..clear()..addAll([
      FoodListing(id:'bag', vendorId:'bakery', title:'Bakery Surprise Bag',
        description:'A delicious selection of today’s croissants, breads and pastries. Freshly baked and too good to waste.',
        category:'Bakery', price:8, original:20, quantity:4),
      FoodListing(id:'lunch', vendorId:'bakery', title:'Cafe Lunch Box',
        description:'A comforting lunch of rice, vegetables and a delicious daily main.',
        category:'Meals', price:9.9, original:18, quantity:3, pickup:'4–6 PM'),
      FoodListing(id:'pastry', vendorId:'bakery', title:'Pastry Selection',
        description:'A little sweetness for your day. An assortment of handmade pastries from today’s bake.',
        category:'Pastries', price:6.5, original:15, quantity:5, pickup:'6–8 PM'),
    ]);
    reservations.clear(); favourites.clear(); activity.clear();
    studentName = 'Student Account'; studentEmail = 'student@example.com';
    _nextListing = 1; _nextReservation = 1;
    notifyListeners();
  }

  void approveVendor(String id, {bool approve = true}) {
    final v = vendor(id);
    v.status = approve ? 'approved' : 'rejected';
    activity.insert(0, '${v.name} ${v.status} by demo administrator');
    notifyListeners();
  }

  void saveListing({String? id, required String title, required String description,
    required String category, required double price, required double original,
    required int quantity, required String pickup}) {
    if (title.trim().isEmpty || description.trim().isEmpty || !price.isFinite ||
        !original.isFinite || price <= 0 || price >= original || quantity < 0 || quantity > 1000) {
      throw StateError('Enter a name, description, valid stock and a rescue price below the original price.');
    }
    if (!['Bakery','Meals','Pastries','Drinks'].contains(category) ||
        !['4–6 PM','5–7 PM','6–8 PM'].contains(pickup)) {
      throw StateError('Choose a valid food category and pickup window.');
    }
    if (id == null) {
      if (vendor('cafe').status != 'approved') {
        throw StateError('Subang Cafe needs Admin approval before publishing.');
      }
      listings.insert(0, FoodListing(id:'demo-${_nextListing++}', vendorId:'cafe',
        title:title.trim(), description:description.trim(), category:category,
        price:price, original:original, quantity:quantity, pickup:pickup));
    } else {
      final l = listing(id);
      l.title = title.trim(); l.description = description.trim();
      l.category = category; l.price = price; l.original = original;
      l.quantity = quantity; l.pickup = pickup;
    }
    activity.insert(0, '${title.trim()} ${id == null ? 'published' : 'updated'}');
    notifyListeners();
  }

  Reservation reserve(String listingId, int quantity) {
    final l = listing(listingId);
    if (!available.contains(l) || quantity < 1 || quantity > l.quantity) {
      throw StateError('This quantity is no longer available. Please choose another deal.');
    }
    final order = Reservation(id:'FN-${(_nextReservation++).toString().padLeft(3, '0')}',
      listingId:l.id, vendorId:l.vendorId, title:l.title, quantity:quantity,
      total:(l.price * quantity * 100).round() / 100,
      saving:((l.original-l.price) * quantity * 100).round() / 100,
      pickup:l.pickup, code:(100000 + Random.secure().nextInt(900000)).toString());
    l.quantity -= quantity; reservations.insert(0, order);
    activity.insert(0, '${order.id} reserved'); notifyListeners(); return order;
  }

  void cancel(Reservation order) {
    if (!reservations.contains(order) || order.status != 'Reserved') {
      throw StateError('Only reserved orders can be cancelled.');
    }
    order.status = 'Cancelled'; listing(order.listingId).quantity += order.quantity;
    activity.insert(0, '${order.id} cancelled'); notifyListeners();
  }

  void collect(Reservation order, String code) {
    if (!reservations.contains(order) || order.status != 'Reserved') {
      throw StateError('This reservation is not awaiting collection.');
    }
    if (order.code != code.trim()) { throw StateError('Pickup code does not match.'); }
    order.status = 'Collected'; activity.insert(0, '${order.id} collected'); notifyListeners();
  }

  void toggleFavourite(String id) {
    if (!favourites.add(id)) { favourites.remove(id); }
    notifyListeners();
  }
  void moderate(FoodListing l) {
    l.status = l.status == 'active' ? 'hidden' : 'active';
    activity.insert(0, '${l.title} ${l.status}'); notifyListeners();
  }
  void saveProfile(String name, String email) {
    if (name.trim().isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      throw StateError('Enter a name and valid email address.');
    }
    studentName = name.trim(); studentEmail = email.trim(); notifyListeners();
  }
}
