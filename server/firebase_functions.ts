// flutter_quests_kit's server side, for Cloud Functions (or any Node server) with the Firebase Admin SDK: the only place
// a quest's day is counted and its reward paid. Call countDay from the triggers that see the account's activity (a chat
// started, a like sent, a rewarded video verified), and expose claimQuest as a callable. Paths match
// rules/firestore.rules and the wallet flutter_shop_kit keeps; change them with it (CHANGE).
import { getDatabase } from 'firebase-admin/database';
import { FieldValue, getFirestore, Transaction } from 'firebase-admin/firestore';

// CHANGE: where the admin's quests are (Realtime Database), and where each account's days, claims and wallet are.
const QUESTS = 'config/quests';
const account = (uid: string) => getFirestore().doc(`accounts/${uid}`);
const day = (uid: string, d: string) => getFirestore().doc(`accounts/${uid}/questDays/${d}`);
const claim = (uid: string, id: string) => getFirestore().doc(`accounts/${uid}/questClaims/${id}`);
const wallet = (uid: string) => getFirestore().doc(`accounts/${uid}/wallet/main`);
const entry = (uid: string, id: string) => getFirestore().doc(`accounts/${uid}/wallet/main/ledger/${id}`);

type Day = Record<string, unknown>;
type Quest = { group: string; metric: string; goal: number; reward: number; enabled?: boolean };
type Streak = { count: number; day: string | null };

/** What a field counts, as the app's QuestDay reads it: a number as itself, a list by its length, true as one. */
const count = (d: Day | undefined, field: string) => {
  const v = d?.[field];
  return typeof v === 'number' ? Math.trunc(v) : Array.isArray(v) ? v.length : v === true ? 1 : 0;
};

/** CHANGE: the same metrics as the app's QuestsKit.setup, by name. */
const DAY_METRICS: Record<string, (d: Day | undefined) => number> = {
  chats: (d) => count(d, 'chats'),
  likes: (d) => count(d, 'likes'),
  active: (d) => (['chats', 'likes'].some((f) => count(d, f) > 0) ? 1 : 0),
};
const DONE_GROUP = 'daily';

const pad = (n: number) => String(n).padStart(2, '0');
const key = (t: Date) => `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`;
const addDays = (d: string, n: number) => key(new Date(Date.parse(`${d}T00:00:00Z`) + n * 864e5));
const weekStart = (d: string) => addDays(d, -((new Date(`${d}T00:00:00Z`).getUTCDay() + 6) % 7));

/**
 * Counts [field] on [uid]'s day [d] (`YYYY-MM-DD`, the person's own day): by [by], or [person] once (a list of the
 * people met, so meeting someone twice counts once).
 */
export async function countDay(uid: string, d: string, field: string, change: { by: number } | { person: string }) {
  const value = 'by' in change ? FieldValue.increment(change.by) : FieldValue.arrayUnion(change.person);
  await day(uid, d).set({ [field]: value }, { merge: true });
}

/** The day quests of [all] done on [d]. */
const doneOn = (d: Day | undefined, all: Record<string, Quest>) =>
  Object.values(all).filter((q) => q.enabled !== false && q.group === DONE_GROUP && (DAY_METRICS[q.metric]?.(d) ?? -1) >= q.goal).length;

/** [q]'s progress and claim key, worked out as the app's metrics do. */
async function state(tx: Transaction, uid: string, id: string, q: Quest, today: string, all: Record<string, Quest>, streak: Streak) {
  const read = async (d: string) => (await tx.get(day(uid, d))).data();
  const daily = DAY_METRICS[q.metric];
  if (daily) return { progress: daily(await read(today)), key: `${id}:${today}` };
  if (q.metric === 'dailyDone') return { progress: doneOn(await read(today), all), key: `${id}:${today}` };
  if (q.metric === 'weekDailyDone') {
    const week = weekStart(today);
    let n = 0;
    for (let d = week; d <= today; d = addDays(d, 1)) n += doneOn(await read(d), all);
    return { progress: n, key: `${id}:${week}` };
  }
  if (q.metric === 'streak') {
    const start = streak.count > 0 && streak.day ? addDays(streak.day, 1 - streak.count) : today;
    return { progress: streak.count, key: `${id}:${start}` };
  }
  return null;
}

/**
 * Pays quest [id] to [uid] once it is done, once per its claim key, on [today] (the app's day; refused unless within a
 * day of the server's, as time zones go). [streak] is the app's streak as the server keeps it. In one transaction: the
 * claim kept (`questClaims/{claimId}`), the balance up, its credit in the ledger, and the account's claims version
 * raised so every phone reads its claims again.
 */
export async function claimQuest(uid: string, id: string, today: string, streak: Streak) {
  const now = key(new Date());
  if (!/^\d{4}-\d{2}-\d{2}$/.test(today) || (today !== now && today !== addDays(now, -1) && today !== addDays(now, 1))) {
    return { result: 'failed' as const, balance: null };
  }
  const all = ((await getDatabase().ref(QUESTS).get()).val() ?? {}) as Record<string, Quest>;
  const q = all[id];
  if (!q || q.enabled === false || !Number.isInteger(q.goal) || !Number.isInteger(q.reward)) return { result: 'failed' as const, balance: null };
  return getFirestore().runTransaction(async (tx) => {
    const s = await state(tx, uid, id, q, today, all, streak);
    if (!s || s.progress < q.goal) return { result: 'incomplete' as const, balance: null };
    const claimId = s.key.replace(/[/:]/g, '_');
    const [claimed, w] = await Promise.all([tx.get(claim(uid, claimId)), tx.get(wallet(uid))]);
    if (claimed.exists) return { result: 'failed' as const, balance: null };
    const balance = Number(w.get('points.amount') ?? 0) + q.reward;
    tx.create(claim(uid, claimId), { quest: id, reward: q.reward, at: FieldValue.serverTimestamp() });
    tx.set(wallet(uid), { points: { amount: FieldValue.increment(q.reward) } }, { merge: true });
    tx.set(entry(uid, `quest_${claimId}`), { kind: 'credit', reason: 'questReward', ref: claimId, amount: q.reward, at: FieldValue.serverTimestamp(), source: 'server' });
    tx.set(account(uid), { versions: { questClaims: FieldValue.increment(1) } }, { merge: true });
    return { result: 'claimed' as const, balance };
  });
}

// A callable for the app's QuestProgressDelegate.claim (firebase-functions v2):
//
//   export const claim = onCall(async (request) => {
//     if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
//     const { questId, today } = request.data;
//     return claimQuest(request.auth.uid, questId, today, await yourStreak(request.auth.uid));
//   });
