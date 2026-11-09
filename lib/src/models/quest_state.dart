import '../enums/claim_result.dart';

/// A quest's [progress] now, and the key its reward is claimed under ([claimKey], one per day, week or streak).
typedef QuestState = ({int progress, String claimKey});

/// A claim's answer: its result, and the balance after it when the server gave one.
typedef ClaimAnswer = (ClaimResult, int?);

/// A streak as the app keeps it: its [count] of days, and its [day] (`YYYY-MM-DD`, the last counted; null when none).
typedef StreakValue = ({int count, String? day});
