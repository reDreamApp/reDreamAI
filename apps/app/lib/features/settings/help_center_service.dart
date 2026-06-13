import '../../core/api/api_client.dart';

abstract class IHelpCenterService {
  /// Submits a support concern (POST /api/v1/help-center/concerns).
  /// Throws [ApiException] on failure.
  Future<void> submitConcern(String message);
}

class ApiHelpCenterService implements IHelpCenterService {
  ApiHelpCenterService(this._api);

  final ApiClient _api;

  @override
  Future<void> submitConcern(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('message must not be empty');
    }
    await _api.post('/api/v1/help-center/concerns', {'message': trimmed});
  }
}
