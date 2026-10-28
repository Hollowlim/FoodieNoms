const {test,before,after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc,getDocs,collection,query,where,runTransaction,writeBatch,serverTimestamp} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Use only the Firestore emulator.');
let env;
const client=uid=>env.authenticatedContext(uid).firestore();
const code=n=>'FN-'+n.toString(16).toUpperCase().padStart(20,'0');
const listing=(overrides={})=>({title:'Lunch box',description:'Rice and vegetables',address:'1 Test Street, Subang Jaya',
  dietary:'Contains soy',category:'Meals',priceCents:800,originalPriceCents:1500,stock:1,
  pickupStart:Date.now()+3600000,pickupEnd:Date.now()+7200000,vendorId:'vendor',vendorName:'Subang Cafe',
  active:true,createdAt:serverTimestamp(),...overrides});
const snapshotOrder=(uid,id,deal,quantity=1)=>({customerId:uid,vendorId:deal.vendorId,listingId:id,title:deal.title,
  vendorName:deal.vendorName,address:deal.address,pickupStart:deal.pickupStart,pickupEnd:deal.pickupEnd,quantity,
  unitPriceCents:deal.priceCents,totalCents:deal.priceCents*quantity,status:'reserved',paymentStatus:'unpaid',createdAt:serverTimestamp()});
async function reserve(uid,id,orderId) {
  const db=client(uid);
  return runTransaction(db,async tx=>{
    const orderRef=doc(db,'reservations',orderId), listingRef=doc(db,'listings',id);
    const previous=await tx.get(orderRef);
    if(previous.exists()) return previous.data();
    const snapshot=await tx.get(listingRef), deal=snapshot.data();
    if(deal.stock<1) throw new Error('Sold out');
    const data={...snapshotOrder(uid,id,deal),code:orderId};
    tx.set(orderRef,data);
    tx.update(listingRef,{stock:deal.stock-1,lastReservationId:orderId});
    return data;
  });
}
async function forge(id,orderId,patch={},listingPatch={}) {
  const db=client('customer'); const deal=(await getDoc(doc(db,'listings',id))).data();
  const batch=writeBatch(db);
  batch.set(doc(db,'reservations',orderId),{...snapshotOrder('customer',id,deal),code:orderId,...patch});
  batch.update(doc(db,'listings',id),{stock:deal.stock-1,lastReservationId:orderId,...listingPatch});
  return batch.commit();
}
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-foodienoms',firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync('../firestore.rules','utf8')}});
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async ctx=>{
   for(const [uid,role,approved,name] of [
    ['vendor','vendor',true,'Subang Cafe'],['other-vendor','vendor',true,'Other Cafe'],['pending','vendor',false,'Pending Cafe'],
    ['customer','customer',false,'Customer'],['other-customer','customer',false,'Other Customer'],['admin','admin',true,'Admin']]) {
     await setDoc(doc(ctx.firestore(),'users',uid),{name,role,approved,createdAt:serverTimestamp()});
   }
 });
});
after(async()=>{await env?.cleanup();});

test('only approved vendors publish validated listings',async()=>{
 await assertSucceeds(setDoc(doc(client('vendor'),'listings','last-item'),listing()));
 await assertFails(setDoc(doc(client('pending'),'listings','pending-food'),listing({vendorId:'pending',vendorName:'Pending Cafe'})));
 await assertFails(setDoc(doc(client('customer'),'listings','customer-food'),listing()));
 for(const [i,patch] of [{priceCents:-1},{priceCents:8.5},{stock:0},{stock:10001},{originalPriceCents:100},
    {vendorId:'other-vendor'},{vendorName:'Spoofed'},{pickupEnd:0},{address:''},{createdAt:0},{extra:'field'}].entries()) {
   await assertFails(setDoc(doc(client('vendor'),'listings','bad-'+i),listing(patch)));
 }
 await assertFails(updateDoc(doc(client('other-vendor'),'listings','last-item'),{active:false}));
 await assertFails(updateDoc(doc(client('vendor'),'listings','last-item'),{stock:100}));
 await assertFails(updateDoc(doc(client('vendor'),'listings','last-item'),{priceCents:1}));
});
test('concurrent customers cannot oversell; retries return the same order',async()=>{
 const result=await Promise.allSettled([reserve('customer','last-item',code(1)),reserve('other-customer','last-item',code(2))]);
 assert.equal(result.filter(r=>r.status==='fulfilled').length,1);
 const winner=result[0].status==='fulfilled'?'customer':'other-customer';
 const orderId=winner==='customer'?code(1):code(2);
 const current=await getDoc(doc(client('vendor'),'listings','last-item'));
 assert.equal(current.data().stock,0);
 await assertSucceeds(reserve(winner,'last-item',orderId));
 assert.equal((await getDocs(query(collection(client('vendor'),'reservations'),where('vendorId','==','vendor')))).size,1);
 await assertFails(updateDoc(doc(client(winner),'listings','last-item'),{stock:-1,lastReservationId:orderId}));
});
test('forged prices, inventory, ownership, timestamps and order snapshots are denied',async()=>{
 await setDoc(doc(client('vendor'),'listings','protected'),listing({stock:20}));
 await assertFails(updateDoc(doc(client('customer'),'listings','protected'),{stock:19,lastReservationId:code(10)}));
 const deal=(await getDoc(doc(client('customer'),'listings','protected'))).data();
 await assertFails(setDoc(doc(client('customer'),'reservations',code(11)),{...snapshotOrder('customer','protected',deal),code:code(11)}));
 for(const [i,patch] of [{totalCents:1},{unitPriceCents:1},{customerId:'other-customer'},
   {vendorId:'other-vendor'},{quantity:0},{quantity:1.5},{quantity:101},{status:'collected'},
   {paymentStatus:'paid'},{title:'Different food'},{pickupEnd:1},{createdAt:0},{extra:'forged'}].entries()) {
   await assertFails(forge('protected',code(20+i),patch));
 }
 await assertFails(forge('protected',code(40),{},{stock:20}));
 await assertFails(forge('protected',code(41),{},{priceCents:1}));
 assert.equal((await getDoc(doc(client('vendor'),'listings','protected'))).data().stock,20);
 // One stock decrease cannot fund two different reservations in one batch.
 const db=client('customer'), batch=writeBatch(db);
 for(const n of [42,43]) batch.set(doc(db,'reservations',code(n)),{...snapshotOrder('customer','protected',deal),code:code(n)});
 batch.update(doc(db,'listings','protected'),{stock:19,lastReservationId:code(43)});
 await assertFails(batch.commit());
});
test('private orders and pickup codes are visible only to their participants',async()=>{
 await reserve('customer','protected',code(50));
 await assertSucceeds(getDoc(doc(client('customer'),'reservations',code(50))));
 await assertSucceeds(getDoc(doc(client('vendor'),'reservations',code(50))));
 await assertFails(getDoc(doc(client('other-customer'),'reservations',code(50))));
 await assertFails(getDoc(doc(client('other-vendor'),'reservations',code(50))));
 await assertFails(getDocs(collection(client('customer'),'reservations')));
 await assertSucceeds(getDocs(query(collection(client('customer'),'reservations'),where('customerId','==','customer'))));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'listings','protected')));
});
test('only owning approved vendors collect once without changing price or customer',async()=>{
 const orderRef=db=>doc(db,'reservations',code(50));
 const fields={status:'collected',collectedAt:serverTimestamp()};
 for(const uid of ['customer','other-vendor','pending']) await assertFails(updateDoc(orderRef(client(uid)),fields));
 await assertFails(updateDoc(orderRef(client('vendor')),{...fields,totalCents:0}));
 await assertFails(updateDoc(orderRef(client('vendor')),{...fields,customerId:'other-customer'}));
 await assertFails(updateDoc(orderRef(client('vendor')),{...fields,collectedAt:0}));
 await assertSucceeds(updateDoc(orderRef(client('vendor')),fields));
 await assertFails(updateDoc(orderRef(client('vendor')),fields));
 await assertFails(updateDoc(orderRef(client('customer')),{paymentStatus:'paid'}));
});
test('paused, expired and unapproved vendor food cannot be reserved',async()=>{
 await setDoc(doc(client('vendor'),'listings','paused'),listing());
 await updateDoc(doc(client('vendor'),'listings','paused'),{active:false});
 await assertFails(getDoc(doc(client('customer'),'listings','paused')));
 await assertFails(reserve('customer','paused',code(60)));
 await assertSucceeds(getDocs(query(collection(client('vendor'),'listings'),where('vendorId','==','vendor'))));
 await env.withSecurityRulesDisabled(async ctx=>{
   await setDoc(doc(ctx.firestore(),'listings','expired'),listing({pickupEnd:Date.now()-1}));
   await setDoc(doc(ctx.firestore(),'listings','unapproved'),listing({vendorId:'pending',vendorName:'Pending Cafe'}));
 });
 await assertFails(reserve('customer','expired',code(61)));
 await assertFails(reserve('customer','unapproved',code(62)));
});
