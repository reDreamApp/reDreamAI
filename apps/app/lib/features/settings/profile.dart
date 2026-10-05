class Profile {
  const Profile({this.gender, this.ageRange, this.nightmareFrequency});

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    gender: json['gender'] as String?,
    ageRange: json['age_range'] as String?,
    nightmareFrequency: json['nightmare_frequency'] as String?,
  );

  static const empty = Profile();

  /// Wire values; labels are localized in the UI.
  static const genders = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];
  static const ageRanges = [
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

  final String? gender;
  final String? ageRange;
  final String? nightmareFrequency;

  bool get isEmpty =>
      gender == null && ageRange == null && nightmareFrequency == null;

  Map<String, dynamic> toJson() => {
    'gender': gender,
    'age_range': ageRange,
    'nightmare_frequency': nightmareFrequency,
  };
}
