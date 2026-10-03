import 'package:redream_app/core/api/api_client.dart';
import 'package:redream_app/features/settings/profile.dart';

class ProfileService {
  ProfileService(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/profile';

  Future<Profile> fetch() async => Profile.fromJson(await _api.get(_base));

  Future<Profile> save(Profile profile) async =>
      Profile.fromJson(await _api.post(_base, profile.toJson()));

  Future<Profile> updateNightmareFrequency(String value) async =>
      Profile.fromJson(
        await _api.patch('$_base/nightmare-frequency', {
          'nightmare_frequency': value,
        }),
      );
}
