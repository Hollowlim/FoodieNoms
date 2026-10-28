const {test, before, after} = require('node:test');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs, serverTimestamp} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Phase 1 tests require the Firestore emulator.');
let env;
const profile = (role = 'customer') => ({name: 'Test Account', role, approved: false, createdAt: serverTimestamp()});
const userDb = uid => env.authenticatedContext(uid).firestore();
const approve = uid => ({approved: true, approvedBy: uid, approvedAt: serverTimestamp()});
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-foodienoms', firestore: {
    host:'127.0.0.1', port:8080, rules:fs.readFileSync('../firestore.rules','utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'users','admin'), {name:'Admin',role:'admin',approved:true});
  });
});
after(async () => { await env?.cleanup(); });

test('customers and vendors create only their own pending profiles', async () => {
  await assertSucceeds(setDoc(doc(userDb('customer'),'users','customer'),profile()));
  await assertSucceeds(setDoc(doc(userDb('vendor'),'users','vendor'),profile('vendor')));
  await assertFails(setDoc(doc(userDb('intruder'),'users','someone-else'),profile()));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(),'users','guest'),profile()));
  await assertFails(setDoc(doc(userDb('self-admin'),'users','self-admin'),profile('admin')));
  await assertFails(setDoc(doc(userDb('self-approved'),'users','self-approved'),{...profile('vendor'),approved:true}));
  await assertFails(setDoc(doc(userDb('bad-name'),'users','bad-name'),{...profile(),name:''}));
  await assertFails(setDoc(doc(userDb('space-name'),'users','space-name'),{...profile(),name:'   '}));
  await assertFails(setDoc(doc(userDb('extra'),'users','extra'),{...profile(),approvedBy:'admin'}));
  await assertFails(setDoc(doc(userDb('bad-time'),'users','bad-time'),{...profile(),createdAt:0}));
});
test('profiles are private and clients cannot change roles or delete profiles', async () => {
  await assertSucceeds(getDoc(doc(userDb('customer'),'users','customer')));
  await assertSucceeds(getDoc(doc(userDb('new-account'),'users','new-account')));
  await assertFails(getDoc(doc(userDb('customer'),'users','vendor')));
  await assertFails(getDocs(collection(userDb('customer'),'users')));
  await assertFails(updateDoc(doc(userDb('customer'),'users','customer'),{role:'admin'}));
  await assertFails(deleteDoc(doc(userDb('customer'),'users','customer')));
  await assertFails(setDoc(doc(userDb('customer'),'users','customer'),profile('vendor')));
});
test('only admins can approve a vendor and cannot smuggle other changes', async () => {
  const vendorRef = doc(userDb('admin'),'users','vendor');
  await assertFails(updateDoc(doc(userDb('vendor'),'users','vendor'),approve('vendor')));
  await assertFails(updateDoc(doc(userDb('customer'),'users','vendor'),approve('customer')));
  await assertFails(updateDoc(vendorRef,{...approve('admin'),name:'Changed'}));
  await assertFails(updateDoc(vendorRef,{...approve('admin'),role:'admin'}));
  await assertFails(updateDoc(vendorRef,{...approve('admin'),approvedBy:'someone-else'}));
  await assertFails(updateDoc(vendorRef,{...approve('admin'),approvedAt:0}));
  await assertFails(updateDoc(doc(userDb('admin'),'users','customer'),approve('admin')));
  await assertSucceeds(getDocs(query(collection(userDb('admin'),'users'),where('role','==','vendor'))));
  await assertFails(getDocs(collection(userDb('admin'),'users')));
  await assertSucceeds(updateDoc(vendorRef,approve('admin')));
  await assertFails(updateDoc(vendorRef,{approved:false}));
});
test('forged listings, orders and lookup codes remain blocked', async () => {
  for (const uid of ['customer','vendor','admin']) {
    for (const name of ['listings','reservations','pickupCodes']) {
      await assertFails(setDoc(doc(userDb(uid),name,'forged'),{customerId:uid,vendorId:uid,stock:999}));
      if (name === 'pickupCodes') await assertFails(getDoc(doc(userDb(uid),name,'forged')));
    }
  }
});
