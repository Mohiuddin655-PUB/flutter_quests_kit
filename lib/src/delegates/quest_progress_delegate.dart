import 'package:flutter/foundation.dart' show Listenable;

import '../models/quest_state.dart';

/// An account's quest progress on the server, given by the app: the days the server counted, the rewards claimed and
/// claiming one, the claims' version, and a place on the phone for their copy.
abstract interface class QuestProgressDelegate {
  /// [uid]'s days from [from] to [to] (`YYYY-MM-DD`), now and on each change, by day.
  Stream<Map<String, Map<String, Object?>>> days(String uid, String from, String to);

  /// Which of [ids] (claim ids) [uid] claimed; null when they couldn't be read.
  Future<Set<String>?> claimed(String uid, List<String> ids);

  /// Claims quest [questId]'s reward for [uid] on the server, which counts it again and pays it.
  Future<ClaimAnswer> claim(String uid, String questId);

  /// [uid]'s claims version now, raised by each claim; null before it is known.
  int? get claimsVersion;

  /// Told when [claimsVersion] changes.
  Listenable get claimsVersionChanges;

  /// What [uid]'s phone keeps under [name]; null when nothing.
  String? loadLocal(String uid, String name);

  /// Keeps [text] under [name] for [uid] on the phone.
  Future<void> saveLocal(String uid, String name, String text);

  /// The phone is online now.
  bool get online;

  /// Each time it goes on or off line.
  Stream<bool> get onlineChanges;
}
