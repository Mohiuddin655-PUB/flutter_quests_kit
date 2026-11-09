## 0.1.0

- First release: `QuestsKit.setup`, `start` and `clear`; `QuestsKit.catalog` (the admin's quests, read again only when
  their version changes) and `QuestsKit.progress` (each quest's progress from the server's day counts, its claim, and
  the claims read only when their version changes). The app names its metrics (`CountMetric`, `AnyMetric`,
  `DoneMetric`, `WeekDoneMetric`, `StreakMetric`, or its own) and gives a `QuestCatalogDelegate` and a
  `QuestProgressDelegate`.
