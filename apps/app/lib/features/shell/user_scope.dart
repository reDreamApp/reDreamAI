import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:redream_app/core/app_services.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/home/progress_state.dart';
import 'package:redream_app/features/journal/dream_store.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/features/reminders/reminder_state.dart';
import 'package:redream_app/features/settings/profile_state.dart';

/// Per-user state. Keyed by user id in the auth gate so signing out disposes
/// everything and signing in starts fresh.
class UserScope extends StatelessWidget {
  const UserScope({required this.userId, required this.child, super.key});

  final String userId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final settings = context.read<AppSettings>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ProgressState(services.progress),
        ),
        ChangeNotifierProvider(
          create: (ctx) => JournalState(
            services.dreams,
            DreamStore(services.store, userId),
            onChanged: () => ctx.read<ProgressState>().refresh(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ChatState(services.chat, language: () => settings.language),
        ),
        ChangeNotifierProvider(create: (_) => ProfileState(services.profile)),
        ChangeNotifierProvider(
          create: (_) => ReminderState(services.store, services.notifications),
        ),
      ],
      child: child,
    );
  }
}
