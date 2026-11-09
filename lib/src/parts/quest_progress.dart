import 'dart:async' show StreamSubscription, scheduleMicrotask, unawaited;

import 'package:flutter/widgets.dart';

import '../delegates/error_reporter.dart';
import '../delegates/quest_progress_delegate.dart';
import '../enums/claim_result.dart';
import '../metrics/quest_metric.dart';
import '../models/quest.dart';
import '../models/quest_context.dart';
import '../models/quest_day.dart';
import '../models/quest_state.dart';
import '../utils/quest_days.dart';
import 'quest_catalog.dart';
import 'quest_claims.dart';

/// The signed-in account's quest progress, as the server counts it: one listener on this week's days (and yesterday's,
/// for a streak) while signed in, and the claimed rewards read only when their version changes. Listen to it to rebuild
/// when the progress or the claims change.
class QuestProgress extends ChangeNotifier {
  QuestProgress(this._catalog, this._delegate, this._metrics, this._today, this._dayChanges, this._changes, this._onError) {
    _claims = QuestClaims(_delegate, notifyListeners, _onError);
    _catalog.addListener(_changed);
    for (final c in _changes) {
      c.addListener(_changed);
    }
    _delegate.claimsVersionChanges.addListener(_claims.check);
    // A new day, or a new time zone: the days are listened to again.
    _dayChanges?.addListener(_newDay);
    // Back from the background: a listener the server stopped starts again; nothing else is read.
    _resume = AppLifecycleListener(
      onResume: () {
        _catalog.ask();
        _newDay();
      },
    );
    // Back online: the quests and the claims a read may have missed offline, once.
    _online = _delegate.onlineChanges.listen((online) {
      if (!online) return;
      _catalog.ask();
      _claims.check();
    });
  }

  final QuestCatalog _catalog;
  final QuestProgressDelegate _delegate;
  final Map<String, QuestMetric> _metrics;
  final String Function() _today;
  final Listenable? _dayChanges;
  final List<Listenable> _changes;
  final ErrorReporter? _onError;
  late final QuestClaims _claims;
  late final AppLifecycleListener _resume;
  late final StreamSubscription<bool> _online;

  String _uid = '';
  String _day = '';
  StreamSubscription<Map<String, Map<String, Object?>>>? _days;
  Map<String, QuestDay> _counted = const {};
  Map<String, QuestState> _states = const {};
  String _claimKeys = '';

  /// The days were heard since the listener started: before, a streak's claim id isn't known.
  bool _daysHeard = false;
  final Set<String> _claiming = {};

  /// [uid] is signed in.
  void start(String uid) {
    if (uid.isEmpty || uid == _uid) return;
    _uid = uid;
    _counted = const {};
    _claims.start(uid);
    _claimKeys = '';
    _listen();
  }

  /// Signed out.
  Future<void> clear() async {
    await _days?.cancel();
    _days = null;
    _claims.clear();
    _uid = '';
    _day = '';
    _counted = const {};
    _states = const {};
    _claimKeys = '';
    notifyListeners();
  }

  /// A page with quests opened: a new day starts listening to it. Just after the frame being built, as pages ask while
  /// they build.
  void refresh() => scheduleMicrotask(_newDay);

  /// Listens again when the day (or the time zone) has changed, or the server stopped the listener.
  void _newDay() {
    if (_uid.isEmpty || (_days != null && _today() == _day)) return;
    _listen();
  }

  void _listen() {
    _day = _today();
    final week = QuestDays.weekStart(_day), yesterday = QuestDays.add(_day, -1);
    final from = week.compareTo(yesterday) < 0 ? week : yesterday;
    unawaited(_days?.cancel());
    _daysHeard = false;
    _days = _delegate.days(_uid, from, _day).listen((days) {
      _daysHeard = true;
      _counted = {for (final MapEntry(:key, :value) in days.entries) key: QuestDay(value)};
      _changed();
    }, onError: _stopped);
    _changed();
  }

  /// The server ended the listener: it starts again on the next refresh or return to the app.
  void _stopped(Object error, StackTrace stack) {
    _days = null;
    if (_delegate.online) _onError?.call(error, stack, 'quest days');
  }

  void _changed() {
    final all = _catalog.all, context = QuestContext(days: _counted, today: _day, all: all, metrics: _metrics);
    _states = {
      for (final q in all)
        if (_metrics[q.metric] case final m?) q.id: m.of(q, context),
    };
    final keys = [for (final s in _states.values) QuestDays.claimId(s.claimKey)]..sort();
    final joined = keys.join(',');
    if (_uid.isNotEmpty && _daysHeard && joined != _claimKeys) {
      _claimKeys = joined;
      _claims.keys(keys);
    }
    notifyListeners();
  }

  /// The signed-in account, or empty.
  String get uid => _uid;

  /// What [field] counts today, as the server counted it.
  int today(String field) => (_counted[_day] ?? const QuestDay()).count(field);

  /// [q]'s progress, up to its goal; 0 for a metric the app doesn't name.
  int done(Quest q) => (_states[q.id]?.progress ?? 0).clamp(0, q.goal);

  bool isComplete(Quest q) => q.enabled && _states.containsKey(q.id) && done(q) >= q.goal;

  bool isClaimed(Quest q) {
    final s = _states[q.id];
    return s != null && _claims.contains(QuestDays.claimId(s.claimKey));
  }

  /// Claims [q]'s reward on the server, with the balance after it; null for a second tap while one is under way, or a
  /// quest whose metric the app doesn't name.
  Future<ClaimAnswer?> claim(Quest q) async {
    final s = _states[q.id];
    if (s == null || _uid.isEmpty || _claiming.contains(q.id)) return null;
    _claiming.add(q.id);
    ClaimAnswer answer;
    try {
      answer = await _delegate.claim(_uid, q.id);
    } catch (error, stack) {
      if (_delegate.online) _onError?.call(error, stack, 'quest claim');
      answer = (_delegate.online ? ClaimResult.failed : ClaimResult.offline, null);
    }
    _claiming.remove(q.id);
    if (answer.$1 == ClaimResult.claimed) _claims.paid(QuestDays.claimId(s.claimKey));
    return answer;
  }

  @override
  void dispose() {
    _catalog.removeListener(_changed);
    for (final c in _changes) {
      c.removeListener(_changed);
    }
    _dayChanges?.removeListener(_newDay);
    _delegate.claimsVersionChanges.removeListener(_claims.check);
    _resume.dispose();
    unawaited(_online.cancel());
    unawaited(_days?.cancel());
    super.dispose();
  }
}
