/// Records an unexpected [error] (not being offline) with [where] it happened, given by the app (Crashlytics, say).
typedef ErrorReporter = void Function(Object error, StackTrace stack, String where);
