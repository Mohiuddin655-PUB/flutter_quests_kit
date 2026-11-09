/// How claiming a quest's reward on the server went.
enum ClaimResult {
  /// Paid.
  claimed,

  /// The server counts it as not done (yet).
  incomplete,

  /// The server couldn't be reached.
  offline,

  /// Refused, or something went wrong.
  failed,
}
