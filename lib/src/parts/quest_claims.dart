import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart' show VoidCallback;

import '../../keys/quest_keys.dart';
import '../delegates/error_reporter.dart';
import '../delegates/quest_progress_delegate.dart';

/// The signed-in account's claimed rewards: the phone's copy at once, read from the server only when the claims'
/// version differs from the copy's, one read at a time.
class QuestClaims {
  QuestClaims(this._delegate, this._changed, this._onError);

  /// Over a month of claims; an older one shows unclaimed, and the server refuses claiming it again.
  static const _max = 500;

  final QuestProgressDelegate _delegate;

  /// The claims changed.
  final VoidCallback _changed;
  final ErrorReporter? _onError;

  String _uid = '';
  Set<String> _ids = const {};

  /// The version [_ids] were read at; null when unknown.
  int? _version;

  /// The claim ids the quests show now; null until the days were heard, as a streak's id needs them.
  List<String>? _keys;

  Future<void>? _reading;
  bool _again = false;

  /// Each sign-in or sign-out: a read begun before it is let go.
  int _account = 0;

  bool contains(String id) => _ids.contains(id);

  void start(String uid) {
    _uid = uid;
    _account++;
    _keys = null;
    _ids = const {};
    _version = null;
    try {
      final copy = jsonDecode(_delegate.loadLocal(uid, QuestClaimsKeys.name) ?? 'null');
      final ids = copy is Map ? copy[QuestClaimsKeys.ids] : null, version = copy is Map ? copy[QuestClaimsKeys.version] : null;
      if (ids is List) _ids = {...ids.whereType<String>()};
      _version = version is int ? version : null;
    } catch (_) {
      // No copy: the server's are read.
    }
  }

  void clear() {
    _uid = '';
    _account++;
    _ids = const {};
    _version = null;
    _keys = null;
  }

  /// The claim ids the quests show changed.
  void keys(List<String> keys) {
    _keys = keys;
    check();
  }

  /// Reads the server's claims when their version differs from the copy's; one under way reads again after it.
  void check() {
    final version = _delegate.claimsVersion, keys = _keys;
    if (_uid.isEmpty || keys == null || version == null || version == _version) return;
    if (_reading != null) {
      _again = true;
      return;
    }
    _reading = _read(version, keys).whenComplete(() {
      _reading = null;
      if (!_again) return;
      _again = false;
      check();
    });
  }

  Future<void> _read(int version, List<String> keys) async {
    final account = _account, uid = _uid;
    Set<String>? found;
    try {
      found = await _delegate.claimed(uid, keys);
    } catch (error, stack) {
      if (_delegate.online) _onError?.call(error, stack, 'quest claims');
    }
    if (found == null || account != _account) return;
    _ids = {..._ids, ...found};
    // Offline it was the phone's cache: read again once back online.
    if (_delegate.online) {
      _version = version;
      _save();
    }
    _changed();
  }

  /// [id] was paid here.
  void paid(String id) {
    _ids = {..._ids, id};
    if (_version != null) _save();
    _changed();
  }

  void _save() {
    final kept = _ids.skip((_ids.length - _max).clamp(0, _ids.length)).toList();
    final text = jsonEncode({QuestClaimsKeys.version: _version, QuestClaimsKeys.ids: kept});
    unawaited(_delegate.saveLocal(_uid, QuestClaimsKeys.name, text).catchError((_) {}));
  }
}
