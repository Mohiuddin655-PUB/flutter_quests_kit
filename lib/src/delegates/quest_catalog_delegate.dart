import 'package:flutter/foundation.dart' show Listenable;

/// Where the admin's quests come from, given by the app: the server's quests (`{questId: {...}}`), their version, and a
/// place on the phone for the kit's copy of them.
abstract interface class QuestCatalogDelegate {
  /// The server's quests now, as JSON values (the kit keeps them as JSON); null when they couldn't be read (or there are
  /// none). May throw: the kit reports it.
  Future<Map<String, Object?>?> fetch();

  /// The server's version now; null before it is known.
  int? get version;

  /// Told when [version] changes.
  Listenable get versionChanges;

  /// What the phone keeps under [name]; null when nothing.
  String? loadLocal(String name);

  /// Keeps [text] under [name] on the phone.
  Future<void> saveLocal(String name, String text);

  /// The phone is online now: an error while offline isn't reported.
  bool get online;
}
