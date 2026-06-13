import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';
import 'profile_service.dart';
import 'widgets/settings_widgets.dart';

/// Localized label for a canonical stored profile value.
String localizedProfileValue(AppLocalizations l10n, String? value) {
  switch (value) {
    case null:
      return l10n.profileNotProvided;
    case 'Male':
      return l10n.profileGenderMale;
    case 'Female':
      return l10n.profileGenderFemale;
    case 'Non-binary':
      return l10n.profileGenderNonBinary;
    case 'Prefer not to say':
      return l10n.profileGenderPreferNot;
    case 'Under 18':
      return l10n.profileAgeUnder18;
    case 'Almost every night':
      return l10n.profileFreqAlmostEveryNight;
    case 'A few times a week':
      return l10n.profileFreqFewTimesWeek;
    case 'A few times a month':
      return l10n.profileFreqFewTimesMonth;
    case 'Rarely':
      return l10n.profileFreqRarely;
    case 'Never':
      return l10n.profileFreqNever;
    default:
      return value;
  }
}

/// View/edit the backend profile fields (gender, age range, nightmare
/// frequency) — GET/POST /api/v1/profile, PATCH .../nightmare-frequency.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final IProfileService _service;

  UserProfile _saved = UserProfile.empty;
  String? _gender;
  String? _ageRange;
  String? _frequency;

  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = ApiProfileService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _error = null;
    });
    try {
      final profile = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _saved = profile;
        _gender = profile.gender;
        _ageRange = profile.ageRange;
        _frequency = profile.nightmareFrequency;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  bool get _dirty =>
      _gender != _saved.gender ||
      _ageRange != _saved.ageRange ||
      _frequency != _saved.nightmareFrequency;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final onlyFrequencyChanged = _gender == _saved.gender &&
          _ageRange == _saved.ageRange &&
          _frequency != _saved.nightmareFrequency &&
          _frequency != null;
      final UserProfile updated;
      if (onlyFrequencyChanged) {
        updated = await _service.updateNightmareFrequency(_frequency!);
      } else {
        updated = await _service.save(
          UserProfile(
            gender: _gender,
            ageRange: _ageRange,
            nightmareFrequency: _frequency,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _saved = updated;
        _gender = updated.gender;
        _ageRange = updated.ageRange;
        _frequency = updated.nightmareFrequency;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.profileSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? _buildLoadError(l10n)
              : _buildForm(l10n),
    );
  }

  Widget _buildLoadError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(l10n.profileLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: Text(l10n.profileRetry)),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.person_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.profileTitle,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _dropdown(
                label: l10n.profileGenderLabel,
                icon: Icons.person_outline,
                value: _gender,
                options: ProfileOptions.genders,
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 20),
              _dropdown(
                label: l10n.profileAgeRangeLabel,
                icon: Icons.cake_outlined,
                value: _ageRange,
                options: ProfileOptions.ageRanges,
                onChanged: (v) => setState(() => _ageRange = v),
              ),
              const SizedBox(height: 20),
              _dropdown(
                label: l10n.profileFrequencyLabel,
                icon: Icons.nights_stay_outlined,
                value: _frequency,
                options: ProfileOptions.nightmareFrequencies,
                onChanged: (v) => setState(() => _frequency = v),
              ),
              const SizedBox(height: 24),
              if (_error != null) SettingsErrorBanner(message: _error!),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _saving || !_dirty ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          l10n.profileSave,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(localizedProfileValue(l10n, option)),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
