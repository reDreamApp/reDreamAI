import 'package:redream_app/core/api/api_client.dart';
import 'package:redream_app/core/storage/local_store.dart';
import 'package:redream_app/features/chat/chat_service.dart';
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
  }) : dreams = DreamService(api),
       chat = ChatService(api),
       progress = ProgressService(api),
       profile = ProfileService(api),
       account = AccountService(api);

  final ApiClient api;
  final LocalStore store;
  final NotificationService notifications;
  final DreamService dreams;
  final ChatService chat;
  final ProgressService progress;
  final ProfileService profile;
  final AccountService account;
}
