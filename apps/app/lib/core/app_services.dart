import 'package:redream_app/core/api/api_client.dart';
import 'package:redream_app/core/storage/local_store.dart';
import 'package:redream_app/features/chat/chat_service.dart';
import 'package:redream_app/features/chat/voice_recorder.dart';
import 'package:redream_app/features/consent/consent_service.dart';
import 'package:redream_app/features/home/progress_service.dart';
import 'package:redream_app/features/journal/dream_service.dart';
import 'package:redream_app/features/reminders/notification_service.dart';
import 'package:redream_app/features/settings/account_service.dart';
import 'package:redream_app/features/settings/profile_service.dart';

/// Stateless services built once in `main` and shared through Provider.
class AppServices {
  AppServices({
    required this.api,
    required this.store,
    required this.notifications,
    this.voiceRecorder,
  }) : dreams = DreamService(api),
       chat = ChatService(api),
       consent = ApiConsentService(api),
       progress = ProgressService(api),
       profile = ProfileService(api),
       account = AccountService(api);

  final ApiClient api;
  final LocalStore store;
  final NotificationService notifications;
  final DreamService dreams;
  final ChatService chat;
  final ApiConsentService consent;

  /// Creates the composer's mic recorder; null hides voice input (tests).
  final IVoiceRecorder Function()? voiceRecorder;
  final ProgressService progress;
  final ProfileService profile;
  final AccountService account;
}
