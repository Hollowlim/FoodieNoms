const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, collection, query, where, getDocs} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run with the Firestore emulator; never against a live project.');
process.env.GCLOUD_PROJECT = 'demo-foodienoms';
const functions = require('../index');
const db = require('firebase-admin/firestore').getFirestore();
let env;
const call = (name, uid, data) => functions[name].run({auth: uid ? {uid} : undefined, data});
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-foodienoms', firestore: {
    host: '127.0.0.1', port: 8080, rules: fs.readFileSync('firestore.cloud-functions.rules', 'utf8')}});
  await env.clearFirestore();
});
after(async () => { await env?.cleanup(); });

test('roles, transactions, ownership and Firestore access end to end', async () => {
  await assert.rejects(() => call('createProfile', null, {name: 'Guest', role: 'customer'}));
  await assert.rejects(() => call('createProfile', 'evil', {name: 'Evil', role: 'admin'}));
  for (const [uid, role] of [['customer1','customer'], ['customer2','customer'], ['vendor1','vendor'], ['vendor2','vendor']]) {
    await call('createProfile', uid, {name: uid, role});
  }
  await db.doc('users/admin1').set({role: 'admin', name: 'Admin', approved: true});
  await call('createProfile', 'customer1', {name: 'Changed', role: 'vendor'});
  assert.equal((await db.doc('users/customer1').get()).data().role, 'customer');
  const input = {title: 'Lunch', description: 'Rice', category: 'Meals', address: 'Subang Jaya',
    dietary: 'Contains soy', priceCents: 800, originalPriceCents: 1500, stock: 1,
    pickupStart: Date.now()+3600000, pickupEnd: Date.now()+7200000};
  await assert.rejects(() => call('publishListing', 'vendor1', input));
  await assert.rejects(() => call('approveVendor', 'customer1', {vendorId: 'vendor1'}));
  await call('approveVendor', 'admin1', {vendorId: 'vendor1'});
  await call('approveVendor', 'admin1', {vendorId: 'vendor2'});
  const {id} = await call('publishListing', 'vendor1', input);
  await assert.rejects(() => call('setListingActive', 'vendor2', {listingId: id, active: false}));
  const attempts = await Promise.allSettled(['customer1','customer2'].map((uid) => call('reserveListing', uid,
    {listingId: id, quantity: 1, requestId: '0123456789abcdef'})));
  assert.equal(attempts.filter((a) => a.status === 'fulfilled').length, 1);
  assert.equal((await db.doc(`listings/${id}`).get()).data().stock, 0);
  const winner = attempts[0].status === 'fulfilled' ? 'customer1' : 'customer2';
  const loser = winner === 'customer1' ? 'customer2' : 'customer1';
  const result = attempts.find((a) => a.status === 'fulfilled').value;
  const retry = await call('reserveListing', winner, {listingId: id, quantity: 1, requestId: '0123456789abcdef'});
  assert.equal(retry.code, result.code);
  assert.equal((await db.collection('reservations').get()).size, 1);
  await assert.rejects(() => call('collectReservation', 'vendor2', {code: result.code}));
  await assert.rejects(() => call('collectReservation', winner, {code: result.code}));
  await call('collectReservation', 'vendor1', {code: result.code});
  await assert.rejects(() => call('collectReservation', 'vendor1', {code: result.code}));
  assert.equal((await db.doc(`reservations/${result.id}`).get()).data().status, 'collected');

  const customer = env.authenticatedContext(winner).firestore();
  const stranger = env.authenticatedContext(loser).firestore();
  const vendor = env.authenticatedContext('vendor1').firestore();
  const otherVendor = env.authenticatedContext('vendor2').firestore();
  const admin = env.authenticatedContext('admin1').firestore();
  await assertSucceeds(getDoc(doc(customer, 'users', winner)));
  await assertFails(getDoc(doc(customer, 'users', 'vendor1')));
  await assertSucceeds(getDocs(query(collection(customer, 'listings'), where('active', '==', true))));
  await assertSucceeds(getDocs(query(collection(customer, 'reservations'), where('customerId', '==', winner))));
  await assertSucceeds(getDocs(query(collection(vendor, 'reservations'), where('vendorId', '==', 'vendor1'))));
  await assertSucceeds(getDocs(query(collection(admin, 'users'), where('role', '==', 'vendor'))));
  await assertFails(getDoc(doc(stranger, 'reservations', result.id)));
  await assertFails(getDoc(doc(otherVendor, 'reservations', result.id)));
  await assertFails(getDoc(doc(customer, 'pickupCodes', result.code)));
  await assertFails(setDoc(doc(customer, 'users', winner), {role: 'admin'}));
  await assertFails(setDoc(doc(vendor, 'listings', id), {stock: 999}, {merge: true}));
  await assertFails(setDoc(doc(customer, 'reservations', 'forged'), {customerId: winner}));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'listings', id)));
  await call('setListingActive', 'vendor1', {listingId: id, active: false});
  await assertFails(getDoc(doc(customer, 'listings', id)));
  await assertSucceeds(getDoc(doc(vendor, 'listings', id)));
});
