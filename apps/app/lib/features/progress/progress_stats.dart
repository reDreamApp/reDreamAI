/// Progress stats, matching the backend `ProgressStatsOut` schema
/// (GET /api/v1/progress/stats).
class ProgressStats {
  const ProgressStats({
    required this.rehearsalStreak,
    this.averageIntensity,
    this.averageMood,
    this.todayMood,
    required this.dreamsLogged,
    required this.nightmaresTreated,
  });

  /// Consecutive days (ending today) with at least one rehearsal practice.
  final int rehearsalStreak;

  /// Average intensity across the user's nightmares, or null if none rated.
  final double? averageIntensity;

  /// Average mood score (1–5) over the last 30 days, or null without check-ins.
  final double? averageMood;

  /// Today's mood check-in (backend wire value, e.g. "Neutral"), or null if
  /// the user hasn't checked in today.
  final String? todayMood;

  /// Total dreams in the collection.
  final int dreamsLogged;

  /// Nightmares that already have a rewritten version.
  final int nightmaresTreated;

  factory ProgressStats.fromJson(Map<String, dynamic> json) {
    return ProgressStats(
      rehearsalStreak: (json['rehearsal_streak'] as num?)?.toInt() ?? 0,
      averageIntensity: (json['average_intensity'] as num?)?.toDouble(),
      averageMood: (json['average_mood'] as num?)?.toDouble(),
      todayMood: json['today_mood'] as String?,
      dreamsLogged: (json['dreams_logged'] as num?)?.toInt() ?? 0,
      nightmaresTreated: (json['nightmares_treated'] as num?)?.toInt() ?? 0,
    );
  }
}
