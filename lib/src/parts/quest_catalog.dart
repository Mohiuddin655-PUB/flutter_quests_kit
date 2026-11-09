import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../../keys/quest_keys.dart';
import '../delegates/quest_catalog_delegate.dart';
import '../models/quest.dart';

/// The admin's quests: the phone's copy at once, the server's read only when its version differs from the copy's.
/// Listen to it to rebuild when the quests change.
class QuestCatalog extends ChangeNotifier {
  QuestCatalog(this._source) {
    _set(_source.cached());
    _source.versionChanges.addListener(ask);
    ask();
  }

  final QuestCatalogDelegate _source;

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

  Future<void> _read(int version) async {
    final config = await _source.fetch(version);
    if (config != null) _set(config);
  }

  void _set(Map<String, Object?>? config) {
    final version = config?[QuestKeys.version];
    _version = version is int ? version : null;
    _all = [for (final MapEntry(:key, :value) in (config ?? const {}).entries) ?Quest.fromConfig(key, value)]
      ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.id.compareTo(b.id));
    notifyListeners();
  }

  @override
  void dispose() {
    _source.versionChanges.removeListener(ask);
    super.dispose();
  }
}
