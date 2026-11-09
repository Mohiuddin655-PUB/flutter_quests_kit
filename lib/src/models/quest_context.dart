import '../metrics/quest_metric.dart';
import 'quest.dart';
import 'quest_day.dart';

/// What a metric works a quest's progress out from: the [days] the server counted (this week's, and yesterday's),
/// [today] (`YYYY-MM-DD`), [all] the admin's quests, and the app's [metrics] by name.
class QuestContext {
  const QuestContext({required this.days, required this.today, required this.all, required this.metrics});

  final Map<String, QuestDay> days;
  final String today;
  final List<Quest> all;
  final Map<String, QuestMetric> metrics;

  /// Today's counts.
  QuestDay get day => days[today] ?? const QuestDay();
}
