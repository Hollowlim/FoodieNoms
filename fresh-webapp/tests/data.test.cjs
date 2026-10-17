const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const sourcePath = path.join(__dirname, '..', 'data.js');
const sandbox = {};
if (fs.existsSync(sourcePath)) vm.runInNewContext(fs.readFileSync(sourcePath, 'utf8'), sandbox);
const api = sandbox.FoodieData || {};

function store() {
  assert.equal(typeof api.createStore, 'function', 'The classic script must expose FoodieData.createStore');
  return api.createStore(null);
}

test('fresh data starts with three available RM deals and a pending vendor', () => {
  const data = store();
  assert.equal(data.getAvailable().length, 3);
  assert.equal(data.state.vendors.find(vendor => vendor.id === 'cafe').status, 'pending');
  assert.equal(data.state.listings.find(listing => listing.id === 'bag').priceCents, 800);
  assert.equal(data.state.listings.find(listing => listing.id === 'lunch').priceCents, 990);
  assert.equal(data.state.orders.length, 0);
});

function snapshot(data) { return JSON.stringify(data.state); }

function memoryStorage() {
  const values = new Map();
  return {
    getItem(key) { return values.has(key) ? values.get(key) : null; },
    setItem(key, value) { values.set(key, value); }
  };
}

function listing(overrides = {}) {
  return { vendorId: 'cafe', name: 'Afternoon Rescue Box', category: 'Meals', description: 'A fresh cafe meal.', priceCents: 1200, originalPriceCents: 2400, quantity: 2, pickupStart: '17:00', pickupEnd: '19:00', image: 'lunch', ...overrides };
}

test('a pending vendor cannot publish until approved by an administrator', () => {
  const data = store();
  const before = snapshot(data);
  assert.throws(() => data.saveListing(listing()), /approv/i);
  assert.equal(snapshot(data), before, 'A rejected action must leave all state unchanged');
  data.approveVendor('cafe', true);
  const deal = data.saveListing(listing());
  assert.equal(deal.active, true);
  assert.ok(data.getAvailable().some(item => item.id === deal.id));
  assert.ok(data.state.events.some(event => event.type === 'vendor.approved'));
});

test('rejecting an approved vendor removes their deals from discovery and reservation', () => {
  const data = store();
  assert.equal(data.approveVendor('bakery', false).status, 'rejected');
  assert.equal(data.getAvailable().length, 0);
  const before = snapshot(data);
  assert.throws(() => data.reserve('bag', 1), /available|approv/i);
  assert.equal(snapshot(data), before);
  assert.throws(() => data.approveVendor('missing', true), /vendor/i);
});

test('pending vendors may save inactive drafts without publishing them', () => {
  const data = store();
  const draft = data.saveListing(listing({ active: false }));
  assert.equal(draft.active, false);
  assert.ok(!data.getAvailable().some(item => item.id === draft.id));
  assert.throws(() => data.toggleListing(draft.id), /approv/i);
});

test('invalid prices, stock, names, vendors, and pickup windows do not change state', () => {
  const data = store();
  data.approveVendor('cafe', true);
  for (const invalid of [
    { name: ' ' }, { vendorId: 'missing' }, { priceCents: -1 }, { priceCents: 1.5 },
    { priceCents: 2500 }, { originalPriceCents: 0 }, { quantity: -1 },
    { quantity: 1.5 }, { pickupStart: '25:00' }, { pickupEnd: '16:00' }
  ]) {
    const before = snapshot(data);
    assert.throws(() => data.saveListing(listing(invalid)));
    assert.equal(snapshot(data), before, JSON.stringify(invalid));
  }
});

test('hiding a listing prevents reservation until it is made available again', () => {
  const data = store();
  assert.equal(data.toggleListing('bag').active, false);
  assert.ok(!data.getAvailable().some(item => item.id === 'bag'));
  assert.throws(() => data.reserve('bag', 1), /available/i);
  assert.equal(data.toggleListing('bag').active, true);
  assert.ok(data.getAvailable().some(item => item.id === 'bag'));
});

test('reservation reduces stock and preserves the price and pickup details at booking', () => {
  const data = store();
  const order = data.reserve('bag', 2);
  assert.equal(order.status, 'reserved');
  assert.equal(order.quantity, 2);
  assert.equal(order.totalCents, 1600);
  assert.equal(order.unitPriceCents, 800);
  assert.equal(order.originalUnitPriceCents, 2000);
  assert.match(order.code, /^FN-\d{4}-\d{3,}$/);
  assert.equal(data.state.listings.find(item => item.id === 'bag').quantity, 2);
  data.saveListing({ name: 'Updated bag', priceCents: 900, pickupStart: '18:00' }, 'bag');
  assert.equal(order.name, 'Bakery Surprise Bag');
  assert.equal(order.unitPriceCents, 800);
  assert.equal(order.pickupStart, '17:00');
});

test('invalid or oversized reservations cannot reduce stock or create orders', () => {
  const data = store();
  for (const quantity of [-1, 0, 1.5, NaN, Infinity, '1', 5]) {
    const before = snapshot(data);
    assert.throws(() => data.reserve('bag', quantity), /quantity|stock|available/i);
    assert.equal(snapshot(data), before);
  }
  assert.throws(() => data.reserve('missing', 1), /listing|food/i);
});

test('cancellation restores stock once and prevents collection of that order', () => {
  const data = store();
  const order = data.reserve('bag', 2);
  assert.equal(data.cancelOrder(order.id).status, 'cancelled');
  assert.equal(data.state.listings.find(item => item.id === 'bag').quantity, 4);
  const before = snapshot(data);
  assert.throws(() => data.cancelOrder(order.id), /cancel|reserved/i);
  assert.throws(() => data.collectOrder(order.id, order.code), /reserved|cancel/i);
  assert.equal(snapshot(data), before);
});

test('only the correct pickup code collects an order and it can be used once', () => {
  const data = store();
  const order = data.reserve('bag', 1);
  const before = snapshot(data);
  assert.throws(() => data.collectOrder(order.id, 'WRONG'), /code/i);
  assert.equal(snapshot(data), before);
  assert.equal(data.collectOrder(order.id, order.code).status, 'collected');
  assert.equal(data.state.listings.find(item => item.id === 'bag').quantity, 3);
  const collected = snapshot(data);
  assert.throws(() => data.collectOrder(order.id, order.code), /reserved|collected/i);
  assert.throws(() => data.cancelOrder(order.id), /reserved|collected/i);
  assert.equal(snapshot(data), collected);
});

test('favourites toggle only existing food listings', () => {
  const data = store();
  assert.equal(data.toggleFavourite('bag'), true);
  assert.ok(data.state.favourites.includes('bag'));
  assert.equal(data.toggleFavourite('bag'), false);
  assert.equal(data.state.favourites.length, 0);
  assert.throws(() => data.toggleFavourite('missing'), /listing|food/i);
});

test('profile updates student details without storing a password', () => {
  const data = store();
  data.saveProfile('  Jamie Lee  ', '  jamie@example.com ');
  assert.equal(data.state.profile.name, 'Jamie Lee');
  assert.equal(data.state.profile.email, 'jamie@example.com');
  assert.equal(data.state.students[0].email, 'jamie@example.com');
  const before = snapshot(data);
  assert.throws(() => data.saveProfile('', 'a@example.com'), /name/i);
  assert.throws(() => data.saveProfile('Jamie', 'invalid'), /email/i);
  assert.equal(snapshot(data), before);
  assert.ok(!snapshot(data).includes('password'));
});

test('state persists under an isolated key and reloads reservations without resetting stock', () => {
  const storage = memoryStorage();
  storage.setItem('foodienoms-demo', 'old unrelated app');
  const first = api.createStore(storage);
  first.reserve('bag', 1);
  first.toggleFavourite('pastry');
  const second = api.createStore(storage);
  assert.equal(second.state.orders.length, 1);
  assert.equal(second.state.listings.find(item => item.id === 'bag').quantity, 3);
  assert.ok(second.state.favourites.includes('pastry'));
  assert.equal(storage.getItem('foodienoms-demo'), 'old unrelated app');
  assert.ok(storage.getItem(api.STORAGE_KEY));
});

test('corrupt or unsupported saved state recovers to clean usable demo data', () => {
  for (const saved of ['{invalid', 'null', '{"version":99}', '{"version":1,"listings":[]}']) {
    const storage = memoryStorage();
    storage.setItem(api.STORAGE_KEY, saved);
    const data = api.createStore(storage);
    assert.equal(data.getAvailable().length, 3);
    assert.equal(data.state.orders.length, 0);
    assert.equal(data.reserve('bag', 1).totalCents, 800);
  }
});

test('denied browser storage still allows an in-memory demo session', () => {
  const denied = {
    getItem() { throw new Error('Storage denied'); },
    setItem() { throw new Error('Storage denied'); }
  };
  const data = api.createStore(denied);
  assert.equal(data.reserve('bag', 1).status, 'reserved');
  assert.equal(data.state.orders.length, 1);
});

test('reset restores the original data and persists the reset', () => {
  const storage = memoryStorage();
  const data = api.createStore(storage);
  data.reserve('bag', 4);
  data.approveVendor('cafe', true);
  data.toggleFavourite('bag');
  const reference = data.state;
  data.reset();
  assert.equal(data.state, reference, 'Views holding state should keep their reference after reset');
  assert.equal(data.state.orders.length, 0);
  assert.equal(data.state.listings[0].quantity, 4);
  assert.equal(data.state.vendors[1].status, 'pending');
  assert.equal(data.state.favourites.length, 0);
  assert.equal(api.createStore(storage).state.orders.length, 0);
});
