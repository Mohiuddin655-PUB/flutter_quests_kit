/// A quest's fields in the admin's config (`{questId: {...}}`), and the [version] each copy of it keeps.
abstract final class QuestKeys {
  /// The config's version, kept in each copy of it.
  static const version = 'version';

  /// Where the quest shows (the app's own groups, such as `daily`).
  static const group = 'group';

  /// What it counts: a name in `QuestsKit.setup`'s `metrics`.
  static const metric = 'metric';
  static const goal = 'goal';

  /// The currency it pays.
  static const reward = 'reward';
  static const order = 'order';

  /// `false` turns it off; on when missing.
  static const enabled = 'enabled';

  /// `{languageCode: text}`, the admin's words.
  static const title = 'title';
  static const description = 'description';
}

/// The phone's copy of the claimed rewards: `{version, ids}`, kept under [name] by the progress delegate.
abstract final class QuestClaimsKeys {
  static const name = 'quest_claims';
  static const version = 'version';
  static const ids = 'ids';
}
