const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs,
  writeBatch, serverTimestamp, increment} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Use only the Firestore emulator.');
let env;
const client = uid => env.authenticatedContext(uid).firestore();
const profile = (name, approved = false) => ({name, role: 'vendor', approved, createdAt: serverTimestamp()});
const business = (uid = 'vendor', patch = {}) => ({vendorId: uid, businessName: 'Subang Cafe',
  address: '1 Jalan SS15, Subang Jaya', latitude: 3.075, longitude: 101.59,
  approved: true, configured: true, updatedAt: serverTimestamp(), ...patch});
const initial = (uid, name = 'Subang Cafe', approved = false) => business(uid,
  {businessName: name, address: '', latitude: null, longitude: null, approved, configured: false});
const listing = (patch = {}) => ({title: 'Lunch box', description: 'Rice and vegetables',
  address: '1 Jalan SS15, Subang Jaya', latitude: 3.075, longitude: 101.59,
  dietary: 'Contains soy', category: 'Meals', priceCents: 800, originalPriceCents: 1500, stock: 10,
  pickupStart: Date.now() - 60000, pickupEnd: Date.now() + 7200000,
  vendorId: 'vendor', vendorName: 'Subang Cafe', active: true, createdAt: serverTimestamp(), ...patch});
const seed = (path, data) => env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), path), data));
const code = n => 'FN-' + n.toString(16).toUpperCase().padStart(20, '0');
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-foodienoms', firestore: {
    host: '127.0.0.1', port: 8080, rules: fs.readFileSync('../firestore.rules', 'utf8')}});
});
beforeEach(async () => {
  await env.clearFirestore();
  await seed('users/admin', {name: 'Admin', role: 'admin', approved: true});
  await seed('users/customer', {name: 'Student', role: 'customer', approved: false});
  await seed('users/vendor', profile('Subang Cafe', true));
  await seed('users/pending', profile('Pending Cafe'));
  await seed('users/other', profile('Other Cafe', true));
  await seed('vendorBusinesses/vendor', business());
  await seed('vendorBusinesses/pending', initial('pending', 'Pending Cafe'));
});
after(async () => { await env?.cleanup(); });
function approval(uid, approved, reason = 'Repeated food quality reports', businessPatch = {}) {
  const db = client('admin'), batch = writeBatch(db);
  batch.update(doc(db, 'users', uid), approved
    ? {approved: true, approvedBy: 'admin', approvedAt: serverTimestamp()}
    : {approved: false, revokedBy: 'admin', revokedAt: serverTimestamp(), revocationReason: reason});
  batch.update(doc(db, 'vendorBusinesses', uid), {approved, updatedAt: serverTimestamp(), ...businessPatch});
  return batch.commit();
}
async function reserve(id, n, patch = {}) {
  const db = client('customer'), deal = (await getDoc(doc(db, 'listings', id))).data();
  const orderId = code(n), batch = writeBatch(db);
  const held = (await getDoc(doc(db, 'listings', id, 'claims', 'customer'))).data()?.quantity ?? 0;
  const snapshot = {customerId: 'customer', vendorId: deal.vendorId, listingId: id, title: deal.title,
    vendorName: deal.vendorName, address: deal.address, pickupStart: deal.pickupStart, pickupEnd: deal.pickupEnd,
    quantity: 1, unitPriceCents: deal.priceCents, totalCents: deal.priceCents, status: 'reserved',
    code: orderId, paymentStatus: 'unpaid', createdAt: serverTimestamp()};
  if ('latitude' in deal) Object.assign(snapshot, {latitude: deal.latitude, longitude: deal.longitude});
  const data = {...snapshot, ...patch};
  for (const key of Object.keys(data)) if (data[key] === undefined) delete data[key];
  batch.set(doc(db, 'reservations', orderId), data);
  batch.update(doc(db, 'listings', id), {stock: deal.stock - 1, lastReservationId: orderId});
  batch.set(doc(db, 'listings', id, 'claims', 'customer'), {quantity: held + 1, lastReservationId: orderId});
  await batch.commit();
  return orderId;
}
function cancel(uid, id) {
  const db = client(uid), batch = writeBatch(db);
  batch.update(doc(db, 'reservations', id), {status: 'cancelled', cancelledBy: uid, cancelledAt: serverTimestamp()});
  batch.update(doc(db, 'listings', 'food'), {stock: increment(1), lastReleaseId: id});
  batch.update(doc(db, 'listings', 'food', 'claims', 'customer'), {quantity: increment(-1), lastReleaseId: id});
  return batch.commit();
}

test('vendor registration atomically creates a private pending profile and public safe initial business', async () => {
  const db = client('new-vendor');
  await assertFails(setDoc(doc(db, 'users', 'new-vendor'), profile('New Bakery')));
  await assertFails(setDoc(doc(db, 'vendorBusinesses', 'new-vendor'), initial('new-vendor', 'New Bakery')));
  for (const [i, patch] of [{approved: true}, {businessName: 'Different business'},
    {email: 'private@example.test'}, {configured: true, address: 'Test', latitude: 3.075, longitude: 101.59}].entries()) {
    const uid = 'forged-registration-' + i, forgedDb = client(uid), forged = writeBatch(forgedDb);
    forged.set(doc(forgedDb, 'users', uid), profile('New Bakery'));
    forged.set(doc(forgedDb, 'vendorBusinesses', uid), {...initial(uid, 'New Bakery'), ...patch});
    await assertFails(forged.commit());
  }
  const batch = writeBatch(db);
  batch.set(doc(db, 'users', 'new-vendor'), profile('New Bakery'));
  batch.set(doc(db, 'vendorBusinesses', 'new-vendor'), initial('new-vendor', 'New Bakery'));
  await assertSucceeds(batch.commit());
  assert.deepEqual(Object.keys((await getDoc(doc(db, 'users', 'new-vendor'))).data()).sort(),
    ['approved', 'createdAt', 'name', 'role']);
  assert.equal((await getDoc(doc(db, 'vendorBusinesses', 'new-vendor'))).data().configured, false);
  await assertFails(getDoc(doc(client('customer'), 'users', 'new-vendor')));
  await assertFails(getDoc(doc(client('customer'), 'vendorBusinesses', 'new-vendor')));
  await assertFails(setDoc(doc(db, 'vendorBusinesses', 'new-vendor'), initial('new-vendor', 'New Bakery')));
});

test('pending and revoked vendors can configure only their own validated public pickup details', async () => {
  const ref = doc(client('pending'), 'vendorBusinesses', 'pending');
  const details = business('pending', {businessName: 'Pending Bakery', approved: false});
  await assertSucceeds(setDoc(ref, details));
  for (const patch of [{approved: true}, {vendorId: 'vendor'}, {businessName: ''}, {businessName: '   '},
    {businessName: 'a'.repeat(101)}, {address: ''}, {address: '  '}, {address: 'a'.repeat(301)},
    {latitude: null}, {latitude: '3.075'}, {latitude: 2.9799}, {latitude: 3.1201}, {longitude: 101.5399},
    {longitude: 101.6401}, {latitude: NaN}, {longitude: Infinity}, {updatedAt: 0},
    {email: 'private@example.test'}, {password: 'secret'}, {configured: false}]) {
    await assertFails(setDoc(ref, {...details, ...patch}));
  }
  for (const uid of ['customer', 'other', 'admin']) {
    await assertFails(setDoc(doc(client(uid), 'vendorBusinesses', 'pending'),
      {...details, businessName: 'Unauthorized business rewrite'}));
  }
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'vendorBusinesses', 'pending'), details));
  await assertFails(deleteDoc(ref));
  await assertSucceeds(approval('vendor', false));
  await assertSucceeds(setDoc(doc(client('vendor'), 'vendorBusinesses', 'vendor'),
    business('vendor', {approved: false, businessName: 'Updated Cafe'})));
  await assertFails(updateDoc(doc(client('vendor'), 'users', 'vendor'), {approved: true}));
});

test('only administrators change approval with reciprocal atomic status and restricted metadata', async () => {
  await assertFails(updateDoc(doc(client('admin'), 'users', 'vendor'),
    {approved: false, revokedBy: 'admin', revokedAt: serverTimestamp(), revocationReason: 'Review required'}));
  await assertFails(updateDoc(doc(client('admin'), 'vendorBusinesses', 'vendor'),
    {approved: false, updatedAt: serverTimestamp()}));
  for (const uid of ['vendor', 'customer', 'other']) {
    const db = client(uid), batch = writeBatch(db);
    batch.update(doc(db, 'users', 'vendor'), {approved: false, revokedBy: uid,
      revokedAt: serverTimestamp(), revocationReason: 'Forged'});
    batch.update(doc(db, 'vendorBusinesses', 'vendor'), {approved: false, updatedAt: serverTimestamp()});
    await assertFails(batch.commit());
  }
  for (const reason of ['', '  ', 'x'.repeat(301)]) await assertFails(approval('vendor', false, reason));
  await assertFails(approval('vendor', false, 'Review', {address: 'Changed by admin'}));
  await assertFails(approval('vendor', false, 'Review', {latitude: 3.1}));
  await assertSucceeds(approval('vendor', false, 'Review required'));
  let saved = (await getDoc(doc(client('admin'), 'users', 'vendor'))).data();
  assert.equal(saved.revokedBy, 'admin');
  assert.equal(saved.revocationReason, 'Review required');
  await assertSucceeds(approval('vendor', true));
  saved = (await getDoc(doc(client('admin'), 'users', 'vendor'))).data();
  assert.equal(saved.approved, true);
  assert.equal(saved.approvedBy, 'admin');
  assert.equal(saved.revocationReason, 'Review required');
  assert.equal((await getDoc(doc(client('customer'), 'vendorBusinesses', 'vendor'))).data().approved, true);
});

test('the approximate Subang/USJ pilot includes each corner and rejects central Kuala Lumpur', async () => {
  const ref = doc(client('pending'), 'vendorBusinesses', 'pending');
  for (const latitude of [2.98, 3.12]) {
    for (const longitude of [101.54, 101.64]) {
      await assertSucceeds(setDoc(ref, business('pending', {approved: false, latitude, longitude})));
    }
  }
  // This KL point was inside the previous, overly broad rectangle.
  await assertFails(setDoc(ref, business('pending', {approved: false, latitude: 3.139, longitude: 101.687})));
  for (const [latitude, longitude] of [[2.9799, 101.59], [3.1201, 101.59],
    [3.075, 101.5399], [3.075, 101.6401]]) {
    await assertFails(setDoc(ref, business('pending', {approved: false, latitude, longitude})));
  }
});

test('existing pickup snapshots outside the tighter pilot remain readable and cancellable', async () => {
  const id = code(99), deal = listing({latitude: 3.139, longitude: 101.687, stock: 9});
  await seed('listings/food', {...deal, lastReservationId: id});
  await seed('listings/food/claims/customer', {quantity: 1, lastReservationId: id});
  await seed('reservations/' + id, {customerId: 'customer', vendorId: 'vendor', listingId: 'food',
    title: deal.title, vendorName: deal.vendorName, address: deal.address,
    latitude: deal.latitude, longitude: deal.longitude, pickupStart: deal.pickupStart, pickupEnd: deal.pickupEnd,
    quantity: 1, unitPriceCents: deal.priceCents, totalCents: deal.priceCents, status: 'reserved',
    code: id, paymentStatus: 'unpaid', createdAt: new Date()});
  const ref = doc(client('customer'), 'reservations', id);
  assert.equal((await assertSucceeds(getDoc(ref))).data().latitude, 3.139);
  await assertSucceeds(cancel('customer', id));
  const saved = (await getDoc(ref)).data();
  assert.equal(saved.status, 'cancelled');
  assert.equal(saved.latitude, 3.139);
  assert.equal(saved.longitude, 101.687);
});

test('admins can revoke and reapprove an older outside location while owner saves require the current pilot', async () => {
  const legacy = business('vendor', {latitude: 3.139, longitude: 101.687});
  await seed('vendorBusinesses/vendor', legacy);
  await assertSucceeds(approval('vendor', false, 'Move pickup point inside the pilot'));
  await assertSucceeds(approval('vendor', true));
  const ref = doc(client('vendor'), 'vendorBusinesses', 'vendor');
  const saved = (await getDoc(ref)).data();
  assert.equal(saved.approved, true);
  assert.equal(saved.latitude, 3.139);
  assert.equal(saved.longitude, 101.687);
  await assertFails(setDoc(ref, {...legacy, businessName: 'Updated outside cafe'}));
  await assertSucceeds(setDoc(ref, business()));
  assert.equal((await getDoc(ref)).data().latitude, 3.075);
});

test('admin approval can safely create missing legacy business profiles without private fields', async () => {
  const db = client('admin'), batch = writeBatch(db);
  batch.update(doc(db, 'users', 'other'), {approved: false, revokedBy: 'admin',
    revokedAt: serverTimestamp(), revocationReason: 'Pending review'});
  batch.set(doc(db, 'vendorBusinesses', 'other'), initial('other', 'Other Cafe', false));
  await assertSucceeds(batch.commit());
  const saved = (await getDoc(doc(db, 'vendorBusinesses', 'other'))).data();
  assert.deepEqual(Object.keys(saved).sort(), ['address', 'approved', 'businessName', 'configured',
    'latitude', 'longitude', 'updatedAt', 'vendorId']);
  assert.equal(saved.configured, false);
  await assertFails(updateDoc(doc(db, 'vendorBusinesses', 'other'), {businessName: 'Admin rewrite', updatedAt: serverTimestamp()}));
});

test('approved businesses are queryable while pending records and private vendor profiles stay restricted', async () => {
  const publicDb = client('customer');
  const results = await assertSucceeds(getDocs(query(collection(publicDb, 'vendorBusinesses'), where('approved', '==', true))));
  assert.deepEqual(results.docs.map(d => d.id), ['vendor']);
  await assertFails(getDocs(collection(publicDb, 'vendorBusinesses')));
  await assertFails(getDoc(doc(client('other'), 'vendorBusinesses', 'pending')));
  await assertSucceeds(getDoc(doc(client('pending'), 'vendorBusinesses', 'pending')));
  await assertSucceeds(getDocs(collection(client('admin'), 'vendorBusinesses')));
  await assertFails(getDocs(query(collection(env.unauthenticatedContext().firestore(), 'vendorBusinesses'), where('approved', '==', true))));
  await assertFails(getDoc(doc(publicDb, 'users', 'vendor')));
});

test('configured listings must match the business while legacy locationless content edits survive', async () => {
  const ref = id => doc(client('vendor'), 'listings', id);
  await assertSucceeds(setDoc(ref('food'), listing()));
  for (const patch of [{vendorName: 'Spoofed'}, {address: 'Other address'}, {latitude: 3.1},
    {longitude: 101.6}, {latitude: null}, {longitude: 101.9}]) {
    await assertFails(setDoc(ref('bad'), listing(patch)));
    await assertFails(updateDoc(ref('food'), patch));
  }
  const noCoordinates = listing(); delete noCoordinates.latitude; delete noCoordinates.longitude;
  await assertFails(setDoc(ref('missing-coordinates'), noCoordinates));
  // A legacy approved account cannot bypass setup through a direct SDK write.
  await assertFails(setDoc(doc(client('other'), 'listings', 'legacy-publish'),
    {...noCoordinates, vendorId: 'other', vendorName: 'Other Cafe'}));
  await assertFails(setDoc(doc(client('other'), 'listings', 'legacy-publish-coordinates'),
    listing({vendorId: 'other', vendorName: 'Other Cafe'})));
  const pending = listing({vendorId: 'pending', vendorName: 'Pending Cafe'});
  await assertFails(setDoc(doc(client('pending'), 'listings', 'pending'), pending));
  await assertSucceeds(approval('pending', true));
  await assertFails(setDoc(doc(client('pending'), 'listings', 'unconfigured'), pending));
  await seed('listings/legacy', noCoordinates);
  await assertSucceeds(updateDoc(ref('legacy'), {priceCents: 700}));
  await assertFails(updateDoc(ref('legacy'), {address: 'Random address'}));
  await assertSucceeds(updateDoc(ref('legacy'), {vendorName: 'Subang Cafe', address: '1 Jalan SS15, Subang Jaya', latitude: 3.075, longitude: 101.59}));
  await assertSucceeds(setDoc(doc(client('vendor'), 'vendorBusinesses', 'vendor'),
    business('vendor', {businessName: 'New Cafe', address: '2 Jalan SS15', latitude: 3.08, longitude: 101.6})));
  await assertSucceeds(updateDoc(ref('food'), {vendorName: 'New Cafe', address: '2 Jalan SS15', latitude: 3.08, longitude: 101.6}));
  await assertFails(updateDoc(ref('food'), {vendorName: 'Subang Cafe'}));
});

test('reservation coordinates are an exact immutable listing snapshot', async () => {
  await setDoc(doc(client('vendor'), 'listings', 'food'), listing());
  for (const [i, patch] of [{latitude: 3.1}, {longitude: 101.6}, {latitude: undefined},
    {latitude: undefined, longitude: undefined}, {latitude: null, longitude: null}].entries()) {
    await assertFails(reserve('food', i + 1, patch));
  }
  const id = await assertSucceeds(reserve('food', 10));
  const saved = (await getDoc(doc(client('customer'), 'reservations', id))).data();
  assert.equal(saved.latitude, 3.075); assert.equal(saved.longitude, 101.59);
  await assertFails(updateDoc(doc(client('customer'), 'reservations', id), {latitude: 3.1}));
  await assertFails(updateDoc(doc(client('vendor'), 'reservations', id),
    {status: 'collected', collectedAt: serverTimestamp(), longitude: 101.6}));
  await setDoc(doc(client('vendor'), 'vendorBusinesses', 'vendor'), business('vendor', {latitude: 3.08}));
  await updateDoc(doc(client('vendor'), 'listings', 'food'), {latitude: 3.08});
  assert.equal((await getDoc(doc(client('customer'), 'reservations', id))).data().latitude, 3.075);
});

test('revocation blocks new publishing, reservations and vendor mutations while customers can cancel', async () => {
  await setDoc(doc(client('vendor'), 'listings', 'food'), listing());
  const id = await reserve('food', 11);
  await assertSucceeds(approval('vendor', false));
  await assertFails(setDoc(doc(client('vendor'), 'listings', 'new-food'), listing()));
  await assertFails(updateDoc(doc(client('vendor'), 'listings', 'food'), {priceCents: 700}));
  await assertFails(updateDoc(doc(client('vendor'), 'listings', 'food'), {active: false}));
  await assertFails(reserve('food', 12));
  await assertFails(updateDoc(doc(client('vendor'), 'reservations', id), {status: 'collected', collectedAt: serverTimestamp()}));
  await assertFails(cancel('vendor', id));
  await assertSucceeds(cancel('customer', id));
  assert.equal((await getDoc(doc(client('customer'), 'reservations', id))).data().status, 'cancelled');
  assert.equal((await getDoc(doc(client('vendor'), 'listings', 'food'))).data().stock, 10);
});
