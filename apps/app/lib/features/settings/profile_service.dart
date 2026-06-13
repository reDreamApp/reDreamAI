import '../../core/api/api_client.dart';

/// Optional demographic profile fields, matching the backend's `ProfileOut`
/// (apps/api .../v1/profile/schemas.py). Values are stored as the canonical
/// English strings the legacy app used; the UI maps them to localized labels.
class UserProfile {
  const UserProfile({this.gender, this.ageRange, this.nightmareFrequency});

  final String? gender;
  final String? ageRange;
  final String? nightmareFrequency;

  static const empty = UserProfile();

  UserProfile copyWith({
    String? gender,
    String? ageRange,
    String? nightmareFrequency,
  }) {
    return UserProfile(
      gender: gender ?? this.gender,
      ageRange: ageRange ?? this.ageRange,
      nightmareFrequency: nightmareFrequency ?? this.nightmareFrequency,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: json['gender'] as String?,
      ageRange: json['age_range'] as String?,
      nightmareFrequency: json['nightmare_frequency'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (gender != null) 'gender': gender,
        if (ageRange != null) 'age_range': ageRange,
        if (nightmareFrequency != null)
          'nightmare_frequency': nightmareFrequency,
      };
}

/// Canonical option values (must match what the legacy app stored).
class ProfileOptions {
  static const genders = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];
  static const ageRanges = [
    'Under 18',
    '18-24',
    '25-34',
    '35-44',
    '45-54',
    '55-64',
    '65+',
  ];
  static const nightmareFrequencies = [
    'Almost every night',
    'A few times a week',
    'A few times a month',
    'Rarely',
    'Never',
  ];
}

abstract class IProfileService {
  Future<UserProfile> fetch();
  Future<UserProfile> save(UserProfile profile);
  Future<UserProfile> updateNightmareFrequency(String frequency);
}

/// Talks to GET/POST /api/v1/profile + PATCH /api/v1/profile/nightmare-frequency.
class ApiProfileService implements IProfileService {
  ApiProfileService(this._api);

  final ApiClient _api;

  @override
  Future<UserProfile> fetch() async {
    return UserProfile.fromJson(await _api.get('/api/v1/profile'));
  }

  @override
  Future<UserProfile> save(UserProfile profile) async {
    return UserProfile.fromJson(
      await _api.post('/api/v1/profile', profile.toJson()),
    );
  }

  @override
  Future<UserProfile> updateNightmareFrequency(String frequency) async {
    return UserProfile.fromJson(
      await _api.patch(
        '/api/v1/profile/nightmare-frequency',
        {'nightmare_frequency': frequency},
      ),
    );
  }
}
