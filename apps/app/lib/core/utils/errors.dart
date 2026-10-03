import 'package:redream_app/core/api/api_exception.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// One user-facing sentence for any failure the services can throw.
String describeError(Object error, AppLocalizations l10n) => switch (error) {
  NetworkException() => l10n.errorOffline,
  ApiException(isRateLimited: true) => l10n.errorRateLimited,
  ApiException(:final message) when message.isNotEmpty => message,
  AuthException(:final message) =>
    _looksOffline(message) ? l10n.errorOffline : message,
  _ => l10n.errorUnknown,
};

bool isOffline(Object error) =>
    error is NetworkException ||
    (error is AuthException && _looksOffline(error.message));

bool _looksOffline(String message) {
  final m = message.toLowerCase();
  return m.contains('socketexception') ||
      m.contains('failed host lookup') ||
      m.contains('clientexception') ||
      m.contains('connection refused') ||
      m.contains('network error') ||
      m.contains('connection reset');
}
