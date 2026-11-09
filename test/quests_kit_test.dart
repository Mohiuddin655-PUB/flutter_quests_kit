import 'package:flutter/foundation.dart';
import 'package:flutter_quests_kit/flutter_quests_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_delegates.dart';

const today = '2026-11-11'; // a Wednesday

Map<String, Object?> quest(String group, String metric, int goal, {int reward = 5, int order = 0}) => {
  QuestKeys.group: group,
  QuestKeys.metric: metric,
  QuestKeys.goal: goal,
  QuestKeys.reward: reward,
  QuestKeys.order: order,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCatalog catalog;
  late FakeProgress progress;
  var streak = (count: 0, day: null as String?);

  void setUpKit() {
    QuestsKit.setup(
      catalogDelegate: catalog,
      progressDelegate: progress,
      today: () => today,
      metrics: {
        'chats': const CountMetric('chats'),
        'active': const AnyMetric(['chats', 'likes']),
        'dailyDone': const DoneMetric('daily'),
        'weekDailyDone': const WeekDoneMetric('daily'),
        'streak': StreakMetric(() => streak),
      },
    );
  }

  setUp(() {
    catalog = FakeCatalog()
      ..server = {
        'chat3': quest('daily', 'chats', 3, order: 1),
        'active': quest('daily', 'active', 1, order: 2),
        'done2': quest('bonus', 'dailyDone', 2),
        'week5': quest('bonus', 'weekDailyDone', 5),
        'streak7': quest('streak', 'streak', 7),
        'unknown': quest('daily', 'nothing', 1),
        'BAD': quest('daily', 'chats', 1),
      };
    progress = FakeProgress();
    streak = (count: 0, day: null);
    setUpKit();
  });

  tearDown(QuestsKit.reset);

  test('the catalog reads the server only when its version differs from the copy', () async {
    expect(QuestsKit.catalog.all, isEmpty);
    catalog.version = 1;
    await QuestsKit.catalog.refresh();
    expect(catalog.fetches, 1);
    expect(QuestsKit.catalog.all.map((q) => q.id), ['done2', 'streak7', 'unknown', 'week5', 'chat3', 'active']);
    expect(QuestsKit.catalog.inGroup('daily').map((q) => q.id), ['unknown', 'chat3', 'active']);
    await QuestsKit.catalog.refresh();
    expect(catalog.fetches, 1);

    // A new start with the phone's copy at the same version reads nothing.
    QuestsKit.reset();
    setUpKit();
    await QuestsKit.catalog.refresh();
    expect(catalog.fetches, 1);
    expect(QuestsKit.catalog.all, hasLength(6));
  });

  test('progress follows the server\'s days, by each quest\'s metric', () async {
    catalog.version = 1;
    await QuestsKit.catalog.refresh();
    QuestsKit.start('u1');
    progress.daysOut.add({
      '2026-11-09': {'chats': 3},
      '2026-11-10': {'chats': 1, 'likes': 2},
      today: {
        'chats': ['a', 'b', 'c', 'd'],
      },
    });
    await pumpEventQueue();
    Quest q(String id) => QuestsKit.catalog.all.firstWhere((q) => q.id == id);
    final p = QuestsKit.progress;
    expect(p.done(q('chat3')), 3);
    expect(p.isComplete(q('chat3')), isTrue);
    expect(p.done(q('active')), 1);
    expect(p.done(q('done2')), 2);
    // Monday 2 (chats, active), Tuesday 1 (active), today 2.
    expect(p.done(q('week5')), 5);
    expect(p.isComplete(q('unknown')), isFalse);
    expect(p.today('chats'), 4);
  });

  test('a streak quest is claimed under the day its streak began', () async {
    catalog.version = 1;
    await QuestsKit.catalog.refresh();
    streak = (count: 7, day: today);
    QuestsKit.start('u1');
    progress
      ..claimsVersion = 1
      ..serverClaims = {'streak7_2026-11-05'};
    progress.daysOut.add({});
    await pumpEventQueue();
    final q = QuestsKit.catalog.all.firstWhere((q) => q.id == 'streak7');
    expect(QuestsKit.progress.isComplete(q), isTrue);
    expect(QuestsKit.progress.isClaimed(q), isTrue);
  });

  test('claims are read once per version, and a claim marks it paid', () async {
    catalog.version = 1;
    await QuestsKit.catalog.refresh();
    QuestsKit.start('u1');
    progress.claimsVersion = 3;
    progress.daysOut.add({
      today: {'chats': 3},
    });
    await pumpEventQueue();
    expect(progress.claimedReads, 1);
    final q = QuestsKit.catalog.all.firstWhere((q) => q.id == 'chat3');
    expect(QuestsKit.progress.isClaimed(q), isFalse);
    expect(await QuestsKit.progress.claim(q), (ClaimResult.claimed, 10));
    expect(QuestsKit.progress.isClaimed(q), isTrue);

    // Signed in again: the phone's copy, at the same version, reads nothing.
    await QuestsKit.clear();
    QuestsKit.start('u1');
    progress.daysOut.add({
      today: {'chats': 3},
    });
    await pumpEventQueue();
    expect(progress.claimedReads, 1);
    expect(QuestsKit.progress.isClaimed(q), isTrue);
  });

  test('a claim that throws offline says offline', () async {
    QuestsKit.reset();
    final failing = _Throwing()..isOnline = false;
    QuestsKit.setup(catalogDelegate: catalog, progressDelegate: failing, today: () => today, metrics: {'chats': const CountMetric('chats')});
    catalog.version = 1;
    await QuestsKit.catalog.refresh();
    QuestsKit.start('u1');
    final q = QuestsKit.catalog.all.firstWhere((q) => q.id == 'chat3');
    expect(await QuestsKit.progress.claim(q), (ClaimResult.offline, null));
  });

  test('signed out, a change of the quests works nothing out (there is no day)', () async {
    // A listener's error is only reported, not thrown: catch the report.
    final errors = <FlutterErrorDetails>[];
    final before = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = before);
    catalog.version = 1;
    await QuestsKit.catalog.refresh();
    final q = QuestsKit.catalog.all.firstWhere((q) => q.id == 'week5');
    expect(QuestsKit.progress.done(q), 0);
    expect(QuestsKit.progress.isComplete(q), isFalse);
    expect(errors, isEmpty);
  });

  test('Quest.fromConfig leaves out what the server leaves out', () {
    expect(Quest.fromConfig('ok', quest('daily', 'chats', 3)), isNotNull);
    expect(Quest.fromConfig('Bad', quest('daily', 'chats', 3)), isNull);
    expect(Quest.fromConfig('ok', quest('daily', 'chats', 0)), isNull);
    expect(Quest.fromConfig('ok', {...quest('daily', 'chats', 3), QuestKeys.reward: 2.5}), isNull);
    expect(Quest.fromConfig('ok', {...quest('daily', 'chats', 3), QuestKeys.enabled: false})!.enabled, isFalse);
  });
}

class _Throwing extends FakeProgress {
  @override
  Future<ClaimAnswer> claim(String uid, String questId) => Future.error(StateError('no network'));
}
