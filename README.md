# flutter_quests_kit

Daily, weekly and streak quests that pay an in-app currency, for Flutter. The admin's quests come from a remote config,
each account's progress from the day counts the server keeps, and its claims are read only when their version changes.
The server counts and pays; the kit only reads, works the progress out, and asks the server to pay.

Backend-agnostic: the app gives two delegates (Firestore, Realtime Database, REST, anything).

## How it reads

| What | Read | Kept on the phone |
| --- | --- | --- |
| The admin's quests | Once per version: the copy keeps its version, and a new one is read only when the server's differs | Yes (`quests_config`, through `saveLocal`) |
| The account's days | One listener on this week's days (and yesterday's) while signed in, started again on a new day | The backend's own cache |
| The claimed rewards | Once per claims version, only the ids the quests show now | Yes (`quest_claims`, through `saveLocal`) |

So with nothing new on the server, a start reads no quests and no claims: only the days' listener runs.

## Setup

```dart
QuestsKit.setup(
  catalogDelegate: MyQuestCatalog(),      // the admin's quests, their version, a place on the phone
  progressDelegate: MyQuestProgress(),    // days, claims, claiming, the phone's copy
  today: () => clock.today,               // 'YYYY-MM-DD', the person's day by the server's clock
  dayChanges: clock,                      // told when the day changes
  changes: [streak],                      // what else a metric reads
  metrics: {
    'chats': const CountMetric('chats'),
    'active': const AnyMetric(['chats', 'likes']),
    'dailyDone': const DoneMetric('daily'),
    'weekDailyDone': const WeekDoneMetric('daily'),
    'streak': StreakMetric(() => (count: streak.count, day: streak.day)),
  },
  onError: (error, stack, where) => crashlytics.recordError(error, stack, reason: where),
);

QuestsKit.start(uid);   // at sign-in
QuestsKit.clear();      // at sign-out
```

## Use

```dart
ListenableBuilder(
  listenable: Listenable.merge([QuestsKit.catalog, QuestsKit.progress]),
  builder: (context, _) {
    final p = QuestsKit.progress;
    return Column(children: [
      for (final q in QuestsKit.catalog.inGroup('daily'))
        QuestRow(
          title: q.titleIn(language) ?? myWords(q.metric),
          done: p.done(q),
          claimed: p.isClaimed(q),
          onClaim: p.claimable(q) ? () => p.claim(q) : null,
        ),
      Text('To claim: ${p.toClaim(QuestsKit.catalog.enabled)}'),
    ]);
  },
);
```

`claim` gives `(ClaimResult, balance?)`: `claimed`, `incomplete`, `offline` or `failed`; null for a second tap while one
is under way.

## The config

`{questId: {...}}`, ids of 1–20 lower-case letters and digits:

| Field | |
| --- | --- |
| `group` | Where it shows, in the app's words (`daily`, `bonus`…) |
| `metric` | A name in `metrics`; a quest whose metric isn't named is left out |
| `goal`, `reward` | Whole numbers from 1 to 100000 |
| `order` | Sorts the quests (then by id) |
| `enabled` | `false` turns it off |
| `title`, `description` | `{languageCode: text}` |

## Metrics

| Metric | Progress | Claimed once per |
| --- | --- | --- |
| `CountMetric(field)` | Today's `field` (a number, a list's length, `true` as one) | Day |
| `AnyMetric(fields)` | 1 when any of `fields` counted something today | Day |
| `DoneMetric(group)` | `group`'s day quests done today | Day |
| `WeekDoneMetric(group)` | `group`'s day quests done this week, from Monday | Week |
| `StreakMetric(streak)` | The app's day streak | Streak (under the day it began) |

A metric of the app's own extends `QuestMetric` (or `DayMetric` for one day's count). The claim key (`questId:day`,
`questId:weekStart` or `questId:streakStart`) becomes the claim's id with `/` and `:` made `_`
(`QuestDays.claimId`): the server writes the claim under the same id.

## The server

Only the server counts a day and pays a claim; the app only reads (the rules refuse its writes). A ready example for
Cloud Functions with the Admin SDK is in [`server/firebase_functions.ts`](server/firebase_functions.ts), and the rules
in [`rules/firestore.rules`](rules/firestore.rules):

- `countDay(uid, day, field, {by} | {person})`: from the triggers that see the account's activity, a day's field up by
  a number, or a person added once (a list, so meeting someone twice counts once).
- `claimQuest(uid, questId, today, streak)`: in one transaction, the quest read from the config, its progress worked
  out with the same metrics as the app's, refused when not done or claimed already; else the claim kept under its id
  (`questClaims/{claimId}`), the balance up with a credit in the ledger (as flutter_shop_kit keeps the wallet), and the
  account's claims version raised so every phone reads its claims again. `today` is the app's day, refused unless
  within a day of the server's.

Keep the server's metrics the same as the app's `QuestsKit.setup(metrics: …)`: a quest the two count differently shows
done on the phone and is refused as `incomplete`.
