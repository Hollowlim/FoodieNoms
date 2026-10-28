'use strict';
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {randomBytes} = require('node:crypto');
const {InputError, text, identifier, listingInput, canReserve} = require('./domain');
initializeApp();
const db = getFirestore();
const options = {region: 'asia-southeast1', maxInstances: 10};
const callable = (handler) => onCall(options, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  try { return await handler(request.auth.uid, request.data || {}); }
  catch (error) {
    if (error instanceof InputError) throw new HttpsError('invalid-argument', error.message);
    if (error instanceof HttpsError) throw error;
    console.error(error);
    throw new HttpsError('internal', 'Unable to complete the request. Please try again.');
  }
});
function requireRole(profile, role, approved = false) {
  if (!profile || profile.role !== role || (approved && profile.approved !== true)) {
    throw new HttpsError('permission-denied', 'Your account does not have permission for this action.');
  }
}
exports.createProfile = callable(async (uid, data) => {
  const name = text(data.name, 'Name', 100);
  if (!['customer', 'vendor'].includes(data.role)) throw new InputError('Choose customer or vendor.');
  const ref = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return; // Safe retry; never replace an existing role.
    tx.create(ref, {name, role: data.role, approved: false, createdAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
});
exports.approveVendor = callable(async (uid, data) => {
  const vendorId = identifier(data.vendorId, 'Vendor ID');
  await db.runTransaction(async (tx) => {
    const [actor, vendor] = await Promise.all([
      tx.get(db.doc(`users/${uid}`)), tx.get(db.doc(`users/${vendorId}`))]);
    requireRole(actor.data(), 'admin');
    requireRole(vendor.data(), 'vendor');
    tx.update(vendor.ref, {approved: true, approvedBy: uid, approvedAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
});
exports.publishListing = callable(async (uid, data) => {
  const input = listingInput(data);
  const ref = db.collection('listings').doc();
  await db.runTransaction(async (tx) => {
    const vendor = await tx.get(db.doc(`users/${uid}`));
    requireRole(vendor.data(), 'vendor', true);
    tx.create(ref, {...input, vendorId: uid, vendorName: vendor.data().name,
      active: true, createdAt: FieldValue.serverTimestamp()});
  });
  return {id: ref.id};
});
exports.setListingActive = callable(async (uid, data) => {
  const id = identifier(data.listingId, 'Listing ID');
  if (typeof data.active !== 'boolean') throw new InputError('Invalid listing status.');
  await db.runTransaction(async (tx) => {
    const [profile, listing] = await Promise.all([
      tx.get(db.doc(`users/${uid}`)), tx.get(db.doc(`listings/${id}`))]);
    requireRole(profile.data(), 'vendor', true);
    if (!listing.exists || listing.data().vendorId !== uid) throw new HttpsError('permission-denied', 'This listing belongs to another vendor.');
    if (data.active && listing.data().pickupEnd <= Date.now()) throw new InputError('This pickup window has ended.');
    tx.update(listing.ref, {active: data.active});
  });
  return {ok: true};
});
exports.reserveListing = callable(async (uid, data) => {
  const listingId = identifier(data.listingId, 'Listing ID');
  // The client keeps this key on retry, preventing duplicate reservations after
  // a successful write whose response was lost.
  const requestId = text(data.requestId, 'Request ID', 64);
  if (!/^[a-zA-Z0-9-]{16,64}$/.test(requestId)) throw new InputError('Invalid request ID.');
  const orderRef = db.doc(`reservations/${uid}_${requestId}`);
  const code = `FN-${randomBytes(8).toString('hex').toUpperCase()}`;
  return db.runTransaction(async (tx) => {
    const [customer, existing, listing] = await Promise.all([
      tx.get(db.doc(`users/${uid}`)), tx.get(orderRef), tx.get(db.doc(`listings/${listingId}`))]);
    requireRole(customer.data(), 'customer');
    if (existing.exists) {
      if (existing.data().listingId !== listingId || existing.data().quantity !== data.quantity) {
        throw new InputError('This request was already used for another reservation.');
      }
      return {id: existing.id, code: existing.data().code};
    }
    if (!listing.exists) throw new HttpsError('not-found', 'Listing not found.');
    const deal = listing.data();
    const vendor = await tx.get(db.doc(`users/${deal.vendorId}`));
    requireRole(vendor.data(), 'vendor', true);
    canReserve(deal, data.quantity);
    tx.update(listing.ref, {stock: deal.stock - data.quantity});
    tx.create(orderRef, {customerId: uid, vendorId: deal.vendorId, listingId,
      title: deal.title, vendorName: deal.vendorName, address: deal.address,
      pickupStart: deal.pickupStart, pickupEnd: deal.pickupEnd,
      quantity: data.quantity, unitPriceCents: deal.priceCents,
      totalCents: deal.priceCents * data.quantity, status: 'reserved', code,
      paymentStatus: 'unpaid', createdAt: FieldValue.serverTimestamp()});
    tx.create(db.doc(`pickupCodes/${code}`), {reservationId: orderRef.id});
    return {id: orderRef.id, code};
  });
});
exports.collectReservation = callable(async (uid, data) => {
  const code = text(data.code, 'Pickup code', 32).toUpperCase();
  if (!/^FN-[A-F0-9]{16}$/.test(code)) throw new InputError('Invalid pickup code.');
  await db.runTransaction(async (tx) => {
    const [vendor, lookup] = await Promise.all([
      tx.get(db.doc(`users/${uid}`)), tx.get(db.doc(`pickupCodes/${code}`))]);
    requireRole(vendor.data(), 'vendor', true);
    if (!lookup.exists) throw new HttpsError('not-found', 'Invalid pickup code.');
    const order = await tx.get(db.doc(`reservations/${lookup.data().reservationId}`));
    if (!order.exists || order.data().vendorId !== uid) throw new HttpsError('permission-denied', 'This reservation is not for your store.');
    if (order.data().status !== 'reserved') throw new HttpsError('failed-precondition', 'This pickup was already collected.');
    tx.update(order.ref, {status: 'collected', collectedAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
});
