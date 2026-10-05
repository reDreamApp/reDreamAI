import 'package:redream_app/l10n/generated/app_localizations.dart';

/// Localized label for a profile wire value (gender, age range, frequency).
String profileLabel(String wire, AppLocalizations l10n) => switch (wire) {
  'Male' => l10n.genderMale,
  'Female' => l10n.genderFemale,
  'Non-binary' => l10n.genderNonBinary,
  'Prefer not to say' => l10n.genderPreferNot,
  '65+' => l10n.age65Plus,
  'Almost every night' => l10n.freqNightly,
  'A few times a week' => l10n.freqWeekly,
  'A few times a month' => l10n.freqMonthly,
  'Rarely' => l10n.freqRarely,
  'Never' => l10n.freqNever,
  _ => wire,
};
