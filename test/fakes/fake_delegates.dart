import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_quests_kit/flutter_quests_kit.dart';

class FakeCatalog implements QuestCatalogDelegate {
  Map<String, Object?>? copy;
  Map<String, Object?> server = {};
  int fetches = 0;
  final changes = ChangeNotifier();
  int? _version;

  @override
  Map<String, Object?>? cached() => copy;

  @override
  Future<Map<String, Object?>?> fetch(int version) async {
    fetches++;
    return copy = {...server, QuestKeys.version: version};
  }

  @override
  int? get version => _version;

  set version(int? v) {
    _version = v;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    changes.notifyListeners();
  }

  /// The version moved without a notice (say, while the app was away).
  set silentVersion(int v) => _version = v;

  @override
  Listenable get versionChanges => changes;
}

class FakeProgress implements QuestProgressDelegate {
  final daysOut = StreamController<Map<String, Map<String, Object?>>>.broadcast();
  final onlineOut = StreamController<bool>.broadcast();
  final claimsChanges = ChangeNotifier();
  final Map<String, String> local = {};
  Set<String> serverClaims = {};
  int claimedReads = 0;
  int daysListens = 0;

  /// When set, a claims read waits for it.
  Completer<void>? claimsGate;
  ClaimAnswer answer = (ClaimResult.claimed, 10);
  bool isOnline = true;
  int? _claimsVersion;

  @override
  Stream<Map<String, Map<String, Object?>>> days(String uid, String from, String to) {
    daysListens++;
    return daysOut.stream;
  }

  @override
  Future<Set<String>?> claimed(String uid, List<String> ids) async {
    claimedReads++;
    await claimsGate?.future;
    return serverClaims.intersection(ids.toSet());
  }

  @override
  Future<ClaimAnswer> claim(String uid, String questId) async => answer;

  @override
  int? get claimsVersion => _claimsVersion;

  set claimsVersion(int? v) {
    _claimsVersion = v;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    claimsChanges.notifyListeners();
  }

  @override
  Listenable get claimsVersionChanges => claimsChanges;

  @override
  String? loadLocal(String uid, String name) => local['$uid/$name'];

  @override
  Future<void> saveLocal(String uid, String name, String text) async => local['$uid/$name'] = text;

  @override
  bool get online => isOnline;

  @override
  Stream<bool> get onlineChanges => onlineOut.stream;
}
