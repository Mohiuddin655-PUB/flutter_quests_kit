import 'package:flutter/foundation.dart' show Listenable, visibleForTesting;

import 'delegates/error_reporter.dart';
import 'delegates/quest_catalog_delegate.dart';
import 'delegates/quest_progress_delegate.dart';
import 'metrics/quest_metric.dart';
import 'parts/quest_catalog.dart';
import 'parts/quest_progress.dart';

/// Quests that reward an in-app currency: the admin's [catalog] of quests, and the signed-in account's [progress] in
/// them (counted by the server, by day) and its claims. Set up once as the app starts ([setup]), then [start] at
/// sign-in and [clear] at sign-out. The server counts and pays; the kit only reads, and asks it to pay.
abstract final class QuestsKit {
  static ({QuestCatalog catalog, QuestProgress progress})? _parts;

  static ({QuestCatalog catalog, QuestProgress progress}) get _p => _parts ?? (throw StateError('QuestsKit.setup must be called first.'));

  /// Sets the kit up with what the app gives it, once, as the app starts (after Flutter's binding is ready). [metrics]
  /// names what each quest counts, by the name the admin's config uses (a quest whose metric isn't named is left
  /// out); [today] gives the person's day (`YYYY-MM-DD`, by the server's clock), told by [dayChanges] when it changes.
  /// [changes] are what else a metric reads (say, the app's streak): each change works the progress out again.
  static void setup({
    required QuestCatalogDelegate catalogDelegate,
    required QuestProgressDelegate progressDelegate,
    required Map<String, QuestMetric> metrics,
    required String Function() today,
    Listenable? dayChanges,
    List<Listenable> changes = const [],
    ErrorReporter? onError,
  }) {
    if (_parts != null) throw StateError('QuestsKit.setup was called already.');
    final catalog = QuestCatalog(catalogDelegate, onError);
    _parts = (catalog: catalog, progress: QuestProgress(catalog, progressDelegate, metrics, today, dayChanges, changes, onError));
  }

  static QuestCatalog get catalog => _p.catalog;
  static QuestProgress get progress => _p.progress;

  /// [uid] is signed in (a login, or a launch still signed in).
  static void start(String uid) => _p.progress.start(uid);

  /// Signed out: nothing of the account stays in memory.
  static Future<void> clear() => _p.progress.clear();

  /// Undoes [setup], so a test can set it up anew.
  @visibleForTesting
  static void reset() {
    _parts?.progress.dispose();
    _parts?.catalog.dispose();
    _parts = null;
  }
}
