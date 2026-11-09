## 0.2.0

- **The kit keeps the quests' phone copy**: `QuestCatalogDelegate` now only reads the server (`fetch()`, no version)
  and gives a place on the phone (`loadLocal` / `saveLocal`, under `QuestConfigKeys.name`, `{version, quests}`) and
  `online`; `cached()` is gone. A failed read is reported (`onError`, `'quests config'`) and read again on the next ask.
  `QuestKeys.version` moves to `QuestConfigKeys.version`.
- `Quest.titleIn(language)` / `descriptionIn(language)`: the admin's words in a language, else in English (`fallback`),
  else null for the app's own.
- `QuestsKit.progress.claimable(quest)` (done, not claimed) and `toClaim(quests)` (their rewards added up).
- The server side: `server/firebase_functions.ts` (`countDay`, `claimQuest`, a callable) and `rules/firestore.rules`.

## 0.1.1

- Signed out (no day yet), a change of the quests or of what a metric reads no longer works the progress out from an
  empty day, which threw for `WeekDoneMetric`.

## 0.1.0

- First release: `QuestsKit.setup`, `start` and `clear`; `QuestsKit.catalog` (the admin's quests, read again only when
  their version changes) and `QuestsKit.progress` (each quest's progress from the server's day counts, its claim, and
  the claims read only when their version changes). The app names its metrics (`CountMetric`, `AnyMetric`,
  `DoneMetric`, `WeekDoneMetric`, `StreakMetric`, or its own) and gives a `QuestCatalogDelegate` and a
  `QuestProgressDelegate`.
