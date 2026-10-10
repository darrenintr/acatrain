import { before, beforeEach, after, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, deleteDoc, writeBatch, getDocs, collection } from 'firebase/firestore';
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-acatrain', firestore: {
    host: '127.0.0.1', port: 8081, rules: await readFile(new URL('../../firebase/firestore.rules', import.meta.url), 'utf8')
  } });
});
beforeEach(() => env.clearFirestore());
after(() => env?.cleanup());
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const progress = (client, uid = 'alice') => doc(client, `users/${uid}/state/progress`);
const deletion = (client, uid = 'alice') => doc(client, `users/${uid}/state/deletion`);
test('normal owner sync works; guests and other accounts cannot read, write, delete or list', async () => {
  const alice = db('alice');
  await assertSucceeds(setDoc(progress(alice), { payload: '{}' }));
  await assertSucceeds(getDoc(progress(alice)));
  for (const attacker of [db(), db('bob')]) {
    await assertFails(getDoc(progress(attacker)));
    await assertFails(setDoc(progress(attacker), { payload: '{}' }));
    await assertFails(deleteDoc(progress(attacker)));
    await assertFails(getDocs(collection(attacker, 'users/alice/state')));
    await assertFails(setDoc(deletion(attacker), { deleted: true }));
  }
});
test('create and update both enforce payload type, size and allowed fields', async () => {
  const alice = db('alice');
  for (const value of [{}, { payload: 1 }, { payload: '{}', admin: true }, { payload: 'x'.repeat(131073) }]) {
    await assertFails(setDoc(progress(alice), value));
  }
  await assertSucceeds(setDoc(progress(alice), { payload: '{}' }));
  for (const value of [{}, { payload: 1 }, { payload: '{}', admin: true }, { payload: 'x'.repeat(131073) }]) {
    await assertFails(setDoc(progress(alice), value));
  }
});
test('atomic deletion blocks old sessions from recreating progress and allows retry', async () => {
  const alice = db('alice'), otherSession = db('alice'), bob = db('bob');
  await setDoc(progress(alice), { payload: '{"old":true}' });
  await assertFails(setDoc(deletion(alice), { deleted: true }));
  await setDoc(progress(bob, 'bob'), { payload: '{}' });
  const erase = () => { const batch = writeBatch(alice); batch.set(deletion(alice), { deleted: true }); batch.delete(progress(alice)); return batch.commit(); };
  await assertSucceeds(erase());
  await env.withSecurityRulesDisabled(async context => {
    const result = await getDoc(progress(context.firestore()));
    if (result.exists()) throw new Error('Progress was not removed atomically');
  });
  await assertSucceeds(erase());
  await assertFails(getDoc(progress(otherSession)));
  await assertFails(setDoc(progress(otherSession), { payload: '{}' }));
  await assertSucceeds(getDoc(progress(bob, 'bob')));
  await assertFails(deleteDoc(deletion(otherSession)));
  await assertFails(setDoc(deletion(otherSession), { deleted: false }));
  await assertFails(setDoc(deletion(otherSession), { deleted: true, extra: 'bypass' }));
  await assertSucceeds(setDoc(deletion(otherSession), { deleted: true }));
});
test('a batch cannot mark deletion and retain or recreate progress', async () => {
  const alice = db('alice');
  const batch = writeBatch(alice);
  batch.set(deletion(alice), { deleted: true });
  batch.set(progress(alice), { payload: '{}' });
  await assertFails(batch.commit());
  await assertSucceeds(setDoc(progress(alice), { payload: '{}' }));
});
test('deletion markers reject missing fields and type changes; internal content is private', async () => {
  const alice = db('alice');
  for (const value of [{}, { deleted: false }, { deleted: 'true' }, { deleted: true, uid: 'bob' }]) {
    await assertFails(setDoc(deletion(alice), value));
  }
  await assertFails(setDoc(doc(alice, 'config/active'), { payload: '{}' }));
  await assertFails(getDoc(doc(alice, 'config/active')));
});
