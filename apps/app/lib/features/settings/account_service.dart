import 'package:redream_app/core/api/api_client.dart';

class PasswordResetResult {
  const PasswordResetResult({
    required this.accountExists,
    required this.emailSent,
  });

  final bool accountExists;
  final bool emailSent;
}

/// Account-level endpoints: password reset, export, deletion, help center.
class AccountService {
  AccountService(this._api);

  final ApiClient _api;

  Future<PasswordResetResult> requestPasswordReset(String email) async {
    final res = await _api.post('/api/v1/auth/password-reset', {
      'email': email.trim(),
    });
    return PasswordResetResult(
      accountExists: res['account_exists'] == true,
      emailSent: res['email_sent'] == true,
    );
  }

  Future<Map<String, dynamic>> exportData() => _api.get('/api/v1/exports/data');

  Future<void> deleteData() => _api.delete('/api/v1/users/me/data');

  Future<void> deleteAccount() => _api.delete('/api/v1/users/me');

  Future<void> submitConcern(String message, {String? email}) =>
      _api.post('/api/v1/help-center/concerns', {
        'message': message.trim(),
        'email': ?email,
      });
}
