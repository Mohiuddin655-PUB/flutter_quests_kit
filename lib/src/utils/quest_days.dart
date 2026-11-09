/// Days as the server writes them: `YYYY-MM-DD`, in the person's own day (the app says which is today).
abstract final class QuestDays {
  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _key(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

  static DateTime _parse(String key) {
    final p = key.split('-').map(int.parse).toList();
    return DateTime.utc(p[0], p[1], p[2]);
  }

  /// [key] moved by [n] days.
  static String add(String key, int n) => _key(_parse(key).add(Duration(days: n)));

  /// Monday of [key]'s week.
  static String weekStart(String key) => add(key, -(_parse(key).weekday - 1));

  /// Days from [from] to [to].
  static int between(String from, String to) => _parse(to).difference(_parse(from)).inDays;

  /// [claimKey] as a document id, `/` and `:` made `_`, as the server writes it.
  static String claimId(String claimKey) => claimKey.replaceAll(RegExp('[/:]'), '_');
}
