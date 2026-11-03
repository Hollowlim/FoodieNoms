const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, serverTimestamp} = require('firebase/firestore');
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
