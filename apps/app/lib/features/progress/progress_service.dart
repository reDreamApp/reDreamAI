import '../../core/api/api_client.dart';
import 'progress_stats.dart';

/// Progress + daily-mood backend access (feature-local service).
abstract class IProgressService {
  Future<ProgressStats> getStats();

  /// Upserts today's mood. [emotion] must be one of the backend wire values
  /// ("Very Dissatisfied" … "Very Satisfied").
  Future<void> submitEmotion(String emotion);
}

class ProgressService implements IProgressService {
  ProgressService(this._api);

  final ApiClient _api;

  @override
  Future<ProgressStats> getStats() async {
    final json = await _api.get('/api/v1/progress/stats');
    return ProgressStats.fromJson(json);
  }

  @override
  Future<void> submitEmotion(String emotion) async {
    // Backend answers 204 No Content; ApiClient maps that to an empty map.
    await _api.post('/api/v1/progress/emotion', {'emotion': emotion});
  }
}
