/// One day's counts as the server keeps them, read leniently: a number counts as itself, a list by its length (say, the
/// people chatted with), `true` as one; anything else as nothing.
class QuestDay {
  const QuestDay([this.fields = const {}]);

  final Map<String, Object?> fields;

  /// What [field] counts.
  int count(String field) => switch (fields[field]) {
    final num n => n.toInt(),
    final List<Object?> l => l.length,
    true => 1,
    _ => 0,
  };
}
