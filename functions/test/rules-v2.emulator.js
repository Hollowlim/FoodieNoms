const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, runTransaction, writeBatch, increment, serverTimestamp} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Use only the Firestore emulator.');
const MINUTE = 60000, HOUR = 60 * MINUTE;
let env;
const client = uid => env.authenticatedContext(uid).firestore();
const listing = (overrides = {}) => ({title: 'Lunch box', description: 'Rice and vegetables', address: '1 Test Street, Subang Jaya',
  dietary: 'Contains soy', category: 'Meals', priceCents: 800, originalPriceCents: 1500, stock: 20,
  pickupStart: Date.now() + 10 * MINUTE, pickupEnd: Date.now() + 2 * HOUR, vendorId: 'vendor', vendorName: 'Subang Cafe',
  active: true, createdAt: serverTimestamp(), ...overrides});
const seed = (path, data) => env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), path), data));
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-foodienoms', firestore: {
    host: '127.0.0.1', port: 8080, rules: fs.readFileSync('../firestore.rules', 'utf8')}});
  await env.clearFirestore();
  for (const [uid, role, approved, name] of [
    ['vendor', 'vendor', true, 'Subang Cafe'], ['other-vendor', 'vendor', true, 'Other Cafe'], ['pending', 'vendor', false, 'Pending Cafe'],
    ['customer', 'customer', false, 'Customer'], ['other-customer', 'customer', false, 'Other Customer']]) {
    await seed('users/' + uid, {name, role, approved, createdAt: new Date()});
  }
});
after(async () => { await env?.cleanup(); });

test('owning vendors edit listing content, price and stock', async () => {
  await seed('listings/edit', listing());
  const ref = uid => doc(client(uid), 'listings/edit');
  await assertSucceeds(updateDoc(ref('vendor'), {priceCents: 700, originalPriceCents: 1400}));
  await assertSucceeds(updateDoc(ref('vendor'), {stock: 0}));
  await assertSucceeds(updateDoc(ref('vendor'), {title: 'Dinner box', pickupEnd: Date.now() + 3 * HOUR}));
  const data = (await getDoc(ref('vendor'))).data();
  assert.equal(data.priceCents, 700);
  assert.equal(data.stock, 0);
  assert.equal(data.title, 'Dinner box');
  for (const uid of ['other-vendor', 'pending', 'customer']) await assertFails(updateDoc(ref(uid), {priceCents: 1}));
});
test('listing edits keep validation and cannot touch identity fields', async () => {
  await seed('listings/guarded', listing());
  const ref = doc(client('vendor'), 'listings/guarded');
  for (const patch of [{priceCents: 0}, {priceCents: 2000}, {priceCents: 8.5}, {stock: -1}, {stock: 10001}, {title: ''},
    {category: 'Unknown'}, {pickupEnd: Date.now() - MINUTE}, {pickupEnd: Date.now() + 31 * 24 * HOUR},
    {vendorId: 'other-vendor'}, {vendorName: 'Spoofed'}, {createdAt: 0}, {lastReservationId: 'x'}, {extra: 'field'},
    {priceCents: 700, active: false}]) {
    await assertFails(updateDoc(ref, patch));
  }
});
test('ended listings cannot be edited unless the window is extended', async () => {
  await seed('listings/ended', listing({pickupStart: Date.now() - 2 * HOUR, pickupEnd: Date.now() - HOUR}));
  const ref = doc(client('vendor'), 'listings/ended');
  await assertFails(updateDoc(ref, {priceCents: 700}));
  await assertSucceeds(updateDoc(ref, {pickupEnd: Date.now() + HOUR}));
});
test('listings may name a preset photo and nothing else', async () => {
  const ref = id => doc(client('vendor'), 'listings', id);
  await assertSucceeds(setDoc(ref('no-photo'), listing()));
  await assertSucceeds(setDoc(ref('photo'), listing({imageKey: 'photo-2'})));
  await assertSucceeds(updateDoc(ref('photo'), {imageKey: 'photo-3'}));
  await assertSucceeds(updateDoc(ref('no-photo'), {imageKey: 'photo-0'}));
  for (const imageKey of ['photo-9', 'https://example.com/a.jpg', '', 3]) {
    await assertFails(setDoc(ref('bad-photo'), listing({imageKey})));
    await assertFails(updateDoc(ref('photo'), {imageKey}));
  }
});
const collected = {status: 'collected', collectedAt: serverTimestamp()};
const seedOrder = (id, pickupStart, pickupEnd) => seed('reservations/' + id, {customerId: 'customer', vendorId: 'vendor', listingId: 'seeded',
  title: 'Lunch box', vendorName: 'Subang Cafe', address: '1 Test Street', pickupStart, pickupEnd, quantity: 1, unitPriceCents: 800,
  totalCents: 800, status: 'reserved', code: id, paymentStatus: 'unpaid', createdAt: new Date()});
test('collection is limited to the pickup window plus the grace period', async () => {
  const now = Date.now();
  const cases = [
    ['FN-WINDOW-OPEN', now - HOUR, now + HOUR, true],
    ['FN-JUST-EARLY', now + 10 * MINUTE, now + HOUR, true],
    ['FN-JUST-LATE', now - HOUR, now - 10 * MINUTE, true],
    ['FN-TOO-EARLY', now + 20 * MINUTE, now + HOUR, false],
    ['FN-TOO-LATE', now - HOUR, now - 20 * MINUTE, false]];
  for (const [id, start, end, allowed] of cases) {
    await seedOrder(id, start, end);
    const attempt = updateDoc(doc(client('vendor'), 'reservations', id), collected);
    await (allowed ? assertSucceeds(attempt) : assertFails(attempt));
  }
});
let nextCode = 0;
const code = () => 'FN-' + (++nextCode).toString(16).toUpperCase().padStart(20, 'A');
const orderFor = (uid, listingId, deal, id, quantity) => ({customerId: uid, vendorId: deal.vendorId, listingId, title: deal.title,
  vendorName: deal.vendorName, address: deal.address, pickupStart: deal.pickupStart, pickupEnd: deal.pickupEnd, quantity,
  unitPriceCents: deal.priceCents, totalCents: deal.priceCents * quantity, status: 'reserved', code: id,
  paymentStatus: 'unpaid', createdAt: serverTimestamp()});
function reserve(uid, listingId, quantity, id = code()) {
  const db = client(uid);
  return runTransaction(db, async tx => {
    const listingRef = doc(db, 'listings', listingId), claimRef = doc(db, 'listings', listingId, 'claims', uid);
    const deal = (await tx.get(listingRef)).data();
    const held = (await tx.get(claimRef)).data()?.quantity ?? 0;
    tx.set(doc(db, 'reservations', id), orderFor(uid, listingId, deal, id, quantity));
    tx.update(listingRef, {stock: deal.stock - quantity, lastReservationId: id});
    tx.set(claimRef, {quantity: held + quantity, lastReservationId: id}, {merge: true});
    return id;
  });
}
const heldBy = async (uid, listingId) => (await getDoc(doc(client(uid), 'listings', listingId, 'claims', uid))).data()?.quantity;
test('each student can hold at most five of a listing across orders', async () => {
  await seed('listings/cap', listing());
  await assertFails(reserve('customer', 'cap', 6));
  await assertSucceeds(reserve('customer', 'cap', 3));
  await assertSucceeds(reserve('customer', 'cap', 2));
  assert.equal(await heldBy('customer', 'cap'), 5);
  await assertFails(reserve('customer', 'cap', 1));
  await assertSucceeds(reserve('other-customer', 'cap', 5));
  assert.equal((await getDoc(doc(client('vendor'), 'listings/cap'))).data().stock, 10);
  await seed('listings/cap-2', listing());
  await assertSucceeds(reserve('customer', 'cap-2', 5));
});
test('the claim total cannot be skipped or forged', async () => {
  await seed('listings/claim', listing());
  const db = client('customer'), deal = (await getDoc(doc(db, 'listings/claim'))).data();
  const ref = doc(db, 'listings/claim/claims/customer');
  // Order and stock change with no claim, or with an understated one.
  for (const claim of [null, {quantity: 0}, {quantity: 1}]) {
    const id = code(), batch = writeBatch(db);
    batch.set(doc(db, 'reservations', id), orderFor('customer', 'claim', deal, id, 2));
    batch.update(doc(db, 'listings/claim'), {stock: deal.stock - 2, lastReservationId: id});
    if (claim) batch.set(ref, {...claim, lastReservationId: id});
    await assertFails(batch.commit());
  }
  await assertSucceeds(reserve('customer', 'claim', 5));
  await assertFails(setDoc(ref, {quantity: 0, lastReservationId: 'x'}));
  await assertFails(updateDoc(ref, {quantity: 0}));
  await assertFails(setDoc(doc(client('other-customer'), 'listings/claim/claims/customer'), {quantity: 0, lastReservationId: 'x'}));
  await assertFails(getDoc(doc(client('other-customer'), 'listings/claim/claims/customer')));
});
test('concurrent orders by one student cannot pass the limit', async () => {
  await seed('listings/race', listing());
  const results = await Promise.allSettled([reserve('customer', 'race', 3), reserve('customer', 'race', 3), reserve('customer', 'race', 3)]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(await heldBy('customer', 'race'), 3);
  assert.equal((await getDoc(doc(client('vendor'), 'listings/race'))).data().stock, 17);
});
const cancelled = uid => ({status: 'cancelled', cancelledAt: serverTimestamp(), cancelledBy: uid});
// Uses increment so a student can cancel after the vendor has paused the listing.
function cancel(uid, id, listingId, quantity, customer = uid, patch = {}) {
  const db = client(uid), batch = writeBatch(db);
  batch.update(doc(db, 'reservations', id), {...cancelled(uid), ...patch.order});
  batch.update(doc(db, 'listings', listingId), {stock: increment(patch.stock ?? quantity), lastReleaseId: patch.releaseId ?? id});
  if (!patch.skipClaim) batch.update(doc(db, 'listings', listingId, 'claims', customer), {quantity: increment(-(patch.claim ?? quantity)), lastReleaseId: patch.releaseId ?? id});
  return batch.commit();
}
const stockOf = async id => (await getDoc(doc(client('vendor'), 'listings', id))).data().stock;
test('students cancel their own order and get their allowance back', async () => {
  await seed('listings/undo', listing());
  const id = await reserve('customer', 'undo', 5);
  assert.equal(await stockOf('undo'), 15);
  await assertSucceeds(cancel('customer', id, 'undo', 5));
  assert.equal(await stockOf('undo'), 20);
  assert.equal(await heldBy('customer', 'undo'), 0);
  const order = (await getDoc(doc(client('customer'), 'reservations', id))).data();
  assert.equal(order.status, 'cancelled');
  assert.equal(order.cancelledBy, 'customer');
  await assertFails(cancel('customer', id, 'undo', 5));
  assert.equal(await stockOf('undo'), 20);
  await assertFails(updateDoc(doc(client('vendor'), 'reservations', id), collected));
  await assertSucceeds(reserve('customer', 'undo', 5));
});
test('only the student or owning vendor can cancel an order', async () => {
  await seed('listings/who', listing());
  const id = await reserve('customer', 'who', 2);
  for (const uid of ['other-customer', 'other-vendor', 'pending']) await assertFails(cancel(uid, id, 'who', 2, 'customer'));
  await assertSucceeds(cancel('vendor', id, 'who', 2, 'customer'));
  assert.equal((await getDoc(doc(client('customer'), 'reservations', id))).data().cancelledBy, 'vendor');
  assert.equal(await heldBy('customer', 'who'), 0);
});
test('cancelling cannot create stock or change the order', async () => {
  await seed('listings/forge', listing());
  const id = await reserve('customer', 'forge', 2), other = await reserve('customer', 'forge', 1);
  for (const patch of [{stock: 3}, {stock: 1}, {claim: 1}, {claim: 3}, {skipClaim: true}, {releaseId: other},
    {order: {totalCents: 0}}, {order: {cancelledBy: 'vendor'}}, {order: {cancelledAt: 0}}, {order: {quantity: 1}}]) {
    await assertFails(cancel('customer', id, 'forge', 2, 'customer', patch));
  }
  const db = client('customer');
  await assertFails(updateDoc(doc(db, 'listings/forge'), {stock: increment(2), lastReleaseId: id}));
  await assertFails(updateDoc(doc(db, 'listings/forge/claims/customer'), {quantity: increment(-2), lastReleaseId: id}));
  await assertFails(updateDoc(doc(db, 'reservations', id), cancelled('customer')));
  assert.equal(await stockOf('forge'), 17);
  assert.equal(await heldBy('customer', 'forge'), 3);
});
test('an attacker cannot use another student order to move stock or allowance', async () => {
  await seed('listings/victim', listing());
  const id = await reserve('customer', 'victim', 2);
  await assertSucceeds(reserve('other-customer', 'victim', 5));
  const db = client('other-customer');
  await assertFails(updateDoc(doc(db, 'listings/victim'), {stock: increment(2), lastReleaseId: id}));
  await assertFails(updateDoc(doc(db, 'listings/victim/claims/other-customer'), {quantity: increment(-2), lastReleaseId: id}));
  assert.equal(await heldBy('other-customer', 'victim'), 5);
});
test('students cancel only until the window ends; vendors can clear no-shows later', async () => {
  const start = Date.now() + 10 * MINUTE;
  await seed('listings/ended-order', listing({pickupStart: start}));
  const id = await reserve('customer', 'ended-order', 2);
  // Simulates the window passing without changing the order's other fields.
  await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'reservations', id), {pickupEnd: Date.now() - MINUTE}));
  await assertFails(cancel('customer', id, 'ended-order', 2));
  await assertSucceeds(cancel('vendor', id, 'ended-order', 2, 'customer'));
  assert.equal(await stockOf('ended-order'), 20);
});
test('orders can be cancelled after pausing, and older orders without a claim still work', async () => {
  await seed('listings/paused-order', listing());
  const id = await reserve('customer', 'paused-order', 2);
  await updateDoc(doc(client('vendor'), 'listings/paused-order'), {active: false});
  await assertSucceeds(cancel('customer', id, 'paused-order', 2));
  await seed('listings/legacy', listing());
  const legacy = code();
  await seed('reservations/' + legacy, {...orderFor('customer', 'legacy', listing(), legacy, 2), createdAt: new Date()});
  await assertSucceeds(cancel('customer', legacy, 'legacy', 2, 'customer', {skipClaim: true}));
  assert.equal(await stockOf('legacy'), 22);
});
