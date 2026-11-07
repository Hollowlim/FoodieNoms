const {test,before,beforeEach,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc,writeBatch,collection,getDocs,serverTimestamp}=require('firebase/firestore');
if(!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Use the isolated Firestore emulator.');
const GRACE=900000;
let env,serial=0;
const client=uid=>env.authenticatedContext(uid).firestore();
const seed=(path,data)=>env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),path),data));
const id=()=>`FN-${(++serial).toString(16).toUpperCase().padStart(20,'0')}`;
const listing=(vendorId='vendor')=>({title:'Tofu lunch',description:'Rice and tofu',dietary:'Soy',category:'Meals',
  vendorId,vendorName:'Subang Cafe',address:'SS15',priceCents:800,originalPriceCents:1500,stock:10,
  pickupStart:Date.now()-60000,pickupEnd:Date.now()+3600000,active:true,createdAt:new Date()});
const order=(rid,deal,patch={})=>({customerId:'customer',vendorId:deal.vendorId,listingId:deal.vendorId,
  title:deal.title,vendorName:deal.vendorName,address:deal.address,pickupStart:deal.pickupStart,pickupEnd:deal.pickupEnd,
  quantity:1,unitPriceCents:800,totalCents:800,status:'reserved',code:rid,paymentStatus:'unpaid',
  createdAt:serverTimestamp(),...patch});
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-foodienoms',firestore:{host:'127.0.0.1',port:8080,
  rules:fs.readFileSync('../firestore.rules','utf8')}});});
beforeEach(async()=>{
  await env.clearFirestore();
  for(const [uid,role,approved] of [['vendor','vendor',true],['other','vendor',true],['pending','vendor',false],
      ['customer','customer',false],['other-customer','customer',false],['admin','admin',true]]) {
    await seed('users/'+uid,{name:uid,role,approved});
  }
  for(const vendor of ['vendor','other']) await seed('listings/'+vendor,listing(vendor));
});
after(async()=>{await env?.cleanup();});
async function reserve(code='0123',vendorId='vendor',options={}) {
  const db=client('customer'),rid=id();
  const ref=doc(db,'listings',vendorId),deal=(await getDoc(ref)).data();
  const claimRef=doc(db,'listings',vendorId,'claims','customer');
  const held=(await getDoc(claimRef)).data()?.quantity||0;
  const batch=writeBatch(db);
  batch.set(doc(db,'reservations',rid),order(rid,deal,{pickupCode:code,...options.orderPatch}));
  if(!options.skipLock) batch.set(doc(db,'vendors',vendorId,'pickupCodes',code),
    {reservationId:rid,until:deal.pickupEnd+GRACE,...options.lockPatch});
  batch.update(ref,{stock:deal.stock-1,lastReservationId:rid});
  batch.set(claimRef,{quantity:held+1,lastReservationId:rid});
  await batch.commit();return rid;
}
const ready={status:'ready',readyAt:serverTimestamp()};
const noshow={status:'noshow',noshowAt:serverTimestamp()};

test('new codes are atomic and cannot collide at a shop; the same code is valid at different shops',async()=>{
  const first=await reserve('0007');
  assert.equal((await getDoc(doc(client('customer'),'reservations',first))).data().pickupCode,'0007');
  await assertFails(reserve('0007'));
  assert.equal((await getDoc(doc(client('vendor'),'listings','vendor'))).data().stock,9);
  await assertSucceeds(reserve('0007','other'));
  assert.notEqual((await getDoc(doc(client('customer'),'vendors','other','pickupCodes','0007'))).data().reservationId,first);
});
test('short codes require a matching new reservation and an exact expiry',async()=>{
  await assertFails(reserve('0123','vendor',{skipLock:true}));
  for(const lockPatch of [{until:0},{reservationId:'FN-00000000000000000000'},{extra:true}]) {
    await assertFails(reserve('0123','vendor',{lockPatch}));
  }
  for(const code of ['123','12345','abcd']) await assertFails(reserve(code));
  for(const uid of ['vendor','other','pending','admin']) {
    await assertFails(setDoc(doc(client(uid),'vendors','vendor','pickupCodes','1234'),{reservationId:id(),until:Date.now()+GRACE}));
  }
});
test('only expired code locks can be reused and code records expose no order details',async()=>{
  await seed('vendors/vendor/pickupCodes/0042',{reservationId:id(),until:Date.now()-1});
  const rid=await reserve('0042');
  const lock=(await getDoc(doc(client('customer'),'vendors','vendor','pickupCodes','0042'))).data();
  assert.equal(lock.reservationId,rid);assert.deepEqual(Object.keys(lock).sort(),['reservationId','until']);
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'vendors','vendor','pickupCodes','0042')));
  await assertFails(getDocs(collection(client('customer'),'vendors','vendor','pickupCodes')));
  await assertFails(getDoc(doc(client('other-customer'),'reservations',rid)));
});
test('ready requires the approved owner and cannot change prices, snapshots, codes or stock',async()=>{
  const rid=await reserve();
  for(const uid of ['customer','other-customer','other','pending','admin']) {
    await assertFails(updateDoc(doc(client(uid),'reservations',rid),ready));
  }
  const ref=doc(client('vendor'),'reservations',rid);
  for(const patch of [{readyAt:0},{pickupCode:'9999'},{unitPriceCents:1},{pickupEnd:Date.now()+7200000},{quantity:2}]) {
    await assertFails(updateDoc(ref,{...ready,...patch}));
  }
  await assertSucceeds(updateDoc(ref,ready));
  assert.equal((await getDoc(ref)).data().status,'ready');
  assert.equal((await getDoc(doc(client('vendor'),'listings','vendor'))).data().stock,9);
  await assertFails(updateDoc(ref,ready));
  await assertFails(updateDoc(ref,noshow));
  await assertSucceeds(updateDoc(ref,{status:'collected',collectedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref,ready));await assertFails(updateDoc(ref,noshow));
});
test('ready cancellation still returns stock and customer allowance atomically',async()=>{
  const rid=await reserve();await updateDoc(doc(client('vendor'),'reservations',rid),ready);
  const db=client('customer'),batch=writeBatch(db);
  batch.update(doc(db,'reservations',rid),{status:'cancelled',cancelledBy:'customer',cancelledAt:serverTimestamp()});
  batch.update(doc(db,'listings','vendor'),{stock:10,lastReleaseId:rid});
  batch.update(doc(db,'listings','vendor','claims','customer'),{quantity:0,lastReleaseId:rid});
  await assertSucceeds(batch.commit());
  assert.equal((await getDoc(doc(client('vendor'),'listings','vendor'))).data().stock,10);
});
test('not-collected is available only after the grace period, preserves stock and is terminal',async()=>{
  const live=await reserve();await assertFails(updateDoc(doc(client('vendor'),'reservations',live),noshow));
  for(const status of ['reserved','ready']) {
    const rid=id(),old=listing();
    await seed('reservations/'+rid,{...order(rid,old),createdAt:new Date(),status,
      pickupStart:Date.now()-7200000,pickupEnd:Date.now()-GRACE-60000});
    for(const uid of ['customer','other','pending','admin']) {
      await assertFails(updateDoc(doc(client(uid),'reservations',rid),noshow));
    }
    const ref=doc(client('vendor'),'reservations',rid);
    await assertFails(updateDoc(ref,{...noshow,noshowAt:0}));
    await assertSucceeds(updateDoc(ref,noshow));
    assert.equal((await getDoc(ref)).data().status,'noshow');
    assert.equal((await getDoc(doc(client('vendor'),'listings','vendor'))).data().stock,9);
    await assertFails(updateDoc(ref,ready));
    await assertFails(updateDoc(ref,{status:'collected',collectedAt:serverTimestamp()}));
  }
});
test('legacy reservations can be marked ready and code fields remain immutable after creation',async()=>{
  const rid=id();await seed('reservations/'+rid,{...order(rid,listing()),createdAt:new Date()});
  const ref=doc(client('vendor'),'reservations',rid);
  await assertSucceeds(updateDoc(ref,ready));
  await assertFails(updateDoc(ref,{pickupCode:'1234'}));
  await assertFails(updateDoc(ref,{slotStart:Date.now(),slotEnd:Date.now()+900000}));
  await assertSucceeds(updateDoc(ref,{status:'collected',collectedAt:serverTimestamp()}));
});
