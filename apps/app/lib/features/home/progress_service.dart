import 'package:redream_app/core/api/api_client.dart';
import 'package:redream_app/features/home/progress_models.dart';

class ProgressService {
  ProgressService(this._api);

  final ApiClient _api;

  Future<ProgressStats> stats() async =>
      ProgressStats.fromJson(await _api.get('/api/v1/progress/stats'));

  Future<void> setTodayMood(Mood mood) =>
      _api.post('/api/v1/progress/emotion', {'emotion': mood.wire});
}
