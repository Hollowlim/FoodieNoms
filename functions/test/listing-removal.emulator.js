const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc,deleteDoc,deleteField,serverTimestamp,Timestamp} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Use only the local Firestore emulator.');
let env;
const client = uid => env.authenticatedContext(uid).firestore();
const seed = (path,data) => env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(),path),data));
const listing = patch => ({title:'Accidental lunch',description:'Rice and tofu',dietary:'Contains soy',
  category:'Meals',priceCents:800,originalPriceCents:1500,stock:4,
  vendorId:'vendor',vendorName:'Subang Cafe',address:'8 Jalan SS15',latitude:3.075,longitude:101.59,
  pickupStart:Date.now()-60000,pickupEnd:Date.now()+7200000,active:true,createdAt:Timestamp.now(),...patch});
const remove = (uid,id='food',patch={}) => updateDoc(doc(client(uid),'listings',id),
  {active:false,removedAt:serverTimestamp(),...patch});
before(async () => {env=await initializeTestEnvironment({projectId:'demo-foodienoms',
  firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync('../firestore.rules','utf8')}});});
beforeEach(async () => {
  await env.clearFirestore();
  for (const [uid,role,approved] of [['vendor','vendor',true],['other','vendor',true],
    ['pending','vendor',false],['customer','customer',false],['admin','admin',true]]) {
    await seed('users/'+uid,{name:uid,role,approved});
  }
  await seed('listings/food',listing());
});
after(async () => {await env?.cleanup();});

test('approved owner can remove active, sold-out, unavailable and expired listings without deleting fields',async () => {
  for (const [i,patch] of [{},{stock:0},{active:false},{pickupEnd:Date.now()-60000,pickupStart:Date.now()-7200000}].entries()) {
    const id='food-'+i;
    await seed('listings/'+id,listing(patch));
    const ref=doc(client('vendor'),'listings',id),before=(await getDoc(ref)).data();
    await assertSucceeds(remove('vendor',id));
    const after=(await getDoc(ref)).data();
    assert.equal(after.active,false);assert.ok(after.removedAt instanceof Timestamp);
    const {active,...old}=before,{active:ignored,removedAt,...kept}=after;
    assert.deepEqual(kept,old);
  }
});
test('removal is limited to the approved owner and the server timestamp',async () => {
  for (const uid of ['other','pending','customer','admin']) await assertFails(remove(uid));
  await assertFails(updateDoc(doc(env.unauthenticatedContext().firestore(),'listings','food'),
    {active:false,removedAt:serverTimestamp()}));
  for (const patch of [{active:true},{removedAt:0},{removedAt:null},{removedAt:Timestamp.fromMillis(1)},
    {title:'Changed contents'},{stock:0},{vendorId:'other'},{priceCents:1},{extra:'metadata'}]) {
    await assertFails(remove('vendor','food',patch));
  }
  await seed('users/vendor',{name:'vendor',role:'vendor',approved:false});
  await assertFails(remove('vendor'));
});
test('removed listings cannot be reopened, edited, restamped or permanently deleted',async () => {
  await remove('vendor');
  const ref=doc(client('vendor'),'listings','food');
  for (const patch of [{active:true},{active:false},{title:'New name'},{stock:6},
    {removedAt:deleteField()},{removedAt:serverTimestamp()},
    {removedAt:deleteField(),active:true},{pickupEnd:Date.now()+10800000}]) {
    await assertFails(updateDoc(ref,patch));
  }
  await assertFails(deleteDoc(ref));
  await assertFails(getDoc(doc(client('customer'),'listings','food')));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(getDoc(doc(client('admin'),'listings','food')));
});
test('new listings cannot be published with removal metadata',async () => {
  await seed('vendorBusinesses/vendor',{vendorId:'vendor',businessName:'Subang Cafe',address:'8 Jalan SS15',
    latitude:3.075,longitude:101.59,approved:true,configured:true,updatedAt:Timestamp.now()});
  await assertFails(setDoc(doc(client('vendor'),'listings','new'),
    listing({removedAt:serverTimestamp(),createdAt:serverTimestamp()})));
});
