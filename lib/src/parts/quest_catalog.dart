import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../keys/quest_keys.dart';
import '../delegates/error_reporter.dart';
import '../delegates/quest_catalog_delegate.dart';
import '../models/quest.dart';

/// The admin's quests: the phone's copy at once, the server's read only when its version differs from the copy's, and
/// kept as the new copy. Listen to it to rebuild when the quests change.
class QuestCatalog extends ChangeNotifier {
  QuestCatalog(this._source, this._onError) {
    _load();
    _source.versionChanges.addListener(ask);
    ask();
  }

  final QuestCatalogDelegate _source;
  final ErrorReporter? _onError;

  List<Quest> _all = const [];

  /// The copy's version; null when it has none.
  int? _version;
  Future<void>? _reading;

  /// The quests in their order, those turned off included.
  List<Quest> get all => _all;

  /// The quests that count now.
  Iterable<Quest> get enabled => _all.where((q) => q.enabled);

  /// The enabled quests of [group].
  Iterable<Quest> inGroup(String group) => enabled.where((q) => q.group == group);

  /// Reads the server's quests when their version differs from the copy's; a second caller waits for the first.
  Future<void> refresh() {
    final version = _source.version;
    if (version == null || version == _version) return _reading ?? Future.value();
    return _reading ??= _read(version).whenComplete(() => _reading = null);
  }

  /// [refresh], without waiting for it.
  void ask() => unawaited(refresh());

  void _load() {
    try {
      final copy = jsonDecode(_source.loadLocal(QuestConfigKeys.name) ?? 'null');
      if (copy is! Map) return;
      final version = copy[QuestConfigKeys.version], quests = copy[QuestConfigKeys.quests];
      if (version is int && quests is Map) _set(version, {for (final e in quests.entries) '${e.key}': e.value});
    } catch (_) {
      // No copy: the server's are read.
    }
  }

  Future<void> _read(int version) async {
    final Map<String, Object?>? quests;
    try {
      quests = await _source.fetch();
    } catch (error, stack) {
      if (_source.online) _onError?.call(error, stack, 'quests config');
      return;
    }
    if (quests == null) return;
    _set(version, quests);
    final text = jsonEncode({QuestConfigKeys.version: version, QuestConfigKeys.quests: quests});
    // Not kept: shown now all the same, and read again on the next start.
    unawaited(_source.saveLocal(QuestConfigKeys.name, text).catchError((_) {}));
  }

  void _set(int version, Map<String, Object?> quests) {
    _version = version;
    _all = [for (final MapEntry(:key, :value) in quests.entries) ?Quest.fromConfig(key, value)]
      ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.id.compareTo(b.id));
    notifyListeners();
  }

  @override
  void dispose() {
    _source.versionChanges.removeListener(ask);
    super.dispose();
  }
}
