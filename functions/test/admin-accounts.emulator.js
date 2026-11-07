const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs, writeBatch, serverTimestamp} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Admin account tests require the local Firestore emulator.');
let env;
const client = uid => env.authenticatedContext(uid).firestore();
const adminProfile = (overrides = {}) => ({
  name: 'New Administrator', email: 'new-admin@example.test', role: 'admin',
  approved: true, createdBy: 'owner-admin', createdAt: serverTimestamp(), ...overrides,
});
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-foodienoms', firestore: {
    host: '127.0.0.1', port: 8080, rules: fs.readFileSync('../firestore.rules', 'utf8'),
  }});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [uid, role] of [['owner-admin', 'admin'], ['customer', 'customer'], ['vendor', 'vendor']]) {
      await setDoc(doc(db, 'users', uid), {name: uid, role, approved: role === 'admin', createdAt: new Date()});
    }
  });
});
after(async () => { await env?.cleanup(); });

test('an existing admin creates a strict profile for a separate new administrator', async () => {
  const ref = doc(client('owner-admin'), 'users', 'new-admin');
  await assertSucceeds(setDoc(ref, adminProfile()));
  const saved = (await getDoc(ref)).data();
  assert.equal(saved.role, 'admin');
  assert.equal(saved.approved, true);
  assert.equal(saved.createdBy, 'owner-admin');
  assert.deepEqual(Object.keys(saved).sort(), ['approved', 'createdAt', 'createdBy', 'email', 'name', 'role']);
  await assertSucceeds(getDoc(doc(client('new-admin'), 'users', 'vendor')));
});

test('guests, customers, vendors and unprofiled users cannot create an administrator', async () => {
  const actors = [env.unauthenticatedContext().firestore(), client('customer'), client('vendor'), client('unprofiled')];
  for (const [i, db] of actors.entries()) {
    await assertFails(setDoc(doc(db, 'users', 'unauthorized-admin-' + i), adminProfile()));
  }
  await assertFails(setDoc(doc(client('self'), 'users', 'self'), adminProfile({createdBy: 'self'})));
  // An existing administrator cannot replace its own immutable profile either.
  await assertFails(setDoc(doc(client('owner-admin'), 'users', 'owner-admin'), adminProfile()));
});

test('administrator provisioning rejects forged metadata, malformed fields and password storage', async () => {
  const patches = [
    {name: ''}, {name: '   '}, {name: 'a'.repeat(101)}, {name: 123},
    {email: ''}, {email: '   '}, {email: 'not-an-email'}, {email: 'a'.repeat(255)}, {email: 123},
    {role: 'vendor'}, {approved: false}, {approved: 'true'},
    {createdBy: 'other-admin'}, {createdAt: 0},
    {password: 'must-not-be-stored'}, {temporaryPassword: 'must-not-be-stored'},
    {passwordHash: 'must-not-be-stored'}, {extra: true},
  ];
  for (const [i, patch] of patches.entries()) {
    await assertFails(setDoc(doc(client('owner-admin'), 'users', 'invalid-admin-' + i), adminProfile(patch)));
  }
  for (const key of ['name', 'email', 'role', 'approved', 'createdBy', 'createdAt']) {
    const data = adminProfile(); delete data[key];
    await assertFails(setDoc(doc(client('owner-admin'), 'users', 'missing-' + key), data));
  }
});

test('existing profiles cannot be promoted, replaced or modified through admin provisioning', async () => {
  const db = client('owner-admin');
  for (const uid of ['customer', 'vendor', 'new-admin', 'owner-admin']) {
    await assertFails(setDoc(doc(db, 'users', uid), adminProfile()));
    await assertFails(updateDoc(doc(db, 'users', uid), {role: 'admin', email: 'replacement@example.test'}));
  }
  assert.equal((await getDoc(doc(db, 'users', 'customer'))).data().role, 'customer');
  assert.equal((await getDoc(doc(db, 'users', 'vendor'))).data().role, 'vendor');
});

test('non-admin batches cannot bootstrap an administrator and then grant another one', async () => {
  for (const uid of ['customer', 'batch-attacker']) {
    const db = client(uid), batch = writeBatch(db);
    batch.set(doc(db, 'users', uid), adminProfile({createdBy: uid}));
    batch.set(doc(db, 'users', uid + '-target'), adminProfile({createdBy: uid}));
    await assertFails(batch.commit());
  }
  await assertFails(getDoc(doc(client('customer'), 'users', 'customer-target')));
});

test('admins can query administrator and vendor directories while customer directories stay private', async () => {
  for (const uid of ['owner-admin', 'new-admin']) {
    const db = client(uid);
    const admins = await assertSucceeds(getDocs(query(collection(db, 'users'), where('role', '==', 'admin'))));
    assert.equal(admins.size, 2);
    await assertSucceeds(getDocs(query(collection(db, 'users'), where('role', '==', 'vendor'))));
    await assertSucceeds(getDocs(query(collection(db, 'users'), where('role', 'in', ['admin', 'vendor']))));
    await assertFails(getDocs(query(collection(db, 'users'), where('role', '==', 'customer'))));
    await assertFails(getDocs(collection(db, 'users')));
  }
  for (const uid of ['customer', 'vendor', 'unprofiled']) {
    await assertFails(getDocs(query(collection(client(uid), 'users'), where('role', '==', 'admin'))));
    await assertFails(getDocs(query(collection(client(uid), 'users'), where('role', '==', 'vendor'))));
  }
  await assertFails(getDocs(query(collection(env.unauthenticatedContext().firestore(), 'users'), where('role', '==', 'admin'))));
});
