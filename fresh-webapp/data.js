(function (root) {
  'use strict';

  const STORAGE_KEY = 'foodienoms.fresh.v1';

  function initialState() {
    return {
      version: 1,
      profile: { id: 'student-001', name: 'Aina Rahman', email: 'aina@student.example' },
      students: [
        { id: 'student-001', name: 'Aina Rahman', email: 'aina@student.example', status: 'active' },
        { id: 'student-002', name: 'Daniel Tan', email: 'daniel@student.example', status: 'active' },
        { id: 'student-003', name: 'Priya Kumar', email: 'priya@student.example', status: 'suspended' }
      ],
      vendors: [
        { id: 'bakery', name: 'Sample Bakery', status: 'approved', address: '12, Jalan SS15/4, Subang Jaya', hours: '09:00–20:00', category: 'Bakery', rating: 4.5 },
        { id: 'cafe', name: 'Subang Cafe', status: 'pending', address: '8, Jalan SS15/8, Subang Jaya', hours: '09:00–20:00', category: 'Cafe', rating: 4.6 }
      ],
      listings: [
        { id: 'bag', vendorId: 'bakery', name: 'Bakery Surprise Bag', category: 'Bakery', description: 'A delicious selection of freshly baked breads and pastries. The exact contents are a surprise, but good food is guaranteed.', priceCents: 800, originalPriceCents: 2000, quantity: 4, pickupStart: '17:00', pickupEnd: '19:00', image: 'bakery', active: true },
        { id: 'lunch', vendorId: 'bakery', name: 'Cafe Lunch Box', category: 'Meals', description: 'A satisfying cafe lunch, freshly prepared and packed for your afternoon. Contents vary with the day’s surplus.', priceCents: 990, originalPriceCents: 1800, quantity: 3, pickupStart: '16:00', pickupEnd: '18:00', image: 'lunch', active: true },
        { id: 'pastry', vendorId: 'bakery', name: 'Pastry Selection', category: 'Pastries', description: 'A little box of sweet moments: a selection of our remaining daily pastries, perfect for sharing.', priceCents: 650, originalPriceCents: 1500, quantity: 5, pickupStart: '18:00', pickupEnd: '20:00', image: 'pastry', active: true }
      ],
      orders: [],
      favourites: [],
      events: []
    };
  }

  function isMoney(value) {
    return Number.isSafeInteger(value) && value > 0;
  }

  function isStock(value) {
    return Number.isSafeInteger(value) && value >= 0;
  }

  function isTime(value) {
    return typeof value === 'string' && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(value);
  }

  function isText(value) {
    return typeof value === 'string' && value.trim().length > 0;
  }

  function validSavedState(saved) {
    if (!saved || saved.version !== 1 || !saved.profile || !isText(saved.profile.id) || !isText(saved.profile.name) || !isText(saved.profile.email)) return false;
    if (!['vendors', 'listings', 'students', 'orders', 'favourites', 'events'].every(function (key) { return Array.isArray(saved[key]); })) return false;
    if (!saved.vendors.length || !saved.students.length) return false;
    const vendorIds = new Set(saved.vendors.map(function (vendor) { return vendor.id; }));
    const listingIds = new Set(saved.listings.map(function (listing) { return listing.id; }));
    if (vendorIds.size !== saved.vendors.length || listingIds.size !== saved.listings.length) return false;
    if (!saved.vendors.every(function (vendor) { return isText(vendor.id) && isText(vendor.name) && ['approved', 'pending', 'rejected'].includes(vendor.status); })) return false;
    if (!saved.students.every(function (student) { return isText(student.id) && isText(student.name) && isText(student.email); })) return false;
    if (!saved.students.some(function (student) { return student.id === saved.profile.id; })) return false;
    if (!saved.listings.every(function (listing) {
      return isText(listing.id) && vendorIds.has(listing.vendorId) && isText(listing.name) && isText(listing.category) && typeof listing.description === 'string' && typeof listing.image === 'string' && isMoney(listing.priceCents) && isMoney(listing.originalPriceCents) && listing.priceCents <= listing.originalPriceCents && isStock(listing.quantity) && typeof listing.active === 'boolean' && isTime(listing.pickupStart) && isTime(listing.pickupEnd) && listing.pickupStart < listing.pickupEnd;
    })) return false;
    if (!saved.orders.every(function (order) {
      return isText(order.id) && isText(order.code) && listingIds.has(order.listingId) && vendorIds.has(order.vendorId) && isText(order.name) && isText(order.vendorName) && Number.isSafeInteger(order.quantity) && order.quantity > 0 && isMoney(order.unitPriceCents) && isMoney(order.originalUnitPriceCents) && isMoney(order.totalCents) && order.totalCents === order.unitPriceCents * order.quantity && ['reserved', 'collected', 'cancelled'].includes(order.status) && isTime(order.pickupStart) && isTime(order.pickupEnd) && isText(order.pickupDate) && isText(order.createdAt);
    })) return false;
    if (new Set(saved.orders.map(function (order) { return order.id; })).size !== saved.orders.length) return false;
    if (new Set(saved.orders.map(function (order) { return order.code; })).size !== saved.orders.length) return false;
    if (!saved.favourites.every(function (id) { return listingIds.has(id); })) return false;
    return saved.events.every(function (event) { return isText(event.id) && isText(event.type) && isText(event.message) && isText(event.createdAt); });
  }

  function createStore(storage) {
    let persistence = storage;
    if (typeof storage === 'undefined') {
      try { persistence = root.localStorage || null; } catch (_) { persistence = null; }
    }
    let state = initialState();
    if (persistence) {
      try {
        const saved = JSON.parse(persistence.getItem(STORAGE_KEY));
        if (validSavedState(saved)) state = saved;
      } catch (_) {
        // Private browsing, unavailable storage, and damaged data must not stop the demo.
      }
    }

    function persist() {
      if (!persistence) return;
      try { persistence.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (_) {
        // Continue in memory when the browser cannot save locally.
      }
    }

    function record(type, message) {
      state.events.unshift({ id: 'event-' + (state.events.length + 1), type: type, message: message, createdAt: new Date().toISOString() });
      persist();
    }

    function findVendor(id) {
      const vendor = state.vendors.find(function (item) { return item.id === id; });
      if (!vendor) throw new Error('Vendor not found.');
      return vendor;
    }

    function findListing(id) {
      const listing = state.listings.find(function (item) { return item.id === id; });
      if (!listing) throw new Error('Food listing not found.');
      return listing;
    }

    function findOrder(id) {
      const order = state.orders.find(function (item) { return item.id === id; });
      if (!order) throw new Error('Reservation not found.');
      return order;
    }

    function getAvailable() {
      return state.listings.filter(function (listing) {
        return listing.active && listing.quantity > 0 && state.vendors.some(function (vendor) {
          return vendor.id === listing.vendorId && vendor.status === 'approved';
        });
      });
    }

    function approveVendor(id, approved) {
      if (typeof approved === 'undefined') approved = true;
      if (typeof approved !== 'boolean') throw new Error('Choose whether to approve or reject the vendor.');
      const vendor = findVendor(id);
      vendor.status = approved ? 'approved' : 'rejected';
      record(approved ? 'vendor.approved' : 'vendor.rejected', vendor.name + (approved ? ' was approved.' : ' was rejected.'));
      return vendor;
    }

    function saveListing(fields, id) {
      if (!fields || typeof fields !== 'object' || Array.isArray(fields)) throw new Error('Enter the food listing details.');
      const previous = id ? findListing(id) : null;
      const candidate = Object.assign({ vendorId: 'cafe', name: '', category: 'Bakery', description: '', priceCents: 0, originalPriceCents: 0, quantity: 0, pickupStart: '17:00', pickupEnd: '19:00', image: 'bakery', active: true }, previous || {}, fields);
      const vendor = findVendor(candidate.vendorId);
      if (!isText(candidate.name) || candidate.name.trim().length > 100) throw new Error('Enter a food name of 1–100 characters.');
      if (!['Bakery', 'Meals', 'Drinks', 'Pastries'].includes(candidate.category)) throw new Error('Choose a food category.');
      if (typeof candidate.description !== 'string' || candidate.description.length > 1200) throw new Error('Keep the description within 1,200 characters.');
      if (!isMoney(candidate.priceCents) || !isMoney(candidate.originalPriceCents) || candidate.priceCents > candidate.originalPriceCents) throw new Error('Enter valid prices; the deal price cannot exceed the original price.');
      if (!isStock(candidate.quantity)) throw new Error('Available quantity must be a whole number of zero or more.');
      if (!isTime(candidate.pickupStart) || !isTime(candidate.pickupEnd) || candidate.pickupStart >= candidate.pickupEnd) throw new Error('Choose a valid pickup window with the end after the start.');
      if (typeof candidate.active !== 'boolean') throw new Error('Choose whether this listing is available.');
      if (typeof candidate.image !== 'string') throw new Error('Choose a food image.');
      if (candidate.active && vendor.status !== 'approved') throw new Error('Your business must be approved before publishing food.');

      const values = {
        id: previous ? previous.id : 'listing-' + (state.listings.length + 1),
        vendorId: vendor.id,
        name: candidate.name.trim(),
        category: candidate.category,
        description: candidate.description.trim(),
        priceCents: candidate.priceCents,
        originalPriceCents: candidate.originalPriceCents,
        quantity: candidate.quantity,
        pickupStart: candidate.pickupStart,
        pickupEnd: candidate.pickupEnd,
        image: candidate.image,
        active: candidate.active
      };
      const saved = previous ? Object.assign(previous, values) : values;
      if (!previous) state.listings.push(saved);
      record(previous ? 'listing.updated' : 'listing.created', saved.name + (previous ? ' was updated.' : (saved.active ? ' was published.' : ' was saved as a draft.')));
      return saved;
    }

    function toggleListing(id) {
      const listing = findListing(id);
      if (!listing.active && findVendor(listing.vendorId).status !== 'approved') throw new Error('Your business must be approved before publishing food.');
      listing.active = !listing.active;
      record(listing.active ? 'listing.shown' : 'listing.hidden', listing.name + (listing.active ? ' is available.' : ' was hidden.'));
      return listing;
    }

    function reserve(id, quantity) {
      if (typeof quantity === 'undefined') quantity = 1;
      if (!Number.isSafeInteger(quantity) || quantity < 1) throw new Error('Choose a whole quantity of at least one.');
      const listing = findListing(id);
      const vendor = findVendor(listing.vendorId);
      if (!listing.active || vendor.status !== 'approved' || listing.quantity < 1) throw new Error('This food is no longer available.');
      if (quantity > listing.quantity) throw new Error('That quantity exceeds the available stock.');
      const totalCents = quantity * listing.priceCents;
      if (!isMoney(totalCents)) throw new Error('That quantity is too large.');
      const now = new Date();
      const sequence = String(state.orders.length + 1).padStart(3, '0');
      const pickupDate = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0') + '-' + String(now.getDate()).padStart(2, '0');
      const order = {
        id: 'order-' + now.getFullYear() + '-' + sequence,
        code: 'FN-' + now.getFullYear() + '-' + sequence,
        listingId: listing.id,
        vendorId: vendor.id,
        studentId: state.profile.id,
        name: listing.name,
        vendorName: vendor.name,
        quantity: quantity,
        unitPriceCents: listing.priceCents,
        originalUnitPriceCents: listing.originalPriceCents,
        totalCents: totalCents,
        pickupStart: listing.pickupStart,
        pickupEnd: listing.pickupEnd,
        pickupDate: pickupDate,
        status: 'reserved',
        createdAt: now.toISOString()
      };
      listing.quantity -= quantity;
      state.orders.push(order);
      record('order.reserved', order.code + ': ' + quantity + ' × ' + listing.name + ' reserved.');
      return order;
    }

    function cancelOrder(id) {
      const order = findOrder(id);
      if (order.status !== 'reserved') throw new Error('Only a reserved order can be cancelled. This order is ' + order.status + '.');
      const listing = findListing(order.listingId);
      if (!isStock(listing.quantity + order.quantity)) throw new Error('The available quantity cannot be restored.');
      order.status = 'cancelled';
      listing.quantity += order.quantity;
      record('order.cancelled', order.code + ' was cancelled; stock was restored.');
      return order;
    }

    function collectOrder(id, code) {
      const order = findOrder(id);
      if (order.status !== 'reserved') throw new Error('Only a reserved order can be collected. This order is ' + order.status + '.');
      if (typeof code !== 'string' || code.trim().toUpperCase() !== order.code) throw new Error('The pickup code does not match this reservation.');
      order.status = 'collected';
      record('order.collected', order.code + ' was collected.');
      return order;
    }

    function toggleFavourite(id) {
      findListing(id);
      const index = state.favourites.indexOf(id);
      if (index === -1) state.favourites.push(id);
      else state.favourites.splice(index, 1);
      persist();
      return index === -1;
    }

    function saveProfile(name, email) {
      if (!isText(name) || name.trim().length > 100) throw new Error('Enter your name using 1–100 characters.');
      if (typeof email !== 'string' || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) throw new Error('Enter a valid email address.');
      state.profile.name = name.trim();
      state.profile.email = email.trim();
      const student = state.students.find(function (item) { return item.id === state.profile.id; });
      if (student) Object.assign(student, state.profile);
      record('profile.updated', state.profile.name + ' updated their profile.');
      return state.profile;
    }

    function reset() {
      Object.assign(state, initialState());
      persist();
      return state;
    }

    persist();
    return {
      state: state,
      getAvailable: getAvailable,
      approveVendor: approveVendor,
      saveListing: saveListing,
      toggleListing: toggleListing,
      reserve: reserve,
      cancelOrder: cancelOrder,
      collectOrder: collectOrder,
      toggleFavourite: toggleFavourite,
      saveProfile: saveProfile,
      reset: reset
    };
  }

  root.FoodieData = Object.freeze({ createStore: createStore, STORAGE_KEY: STORAGE_KEY });
})(globalThis);
