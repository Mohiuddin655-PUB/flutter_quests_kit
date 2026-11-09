import '../../keys/quest_keys.dart';

/// A quest from the admin's config, read as the server reads it: [fromConfig] gives null for an entry the server
/// leaves out too.
class Quest {
  const Quest({
    required this.id,
    required this.group,
    required this.metric,
    required this.goal,
    required this.reward,
    this.enabled = true,
    this.order = 0,
    this.title = const {},
    this.description = const {},
  });

  static final _id = RegExp(r'^[a-z0-9]{1,20}$');

  /// The most a goal or a reward may be, as on the server.
  static const max = 100000;

  /// [raw] as quest [id]; null when its id, group, metric, goal or reward isn't right.
  static Quest? fromConfig(String id, Object? raw) {
    if (!_id.hasMatch(id) || raw is! Map) return null;
    // A whole number, as the server's `Number.isInteger` (10 and 10.0 alike).
    int? whole(Object? v) => v is num && v == v.roundToDouble() && v > 0 && v <= max ? v.toInt() : null;
    final group = raw[QuestKeys.group], metric = raw[QuestKeys.metric];
    final goal = whole(raw[QuestKeys.goal]), reward = whole(raw[QuestKeys.reward]);
    if (group is! String || group.isEmpty || metric is! String || metric.isEmpty || goal == null || reward == null) return null;
    final order = raw[QuestKeys.order];
    return Quest(
      id: id,
      group: group,
      metric: metric,
      goal: goal,
      reward: reward,
      enabled: raw[QuestKeys.enabled] != false,
      order: order is num ? order : 0,
      title: _texts(raw[QuestKeys.title]),
      description: _texts(raw[QuestKeys.description]),
    );
  }

  /// `{languageCode: text}`, only the non-empty ones.
  static Map<String, String> _texts(Object? v) => {
    if (v is Map)
      for (final MapEntry(:key, :value) in v.entries)
        if (key is String && value is String && value.trim().isNotEmpty) key: value,
  };

  final String id;

  /// Where it shows, in the app's own words (such as `daily`).
  final String group;

  /// What it counts: a name in `QuestsKit.setup`'s `metrics`.
  final String metric;
  final int goal;
  final int reward;
  final bool enabled;
  final num order;

  /// The admin's words, by language code; the app's own where one is missing.
  final Map<String, String> title;
  final Map<String, String> description;

  /// The admin's title in [language], else in [fallback]; null when it has neither (the app's own words then).
  String? titleIn(String language, {String fallback = 'en'}) => title[language] ?? title[fallback];

  /// The admin's description, the same way.
  String? descriptionIn(String language, {String fallback = 'en'}) => description[language] ?? description[fallback];
}
