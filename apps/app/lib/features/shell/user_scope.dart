import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:redream_app/core/app_services.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/consent/consent_state.dart';
import 'package:redream_app/features/home/progress_state.dart';
import 'package:redream_app/features/journal/dream_store.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/features/reminders/reminder_state.dart';
import 'package:redream_app/features/settings/profile_state.dart';
import 'package:redream_app/features/shell/shell_tabs.dart';

/// Per-user state. Keyed by user id in the auth gate so signing out disposes
/// everything and signing in starts fresh.
///
/// Screens pushed from inside (settings, dream details, practice) need these
/// providers too, so the scope owns a nested [Navigator]: every route lives
/// below the providers instead of beside them on the root navigator.
class UserScope extends StatefulWidget {
  const UserScope({required this.userId, required this.child, super.key});

  final String userId;

  /// Built once as the nested navigator's first route; it must watch the
  /// state it depends on itself rather than be swapped by the parent.
  final Widget child;

  @override
  State<UserScope> createState() => _UserScopeState();
}

class _UserScopeState extends State<UserScope> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ShellTabs()),
        ChangeNotifierProvider(create: (_) => ConsentState(services.consent)),
        ChangeNotifierProvider(
          create: (_) => ProgressState(services.progress),
        ),
        ChangeNotifierProvider(
          create: (ctx) => JournalState(
            services.dreams,
            DreamStore(services.store, widget.userId),
            onChanged: () => ctx.read<ProgressState>().refresh(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChatState(
            services.chat,
            voiceRecorder: services.voiceRecorder?.call(),
            onSessionDone: () {
              unawaited(ctx.read<JournalState>().refresh());
              unawaited(ctx.read<ProgressState>().refresh());
            },
          ),
        ),
        ChangeNotifierProvider(create: (_) => ProfileState(services.profile)),
        ChangeNotifierProvider(
          create: (_) => ReminderState(services.store, services.notifications),
        ),
      ],
      child: NavigatorPopHandler<Object?>(
        onPopWithResult: (_) => unawaited(_navigator.currentState?.maybePop()),
        child: Navigator(
          key: _navigator,
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => widget.child),
        ),
      ),
    );
  }
}
