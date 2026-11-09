import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_quests_kit/flutter_quests_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_delegates.dart';

Map<String, Object?> quest(String metric, int goal) => {QuestKeys.group: 'daily', QuestKeys.metric: metric, QuestKeys.goal: goal, QuestKeys.reward: 5};

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCatalog catalog;
  late FakeProgress progress;
  late ValueNotifier<String> day;

  setUp(() async {
    catalog = FakeCatalog()..server = {'chat1': quest('chats', 1)};
    progress = FakeProgress();
    day = ValueNotifier('2026-11-11');
    QuestsKit.setup(
      catalogDelegate: catalog,
      progressDelegate: progress,
      today: () => day.value,
      dayChanges: day,
      metrics: {'chats': const CountMetric('chats')},
    );
    catalog.version = 1;
    await QuestsKit.catalog.refresh();
  });

  tearDown(QuestsKit.reset);

  Quest chat1() => QuestsKit.catalog.all.single;

  test('a new day listens to the new week once; the same day listens no more', () async {
    QuestsKit.start('u1');
    expect(progress.daysListens, 1);
    day.value = '2026-11-11';
    QuestsKit.progress.refresh();
    await pumpEventQueue();
    expect(progress.daysListens, 1);
    day.value = '2026-11-12';
    expect(progress.daysListens, 2);
  });

  test('back from the background, the quests are asked for and a stopped listener starts again', () async {
    QuestsKit.start('u1');
    progress.daysOut.addError(StateError('stopped'));
    await pumpEventQueue();
    catalog.server = {...catalog.server, 'chat2': quest('chats', 2)};
    // The version moved while the app was away, its notice missed.
    catalog.silentVersion = 2;
    for (final s in [
      AppLifecycleState.resumed,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await pumpEventQueue();
    expect(progress.daysListens, 2);
    expect(QuestsKit.catalog.all, hasLength(2));
  });

  test('back online, the claims a read missed offline are read once', () async {
    QuestsKit.start('u1');
    progress
      ..isOnline = false
      ..claimsVersion = 1;
    progress.daysOut.add({});
    await pumpEventQueue();
    // Offline it was the cache: not kept as the version's.
    expect(progress.claimedReads, 1);
    progress
      ..isOnline = true
      ..serverClaims = {'chat1_2026-11-11'};
    progress.onlineOut.add(true);
    await pumpEventQueue();
    expect(progress.claimedReads, 2);
    expect(QuestsKit.progress.isClaimed(chat1()), isTrue);
    progress.onlineOut.add(true);
    await pumpEventQueue();
    expect(progress.claimedReads, 2);
  });

  test('signed out during a claims read, its answer is let go', () async {
    QuestsKit.start('u1');
    progress
      ..claimsGate = Completer<void>()
      ..serverClaims = {'chat1_2026-11-11'}
      ..claimsVersion = 1;
    progress.daysOut.add({});
    await pumpEventQueue();
    await QuestsKit.clear();
    QuestsKit.start('u2');
    progress.claimsGate!.complete();
    await pumpEventQueue();
    expect(QuestsKit.progress.isClaimed(chat1()), isFalse);
    expect(progress.local.keys.where((k) => k.startsWith('u1/')), isEmpty);
  });

  test('the phone keeps the newest 500 claims', () async {
    final old = [for (var i = 0; i < 600; i++) 'old$i'];
    progress.local['u1/${QuestClaimsKeys.name}'] = jsonEncode({QuestClaimsKeys.version: 1, QuestClaimsKeys.ids: old});
    progress.claimsVersion = 1;
    QuestsKit.start('u1');
    progress.daysOut.add({
      '2026-11-11': {'chats': 1},
    });
    await pumpEventQueue();
    await QuestsKit.progress.claim(chat1());
    final kept = (jsonDecode(progress.local['u1/${QuestClaimsKeys.name}']!) as Map)[QuestClaimsKeys.ids] as List;
    expect(kept, hasLength(500));
    expect(kept.last, 'chat1_2026-11-11');
    expect(kept.first, 'old101');
  });
}
