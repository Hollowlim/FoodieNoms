// Creates approved accounts for service_emulator_test.dart on local emulators only.
const project = 'demo-foodienoms';
const auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const firestore = `http://127.0.0.1:8080/v1/projects/${project}/databases/(default)/documents`;
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Use only the emulators.');
async function seed(email, name, role, approved) {
  const res = await fetch(`${auth}/accounts:signUp?key=demo`, {method: 'POST', headers: {'content-type': 'application/json'},
    body: JSON.stringify({email, password: 'emulator-only', returnSecureToken: true})});
  const {localId} = await res.json();
  const saved = await fetch(`${firestore}/users/${localId}`, {method: 'PATCH',
    headers: {'content-type': 'application/json', authorization: 'Bearer owner'},
    body: JSON.stringify({fields: {name: {stringValue: name}, role: {stringValue: role}, approved: {booleanValue: approved},
      createdAt: {timestampValue: new Date().toISOString()}}})});
  if (!saved.ok) throw new Error(await saved.text());
}
(async () => {
  await seed('vendor@example.test', 'Subang Cafe', 'vendor', true);
  await seed('student@example.test', 'Student', 'customer', false);
  await seed('admin@example.test', 'Owner Admin', 'admin', true);
})();

