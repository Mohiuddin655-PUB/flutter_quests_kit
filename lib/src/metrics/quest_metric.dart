import '../models/quest.dart';
import '../models/quest_context.dart';
import '../models/quest_day.dart';
import '../models/quest_state.dart';
import '../utils/quest_days.dart';

/// What a quest counts, named in `QuestsKit.setup`'s `metrics` by the name the admin's config uses. The server counts
/// the same way, as it checks a claim; the app may give its own.
abstract class QuestMetric {
  const QuestMetric();

  QuestState of(Quest quest, QuestContext context);
}

/// A quest of one day, claimed once that day.
abstract class DayMetric extends QuestMetric {
  const DayMetric();

  /// What [day] counts.
  int count(QuestDay day);

  @override
  QuestState of(Quest quest, QuestContext context) => (progress: count(context.day), claimKey: '${quest.id}:${context.today}');
}

/// Today's [field].
class CountMetric extends DayMetric {
  const CountMetric(this.field);

  final String field;

  @override
  int count(QuestDay day) => day.count(field);
}

/// One when any of [fields] counted something today (say, being active).
class AnyMetric extends DayMetric {
  const AnyMetric(this.fields);

  final List<String> fields;

  @override
  int count(QuestDay day) => fields.any((f) => day.count(f) > 0) ? 1 : 0;
}

/// The day quests of [group] done on a day, each counted by its own metric.
mixin _DoneCount {
  String get group;

  int done(QuestDay day, QuestContext context) {
    return context.all.where((q) {
      final metric = context.metrics[q.metric];
      return q.enabled && q.group == group && metric is DayMetric && metric.count(day) >= q.goal;
    }).length;
  }
}

/// How many of [group]'s day quests were done today.
class DoneMetric extends QuestMetric with _DoneCount {
  const DoneMetric(this.group);

  @override
  final String group;

  @override
  QuestState of(Quest quest, QuestContext context) => (progress: done(context.day, context), claimKey: '${quest.id}:${context.today}');
}

/// How many of [group]'s day quests were done this week (from Monday), claimed once a week.
class WeekDoneMetric extends QuestMetric with _DoneCount {
  const WeekDoneMetric(this.group);

  @override
  final String group;

  @override
  QuestState of(Quest quest, QuestContext context) {
    final week = QuestDays.weekStart(context.today);
    var n = 0;
    context.days.forEach((k, v) {
      if (k.compareTo(week) >= 0 && k.compareTo(context.today) <= 0) n += done(v, context);
    });
    return (progress: n, claimKey: '${quest.id}:$week');
  }
}

/// The app's day streak as it stands now ([streak]), claimed once per streak, under the day it began.
class StreakMetric extends QuestMetric {
  const StreakMetric(this.streak);

  final StreakValue Function() streak;

  @override
  QuestState of(Quest quest, QuestContext context) {
    final s = streak(), last = s.day;
    final start = s.count > 0 && last != null ? QuestDays.add(last, 1 - s.count) : context.today;
    return (progress: s.count, claimKey: '${quest.id}:$start');
  }
}
