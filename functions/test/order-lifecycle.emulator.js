const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, getDocs, setDoc, updateDoc, writeBatch, increment, collection, query, where, serverTimestamp} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Use only the Firestore emulator.');
const MINUTE = 60000, HOUR = 60 * MINUTE, SLOT = 15 * MINUTE, GRACE = 15 * MINUTE;
let env, next = 0;
const client = uid => env.authenticatedContext(uid).firestore();
const seed = (path, data) => env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), path), data));
const read = async path => {
  let data;
  await env.withSecurityRulesDisabled(async ctx => { data = (await getDoc(doc(ctx.firestore(), path))).data(); });
  return data;
};
// The quarter-hour slot that is open now.
const slotNow = () => Math.floor(Date.now() / SLOT) * SLOT;
const id = () => 'FN-' + (++next).toString(16).toUpperCase().padStart(20, 'C');
// Windows start five minutes ago, so the first slot is open now.
const listing = (overrides = {}) => ({title: 'Lunch box', description: 'Rice and vegetables', address: '1 Test Street, Subang Jaya',
  dietary: 'Contains soy', category: 'Meals', priceCents: 800, originalPriceCents: 1500, stock: 20,
  pickupStart: Date.now() - 5 * MINUTE, pickupEnd: Date.now() + 2 * HOUR, vendorId: 'vendor', vendorName: 'Subang Cafe',
  active: true, createdAt: new Date(), ...overrides});
const fields = (uid, listingId, deal, rid, quantity, slotStart, orderId, code) => ({customerId: uid, vendorId: deal.vendorId,
  listingId, title: deal.title, vendorName: deal.vendorName, address: deal.address, pickupStart: deal.pickupStart,
  pickupEnd: deal.pickupEnd, quantity, unitPriceCents: deal.priceCents, totalCents: deal.priceCents * quantity,
  status: 'reserved', code: rid, paymentStatus: 'unpaid', createdAt: serverTimestamp(),
  orderId, slotStart, slotEnd: slotStart + SLOT, pickupCode: code});

// Writes an order the way the app does: one write per item, because rules may
// read at most 20 documents per write. The first item also takes the code.
async function placeOrder(uid, items, options = {}) {
  const db = client(uid);
  const deals = [];
  for (const item of items) deals.push((await read('listings/' + item.listingId)));
  const slotStart = options.slotStart ?? slotNow();
  const code = options.code ?? '1234';
  const ids = items.map(() => id());
  const orderId = options.orderId ?? ids[0];
  for (const [i, item] of items.entries()) {
    const deal = deals[i], rid = ids[i], batch = writeBatch(db);
    const held = (await read(`listings/${item.listingId}/claims/${uid}`))?.quantity ?? 0;
    const data = fields(uid, item.listingId, deal, rid, item.quantity, item.slotStart ?? slotStart, orderId, code);
    batch.set(doc(db, 'reservations', rid), {...data, ...options.patch, ...item.patch});
    batch.update(doc(db, 'listings', item.listingId), {stock: deal.stock - item.quantity, lastReservationId: rid});
    batch.set(doc(db, 'listings', item.listingId, 'claims', uid), {quantity: held + item.quantity, lastReservationId: rid});
    if (i === 0 && !options.skipLock) {
      const slotEnd = slotStart + SLOT;
      batch.set(doc(db, 'vendors', deal.vendorId, 'pickupCodes', code),
        {orderId, reservationId: rid, until: slotEnd + GRACE, ...options.lock});
    }
    await batch.commit();
  }
  return {ids, orderId, code};
}
const seedOrder = async (overrides) => {
  const rid = id(), deal = listing();
  await seed('listings/seeded', deal);
  const slotStart = overrides.slotStart ?? slotNow();
  await seed('reservations/' + rid, {...fields('customer', 'seeded', deal, rid, 1, slotStart, rid, '9999'),
    createdAt: new Date(), ...overrides});
  return rid;
};
const vendorUpdate = (uid, rid, data) => updateDoc(doc(client(uid), 'reservations', rid), data);

before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-foodienoms', firestore: {
    host: '127.0.0.1', port: 8080, rules: fs.readFileSync('../firestore.rules', 'utf8')}});
  await env.clearFirestore();
  for (const [uid, role, approved, name] of [
    ['vendor', 'vendor', true, 'Subang Cafe'], ['other-vendor', 'vendor', true, 'Other Cafe'],
    ['customer', 'customer', false, 'Customer'], ['other-customer', 'customer', false, 'Other Customer']]) {
    await seed('users/' + uid, {name, role, approved, createdAt: new Date()});
  }
});
after(async () => { await env?.cleanup(); });

test('a grouped order with a slot and a 4-digit code is accepted', async () => {
  await seed('listings/group-a', listing());
  await seed('listings/group-b', listing({title: 'Croissant', category: 'Bakery'}));
  const {orderId} = await placeOrder('customer', [{listingId: 'group-a', quantity: 2}, {listingId: 'group-b', quantity: 1}]);
  assert.equal((await read('listings/group-a')).stock, 18);
  assert.equal((await read('listings/group-b')).stock, 19);
  const items = await getDocs(query(collection(client('vendor'), 'reservations'),
    where('vendorId', '==', 'vendor'), where('orderId', '==', orderId)));
  assert.equal(items.size, 2);
  assert.equal((await getDoc(doc(client('vendor'), 'vendors/vendor/pickupCodes/1234'))).data().orderId, orderId);
  await assertSucceeds(getDoc(doc(client('other-customer'), 'vendors/vendor/pickupCodes/1234')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'vendors/vendor/pickupCodes/1234')));
});

test('order fields come as a set and are checked', async () => {
  const deal = listing();
  await seed('listings/fields', deal);
  const item = patch => [{listingId: 'fields', quantity: 1, patch}];
  for (const [i, options] of [
    {patch: {pickupCode: '12a4'}, code: '12a4'},
    {code: '123'},
    {slotStart: slotNow() + MINUTE},
    {slotStart: slotNow() + 3 * HOUR},
    {slotStart: slotNow() - 2 * SLOT},
    {patch: {slotEnd: slotNow() + 2 * SLOT}},
    {patch: {orderId: 'FN-NOTVALID'}},
    {skipLock: true},
    {lock: {orderId: 'FN-' + 'D'.repeat(20)}},
    {lock: {until: Date.now() + HOUR}},
  ].entries()) {
    await assertFails(placeOrder('customer', item(), {code: String(2000 + i), ...options}));
  }
  // Only part of the set, with no lock, is refused too.
  for (const missing of ['pickupCode', 'orderId']) {
    const rid = id(), db = client('customer'), batch = writeBatch(db);
    const partial = fields('customer', 'fields', deal, rid, 1, slotNow(), rid, '3000');
    delete partial[missing];
    batch.set(doc(db, 'reservations', rid), partial);
    batch.update(doc(db, 'listings/fields'), {stock: deal.stock - 1, lastReservationId: rid});
    batch.set(doc(db, 'listings/fields/claims/customer'), {quantity: 1, lastReservationId: rid});
    await assertFails(batch.commit());
  }
  assert.equal((await read('listings/fields')).stock, 20);
});

test('a slot must still be open, and all items in an order share it', async () => {
  const started = Date.now() - HOUR;
  await seed('listings/late', listing({pickupStart: started}));
  await assertFails(placeOrder('customer', [{listingId: 'late', quantity: 1}], {code: '3100', slotStart: slotNow() - 4 * SLOT}));
  await assertSucceeds(placeOrder('customer', [{listingId: 'late', quantity: 1}], {code: '3101', slotStart: slotNow() + SLOT}));
  await seed('listings/mixed-a', listing());
  await seed('listings/mixed-b', listing());
  const first = slotNow();
  await assertFails(placeOrder('customer', [{listingId: 'mixed-a', quantity: 1},
    {listingId: 'mixed-b', quantity: 1, slotStart: first + SLOT}], {code: '3102'}));
  // The first item went through on its own; only the mismatched second was refused.
  assert.equal((await read('listings/mixed-b')).stock, 20);
});

test('an order cannot mix vendors', async () => {
  await seed('listings/mine', listing());
  await seed('listings/theirs', listing({vendorId: 'other-vendor', vendorName: 'Other Cafe'}));
  await assertFails(placeOrder('customer', [{listingId: 'mine', quantity: 1}, {listingId: 'theirs', quantity: 1}], {code: '3200'}));
  assert.equal((await read('listings/theirs')).stock, 20);
});

test('codes stay unique while an order can still be collected', async () => {
  await seed('listings/codes', listing({stock: 50}));
  await assertSucceeds(placeOrder('customer', [{listingId: 'codes', quantity: 1}], {code: '4321'}));
  await assertFails(placeOrder('other-customer', [{listingId: 'codes', quantity: 1}], {code: '4321'}));
  await seed('vendors/vendor/pickupCodes/5555', {orderId: 'FN-' + 'E'.repeat(20), reservationId: 'FN-' + 'E'.repeat(20), until: Date.now() - MINUTE});
  await assertSucceeds(placeOrder('other-customer', [{listingId: 'codes', quantity: 1}], {code: '5555'}));
  await assertFails(setDoc(doc(client('vendor'), 'vendors/vendor/pickupCodes/6666'), {orderId: 'x', reservationId: 'x', until: 0}));
  await assertFails(updateDoc(doc(client('customer'), 'vendors/vendor/pickupCodes/4321'), {until: 0}));
});

test('vendors mark an order ready, then collect it', async () => {
  await seed('listings/ready', listing());
  const {ids: [rid]} = await placeOrder('customer', [{listingId: 'ready', quantity: 1}], {code: '7001'});
  const ready = {status: 'ready', readyAt: serverTimestamp()};
  for (const uid of ['customer', 'other-vendor']) await assertFails(vendorUpdate(uid, rid, ready));
  await assertFails(vendorUpdate('vendor', rid, {...ready, totalCents: 0}));
  await assertSucceeds(vendorUpdate('vendor', rid, ready));
  await assertFails(vendorUpdate('vendor', rid, ready));
  await assertSucceeds(vendorUpdate('vendor', rid, {status: 'collected', collectedAt: serverTimestamp()}));
  await assertFails(vendorUpdate('vendor', rid, {status: 'noshow', noshowAt: serverTimestamp()}));
});

test('collection and ready follow the chosen slot, not the whole window', async () => {
  const later = await seedOrder({slotStart: Date.now() + 40 * MINUTE, slotEnd: Date.now() + 55 * MINUTE});
  await assertFails(vendorUpdate('vendor', later, {status: 'collected', collectedAt: serverTimestamp()}));
  const ended = await seedOrder({slotStart: Date.now() - 35 * MINUTE, slotEnd: Date.now() - 20 * MINUTE});
  await assertFails(vendorUpdate('vendor', ended, {status: 'collected', collectedAt: serverTimestamp()}));
  await assertFails(vendorUpdate('vendor', ended, {status: 'ready', readyAt: serverTimestamp()}));
  const legacy = id();
  const deal = listing();
  await seed('reservations/' + legacy, {customerId: 'customer', vendorId: 'vendor', listingId: 'seeded', title: deal.title,
    vendorName: deal.vendorName, address: deal.address, pickupStart: deal.pickupStart, pickupEnd: deal.pickupEnd, quantity: 1,
    unitPriceCents: 800, totalCents: 800, status: 'reserved', code: legacy, paymentStatus: 'unpaid', createdAt: new Date()});
  await assertSucceeds(vendorUpdate('vendor', legacy, {status: 'collected', collectedAt: serverTimestamp()}));
});

test('no-show only once collection is no longer possible', async () => {
  const noshow = {status: 'noshow', noshowAt: serverTimestamp()};
  const grace = await seedOrder({slotStart: Date.now() - 25 * MINUTE, slotEnd: Date.now() - 10 * MINUTE});
  await assertFails(vendorUpdate('vendor', grace, noshow));
  const missed = await seedOrder({slotStart: Date.now() - 35 * MINUTE, slotEnd: Date.now() - 20 * MINUTE, status: 'ready'});
  for (const uid of ['customer', 'other-vendor']) await assertFails(vendorUpdate(uid, missed, noshow));
  await assertSucceeds(vendorUpdate('vendor', missed, noshow));
  assert.equal((await read('reservations/' + missed)).status, 'noshow');
  await assertFails(vendorUpdate('vendor', missed, {status: 'collected', collectedAt: serverTimestamp()}));
});

test('ready orders can still be cancelled, returning stock and allowance', async () => {
  await seed('listings/cancel-ready', listing());
  const {ids: [rid]} = await placeOrder('customer', [{listingId: 'cancel-ready', quantity: 2}], {code: '7101'});
  await assertSucceeds(vendorUpdate('vendor', rid, {status: 'ready', readyAt: serverTimestamp()}));
  const db = client('customer'), batch = writeBatch(db);
  batch.update(doc(db, 'reservations', rid), {status: 'cancelled', cancelledAt: serverTimestamp(), cancelledBy: 'customer'});
  batch.update(doc(db, 'listings/cancel-ready'), {stock: increment(2), lastReleaseId: rid});
  batch.update(doc(db, 'listings/cancel-ready/claims/customer'), {quantity: increment(-2), lastReleaseId: rid});
  await assertSucceeds(batch.commit());
  assert.equal((await read('listings/cancel-ready')).stock, 20);
  assert.equal((await read('listings/cancel-ready/claims/customer')).quantity, 0);
});

test('payment is simulated: a test payment records its method, real payment states are refused', async () => {
  await seed('listings/pay', listing());
  for (const [i, paymentMethod] of ['ewallet', 'banking', 'card'].entries()) {
    await assertSucceeds(placeOrder('customer', [{listingId: 'pay', quantity: 1}],
      {code: String(8000 + i), patch: {paymentStatus: 'test_paid', paymentMethod}}));
  }
  for (const [i, patch] of [{paymentStatus: 'test_paid'}, {paymentStatus: 'test_paid', paymentMethod: 'cash'},
    {paymentStatus: 'paid', paymentMethod: 'card'}, {paymentStatus: 'unpaid', paymentMethod: 'card'}].entries()) {
    await assertFails(placeOrder('other-customer', [{listingId: 'pay', quantity: 1}], {code: String(8100 + i), patch}));
  }
});

const upcoming = () => ({pickupStart: Date.now() + 10 * MINUTE, pickupEnd: Date.now() + HOUR, createdAt: serverTimestamp()});
test("Han's categories are accepted, others are not", async () => {
  for (const category of ['Café', 'Dessert', 'Drinks', 'Others', 'Bakery']) {
    await assertSucceeds(setDoc(doc(client('vendor'), 'listings', 'cat-' + category), {...listing({category}), ...upcoming()}));
  }
  await assertFails(setDoc(doc(client('vendor'), 'listings', 'cat-bad'), {...listing({category: 'Snacks'}), ...upcoming()}));
});
