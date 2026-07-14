import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'consent_service.dart';

/// Consent status for the signed-in session. Provided inside the signed-in
/// subtree (recreated per sign-in), loaded once by the ConsentGate widget;
/// while `consentRequired != false` the gate blocks the app behind the
/// consent screen.
class ConsentState extends ChangeNotifier {
  ConsentState(this._service);

  final IConsentService _service;

  ConsentStatus? _status;
  bool _loading = false;
  bool _saving = false;
  String? _errorMessage;

  /// null = status not fetched yet (gate shows a spinner / error + retry).
  bool? get consentRequired => _status?.consentRequired;
  String? get requiredVersion => _status?.requiredVersion;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _status = await _service.status();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } on Exception catch (e) {
      _errorMessage = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Records the explicit grant for the version currently on screen.
  /// On a 409 (consent text changed under a stale screen) the status is
  /// refetched so the screen shows the current text.
  Future<void> grant() async {
    final version = _status?.requiredVersion;
    if (version == null || _saving) return;
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.grant(version);
      _status = ConsentStatus(
        requiredVersion: version,
        grantedVersion: version,
        consentRequired: false,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        await load();
      } else {
        _errorMessage = e.message;
      }
    } on Exception catch (e) {
      _errorMessage = e.toString();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Withdraws consent; the gate immediately re-blocks the app.
  /// Returns true on success (the settings dialog closes on it).
  Future<bool> withdraw() async {
    if (_saving) return false;
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.withdraw();
      final current = _status;
      _status = ConsentStatus(
        requiredVersion: current?.requiredVersion ?? '',
        grantedVersion: null,
        consentRequired: true,
      );
      // A withdrawal from settings needs the fresh required version for the
      // re-consent screen; refetch keeps it authoritative.
      await load();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } on Exception catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
