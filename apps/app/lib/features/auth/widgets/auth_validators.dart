import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Shared form validators for the auth + account screens
/// (ported from legacy models/auth_validation.dart, localized).
const int kMinPasswordLength = 6;

final RegExp _emailRegExp = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');

String? validateEmail(BuildContext context, String? value) {
  final l10n = AppLocalizations.of(context)!;
  final text = value?.trim() ?? '';
  if (text.isEmpty) return l10n.authEmailRequired;
  if (!_emailRegExp.hasMatch(text)) return l10n.authEmailInvalid;
  return null;
}

String? validatePassword(BuildContext context, String? value) {
  final l10n = AppLocalizations.of(context)!;
  if (value == null || value.isEmpty) return l10n.authPasswordRequired;
  if (value.length < kMinPasswordLength) {
    return l10n.authPasswordTooShort(kMinPasswordLength);
  }
  return null;
}

String? validateConfirmPassword(
  BuildContext context,
  String? value,
  TextEditingController passwordController,
) {
  final l10n = AppLocalizations.of(context)!;
  if (value == null || value.isEmpty) return l10n.authPasswordRequired;
  if (value != passwordController.text) return l10n.authPasswordMismatch;
  return null;
}
