const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, collection, query, orderBy,
  serverTimestamp, writeBatch, Bytes, deleteField} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Use only the isolated Firestore emulator.');
let env;
const id = n => n.toString(16).padStart(32, '0');
const client = uid => env.authenticatedContext(uid).firestore();
const jpeg = size => Bytes.fromUint8Array(Uint8Array.from({length: size}, (_, i) => i === 0 ? 255 : i === 1 ? 216 : 0));
const photo = (patch = {}) => ({vendorId: 'vendor', bytes: jpeg(20), contentType: 'image/jpeg',
  published: false, firstListingId: '', createdAt: serverTimestamp(), ...patch});
const listing = (patch = {}) => ({title: 'Lunch box', description: 'Rice, vegetables and tofu',
  dietary: 'Vendor supplied information', category: 'Meals', priceCents: 890, originalPriceCents: 1290,
  stock: 4, pickupStart: Date.now() - 60000, pickupEnd: Date.now() + 7200000, vendorId: 'vendor',
  vendorName: 'Subang Cafe', address: '8 Jalan SS15', latitude: 3.075, longitude: 101.59,
  active: true, createdAt: serverTimestamp(), ...patch});
const draft = (formData = {}, patch = {}) => ({vendorId: 'vendor', formVersion: 1, formData,
  sourceListingId: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...patch});
const draftRef = (uid, draftId = id(1)) => doc(client(uid), 'listingDrafts', 'vendor', 'items', draftId);
const seed = (path, data) => env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), path), data));
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-foodienoms', firestore: {
    host: '127.0.0.1', port: 8080, rules: fs.readFileSync('../firestore.rules', 'utf8')}});
});
beforeEach(async () => {
  await env.clearFirestore();
  for (const [uid, role, approved] of [['vendor', 'vendor', true], ['other', 'vendor', true],
    ['pending', 'vendor', false], ['customer', 'customer', false], ['admin', 'admin', true]]) {
    await seed('users/' + uid, {name: uid, role, approved});
  }
  for (const uid of ['vendor', 'other']) await seed('vendorBusinesses/' + uid,
    {vendorId: uid, businessName: uid === 'vendor' ? 'Subang Cafe' : 'Other Cafe', address: '8 Jalan SS15',
      latitude: 3.075, longitude: 101.59, approved: true, configured: true, updatedAt: serverTimestamp()});
});
after(async () => { await env?.cleanup(); });
function publish(photoId, listingId = id(100), patch = {}, uid = 'vendor') {
  const db = client(uid), batch = writeBatch(db);
  batch.set(doc(db, 'listings', listingId), listing({imageId: photoId, ...patch}));
  batch.update(doc(db, 'listingPhotos', photoId), {published: true, firstListingId: listingId});
  return batch.commit();
}

test('partial drafts restore exactly, preserve creation time and stay private even from administrators', async () => {
  const formData = {title: 'Unfinished lunch', description: '', priceText: '8.', quantityText: '',
    pickupStart: null, pickupEnd: null, startsNow: true, imageId: null, imageKey: 'photo-1',
    dietaryTags: ['Vegetarian'], halalStatus: 'not_declared'};
  await assertSucceeds(setDoc(draftRef('vendor'), draft(formData)));
  const saved = (await getDoc(draftRef('vendor'))).data();
  assert.deepEqual(saved.formData, formData);
  await assertSucceeds(updateDoc(draftRef('vendor'), {formData: {...formData, ingredients: 'Tofu'}, updatedAt: serverTimestamp()}));
  assert.equal((await getDoc(draftRef('vendor'))).data().createdAt.toMillis(), saved.createdAt.toMillis());
  await assertSucceeds(getDocs(query(collection(client('vendor'), 'listingDrafts', 'vendor', 'items'), orderBy('updatedAt', 'desc'))));
  for (const uid of ['other', 'customer', 'admin', 'pending']) {
    await assertFails(getDoc(draftRef(uid)));
    await assertFails(getDocs(collection(client(uid), 'listingDrafts', 'vendor', 'items')));
  }
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'listingDrafts', 'vendor', 'items', id(1))));
  await seed('users/vendor', {name: 'vendor', role: 'vendor', approved: false});
  await assertSucceeds(getDoc(draftRef('vendor')));
  await assertFails(updateDoc(draftRef('vendor'), {updatedAt: serverTimestamp()}));
  await assertFails(deleteDoc(draftRef('vendor')));
});

test('draft owner, schema, photo references, timestamps and bounded partial values are enforced', async () => {
  for (const uid of ['other', 'customer', 'pending', 'admin']) await assertFails(setDoc(draftRef(uid), draft()));
  await assertFails(setDoc(doc(client('vendor'), 'listingDrafts', 'other', 'items', id(1)), draft({},{vendorId:'other'})));
  for (const [i, patch] of [{vendorId: 'other'}, {formVersion: 2}, {formData: []}, {createdAt: 0},
    {updatedAt: 0}, {password: 'private'}, {sourceListingId: 'not-owned'}].entries()) {
    await assertFails(setDoc(draftRef('vendor', id(10 + i)), draft({}, patch)));
  }
  const invalidForms = [{title: 'x'.repeat(101)}, {description: 'x'.repeat(1001)}, {priceText: 'x'.repeat(21)},
    {originalPriceText: 10}, {quantityText: 'x'.repeat(9)}, {ingredients: 'x'.repeat(501)},
    {startsNow: 1}, {pickupStart: 'tomorrow'}, {pickupEnd: 1.5}, {unknown: 'metadata'},
    {imageId: id(999)}, {imageKey: 'https://external.test/photo.jpg'}, {dietaryTags: ['Vegan', 'Vegan']},
    {halalStatus: 'halal_certified'}, {vendorId: 'vendor'}, {bytes: jpeg(20)}];
  for (const [i, form] of invalidForms.entries()) await assertFails(setDoc(draftRef('vendor', id(30 + i)), draft(form)));
  await setDoc(doc(client('other'), 'listingPhotos', id(91)), photo({vendorId: 'other'}));
  await assertFails(setDoc(draftRef('vendor'), draft({imageId: id(91)})));
  await setDoc(doc(client('vendor'), 'listingPhotos', id(92)), photo());
  await assertSucceeds(setDoc(draftRef('vendor'), draft({imageId: id(92)})));
  await seed('listings/source', listing());
  await assertSucceeds(updateDoc(draftRef('vendor'), {sourceListingId: 'source', updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(draftRef('vendor'), {createdAt: serverTimestamp(), updatedAt: serverTimestamp()}));
});

test('photo upload bytes are bounded and immutable, with owner/admin private access only', async () => {
  const ref = doc(client('vendor'), 'listingPhotos', id(1));
  await assertSucceeds(setDoc(ref, photo({bytes: jpeg(160 * 1024)})));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(getDoc(doc(client('admin'), 'listingPhotos', id(1))));
  for (const uid of ['other', 'customer', 'pending']) await assertFails(getDoc(doc(client(uid), 'listingPhotos', id(1))));
  await assertFails(getDocs(collection(client('vendor'), 'listingPhotos')));
  await assertFails(updateDoc(ref, {bytes: jpeg(10)}));
  await assertFails(deleteDoc(ref));
  for (const [i, patch] of [{vendorId: 'other'}, {bytes: jpeg(0)}, {bytes: jpeg(160 * 1024 + 1)},
    {bytes: 'base64-string'}, {contentType: 'image/png'}, {published: true}, {firstListingId: 'forged'},
    {createdAt: 0}, {extra: 'field'}].entries()) {
    await assertFails(setDoc(doc(client('vendor'), 'listingPhotos', id(10 + i)), photo(patch)));
  }
  for (const uid of ['customer', 'pending', 'admin']) await assertFails(setDoc(doc(client(uid), 'listingPhotos', id(50)), photo({vendorId: uid})));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'listingPhotos', id(51)), photo()));
});

test('photos become public only atomically with an owned listing and are reusable only by that vendor', async () => {
  const photoId = id(1), db = client('vendor');
  await setDoc(doc(db, 'listingPhotos', photoId), photo());
  await assertFails(setDoc(doc(db, 'listings', id(101)), listing({imageId: photoId})));
  await assertFails(updateDoc(doc(db, 'listingPhotos', photoId), {published: true, firstListingId: id(101)}));
  await assertSucceeds(publish(photoId));
  await assertSucceeds(getDoc(doc(client('customer'), 'listingPhotos', photoId)));
  await assertSucceeds(setDoc(doc(db, 'listings', id(102)), listing({imageId: photoId})));
  await assertFails(setDoc(doc(client('other'), 'listings', id(103)), listing({vendorId: 'other', vendorName: 'Other Cafe', imageId: photoId})));
  await assertFails(updateDoc(doc(db, 'listingPhotos', photoId), {firstListingId: id(102)}));
  await assertFails(updateDoc(doc(db, 'listingPhotos', photoId), {published: false}));
  await seed('users/vendor', {name: 'vendor', role: 'vendor', approved: false});
  await assertFails(getDoc(doc(client('customer'), 'listingPhotos', photoId)));
  await assertSucceeds(getDoc(doc(db, 'listingPhotos', photoId)));
});

test('atomic photo attachment works during edits and removals preserve old photo records', async () => {
  const db = client('vendor'), photoId = id(1), listingId = id(100);
  await setDoc(doc(db, 'listings', listingId), listing());
  await setDoc(doc(db, 'listingPhotos', photoId), photo());
  const batch = writeBatch(db);
  batch.update(doc(db, 'listings', listingId), {imageId: photoId});
  batch.update(doc(db, 'listingPhotos', photoId), {published: true, firstListingId: listingId});
  await assertSucceeds(batch.commit());
  await assertSucceeds(updateDoc(doc(db, 'listings', listingId), {imageId: deleteField(), imageKey: 'photo-2'}));
  assert.equal((await getDoc(doc(db, 'listingPhotos', photoId))).data().published, true);
  await assertFails(updateDoc(doc(db, 'listingPhotos', photoId), {bytes: jpeg(15)}));
});

test('failed publication retains private photo and draft; successful publication deletes draft atomically', async () => {
  const db = client('vendor'), photoId = id(1), listingId = id(100);
  await setDoc(doc(db, 'listingPhotos', photoId), photo());
  await setDoc(draftRef('vendor'), draft({title: 'Draft lunch', imageId: photoId}));
  const attempt = patch => {
    const batch = writeBatch(db);
    batch.set(doc(db, 'listings', listingId), listing({imageId: photoId, ...patch}));
    batch.update(doc(db, 'listingPhotos', photoId), {published: true, firstListingId: listingId});
    batch.delete(doc(db, 'listingDrafts', 'vendor', 'items', id(1)));
    return batch.commit();
  };
  await assertFails(attempt({priceCents: -1}));
  assert.equal((await getDoc(draftRef('vendor'))).exists(), true);
  assert.equal((await getDoc(doc(db, 'listingPhotos', photoId))).data().published, false);
  await assertSucceeds(attempt({}));
  assert.equal((await getDoc(draftRef('vendor'))).exists(), false);
});

test('new food metadata is bounded and halal declarations cannot claim certification', async () => {
  const db = client('vendor'), ref = doc(db, 'listings', id(100));
  const metadata = {foodDescription: 'Prepared today', ingredients: 'Rice, tofu, soy', allergens: 'Soy',
    dietaryTags: ['Vegetarian', 'Vegan', 'Gluten-free', 'Dairy-free'], halalStatus: 'vendor_declared', pickupInstructions: 'Ask at the counter'};
  await assertSucceeds(setDoc(ref, listing(metadata)));
  await assertSucceeds(updateDoc(ref, {foodDescription: '', dietaryTags: [], halalStatus: 'not_declared'}));
  for (const patch of [{foodDescription: 'x'.repeat(1001)}, {ingredients: 'x'.repeat(501)},
    {allergens: 7}, {pickupInstructions: null}, {dietaryTags: ['Vegan', 'Vegan']}, {dietaryTags: ['Halal']},
    {dietaryTags: 'Vegan'}, {halalStatus: 'certified'}, {halalStatus: true}, {requestId: id(3)},
    {expectedStock: 4}, {draftId: id(1)}]) {
    await assertFails(updateDoc(ref, patch));
    await assertFails(setDoc(doc(db, 'listings', id(101)), listing(patch)));
  }
});

test('strict create discounts and changed edit prices preserve equal-price legacy content edits', async () => {
  const db = client('vendor'), ref = doc(db, 'listings', 'legacy-equal');
  await assertFails(setDoc(doc(db, 'listings', id(100)), listing({originalPriceCents: 890})));
  await seed('listings/legacy-equal', listing({originalPriceCents: 890, pickupStart: Date.now() - 7200000}));
  await assertSucceeds(updateDoc(ref, {description: 'Updated included contents'}));
  await assertSucceeds(updateDoc(ref, {stock: 0}));
  await assertFails(updateDoc(ref, {priceCents: 900, originalPriceCents: 900}));
  await assertSucceeds(updateDoc(ref, {priceCents: 700, originalPriceCents: 890}));
  await assertSucceeds(updateDoc(ref, {pickupEnd: Date.now() + 10800000}));
});
