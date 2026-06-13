import 'package:flutter/foundation.dart';

import 'progress_service.dart';
import 'progress_stats.dart';

/// Feature-local state for progress stats + the daily mood check-in.
///
/// Registered inside the home feature (not in main.dart): HomeScreen creates
/// one instance and exposes it to its subtree via Provider.
class ProgressState extends ChangeNotifier {
  ProgressState(this._service);

  final IProgressService _service;

  ProgressStats? _stats;
  bool _isLoading = false;
  bool _submittingMood = false;
  String? _error;
  bool _loadedOnce = false;

  /// Fallback so the check-in stays "done" even if the post-submit refresh
  /// fails (stats would otherwise still say today_mood == null).
  String? _submittedMoodFallback;

  ProgressStats? get stats => _stats;
  bool get isLoading => _isLoading;
  bool get submittingMood => _submittingMood;
  String? get error => _error;

  /// Today's mood (backend wire value), or null if not checked in yet.
  String? get todayMood => _stats?.todayMood ?? _submittedMoodFallback;

  bool get hasCheckedInToday => todayMood != null;

  /// Loads once; later calls are no-ops (use [refresh] to force).
  Future<void> preload() async {
    if (_loadedOnce || _isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _stats = await _service.getStats();
      _loadedOnce = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submits today's mood, then refreshes stats. Returns true on success.
  Future<bool> submitEmotion(String emotion) async {
    _submittingMood = true;
    notifyListeners();
    try {
      await _service.submitEmotion(emotion);
      _submittedMoodFallback = emotion;
      await refresh();
      return true;
    } catch (e) {
      debugPrint('ProgressState: failed to submit emotion: $e');
      return false;
    } finally {
      _submittingMood = false;
      notifyListeners();
    }
  }
}
