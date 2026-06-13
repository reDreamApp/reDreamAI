import '../../core/api/api_client.dart';

/// GDPR data-management calls (ported from legacy
/// services/data_management_service.dart, now routed through [ApiClient]).
abstract class IAccountDataService {
  /// GET /api/v1/exports/data — full JSON dump of the user's data.
  Future<Map<String, dynamic>> exportData();

  /// DELETE /api/v1/users/me/data — purges the user's data, keeps the login.
  Future<void> deleteData();

  /// DELETE /api/v1/users/me — deletes the account row entirely.
  Future<void> deleteAccount();
}

class ApiAccountDataService implements IAccountDataService {
  ApiAccountDataService(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> exportData() => _api.get('/api/v1/exports/data');

  @override
  Future<void> deleteData() => _api.delete('/api/v1/users/me/data');

  @override
  Future<void> deleteAccount() => _api.delete('/api/v1/users/me');
}
