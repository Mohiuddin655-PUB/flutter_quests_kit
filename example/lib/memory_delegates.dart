import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_quests_kit/flutter_quests_kit.dart';

/// The admin's quests, as a server would keep them.
class MemoryCatalog implements QuestCatalogDelegate {
  final _changes = ValueNotifier<int?>(1);
  final _local = <String, String>{};

  static const quests = {
    'chat3': {QuestKeys.group: 'daily', QuestKeys.metric: 'chats', QuestKeys.goal: 3, QuestKeys.reward: 10, QuestKeys.order: 1},
    'like5': {QuestKeys.group: 'daily', QuestKeys.metric: 'likes', QuestKeys.goal: 5, QuestKeys.reward: 10, QuestKeys.order: 2},
    'alldaily': {QuestKeys.group: 'bonus', QuestKeys.metric: 'dailyDone', QuestKeys.goal: 2, QuestKeys.reward: 25, QuestKeys.order: 3},
  };

  @override
  Future<Map<String, Object?>?> fetch() async => quests;

  @override
  int? get version => _changes.value;

  @override
  Listenable get versionChanges => _changes;

  @override
  String? loadLocal(String name) => _local[name];

  @override
  Future<void> saveLocal(String name, String text) async => _local[name] = text;

  @override
  bool get online => true;
}

/// A server that counts a day and pays claims, in memory.
class MemoryProgress implements QuestProgressDelegate {
  MemoryProgress(this.today);

  final String Function() today;
  final _days = <String, Map<String, Object?>>{};
  final _out = StreamController<Map<String, Map<String, Object?>>>.broadcast();
  final _claims = <String>{};
  final _version = ValueNotifier<int?>(0);
  final _local = <String, String>{};
  int balance = 0;

  /// The server counted one more [field] today.
  void count(String field) {
    final day = _days.putIfAbsent(today(), () => {});
    day[field] = ((day[field] as int?) ?? 0) + 1;
    _out.add({..._days});
  }

  @override
  Stream<Map<String, Map<String, Object?>>> days(String uid, String from, String to) async* {
    yield {..._days};
    yield* _out.stream;
  }

  @override
  Future<Set<String>?> claimed(String uid, List<String> ids) async => _claims.intersection(ids.toSet());

  @override
  Future<ClaimAnswer> claim(String uid, String questId) async {
    final quest = Quest.fromConfig(questId, MemoryCatalog.quests[questId]);
    if (quest == null) return (ClaimResult.failed, null);
    final id = QuestDays.claimId('$questId:${today()}');
    if (_claims.contains(id)) return (ClaimResult.failed, null);
    _claims.add(id);
    balance += quest.reward;
    _version.value = (_version.value ?? 0) + 1;
    return (ClaimResult.claimed, balance);
  }

  @override
  int? get claimsVersion => _version.value;

  @override
  Listenable get claimsVersionChanges => _version;

  @override
  String? loadLocal(String uid, String name) => _local['$uid/$name'];

  @override
  Future<void> saveLocal(String uid, String name, String text) async => _local['$uid/$name'] = text;

  @override
  bool get online => true;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();
}
