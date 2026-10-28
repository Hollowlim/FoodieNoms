// Run only in a trusted environment with Application Default Credentials.
// Usage: node scripts/grant-admin.js FIREBASE_PROJECT_ID EXISTING_AUTH_UID
const {initializeApp, applicationDefault} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const [projectId, uid] = process.argv.slice(2);
if (!projectId || !uid) throw new Error('Provide the project ID and existing Firebase Auth UID.');
initializeApp({projectId, credential: applicationDefault()});
(async () => {
  const user = await getAuth().getUser(uid);
  const ref = getFirestore().doc(`users/${uid}`);
  await getFirestore().runTransaction(async (tx) => {
    const profile = await tx.get(ref);
    if (profile.exists && profile.data().role === 'vendor') {
      throw new Error('Use a separate admin account rather than converting a vendor with listings.');
    }
    tx.set(ref, {name: user.displayName || user.email || 'Administrator', role: 'admin',
      approved: true, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
  console.log(`Admin role assigned to ${uid} in ${projectId}.`);
})().catch((error) => { console.error(error.message); process.exitCode = 1; });
