import 'package:flutter/foundation.dart' show Listenable;

/// Where the admin's quests come from, given by the app: their copy on the phone, the server's at a version, and that
/// version. Each copy is `{questId: {...}}` and keeps its version (`version`).
abstract interface class QuestCatalogDelegate {
  /// The copy on the phone; null when there is none.
  Map<String, Object?>? cached();

  /// The server's quests at [version], kept as the phone's copy with it; null when they couldn't be read.
  Future<Map<String, Object?>?> fetch(int version);

  /// The server's version now; null before it is known.
  int? get version;

  /// Told when [version] changes.
  Listenable get versionChanges;
}
