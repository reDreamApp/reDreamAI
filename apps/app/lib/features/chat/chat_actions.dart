import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

/// Session entry points shared by the chat screen and the history drawer.
/// They supply the app language and the localized welcome bubble, which is
/// display-only and never sent to the backend.
extension ChatActions on BuildContext {
  String get _welcome => AppLocalizations.of(this)!.chatWelcome;
  String get _language => read<AppSettings>().language;

  /// First open: resume the latest unfinished chat, else start a new one.
  Future<void> resumeOrStartChat() => read<ChatState>().resumeOrStart(
    language: _language,
    welcomeMessage: _welcome,
  );

  Future<void> startNewChat() => read<ChatState>().startChat(
    language: _language,
    welcomeMessage: _welcome,
  );

  Future<bool> openChat(int id) =>
      read<ChatState>().loadChat(id, welcomeMessage: _welcome);

  Future<void> refreshChat() =>
      read<ChatState>().refreshCurrentChat(welcomeMessage: _welcome);
}
