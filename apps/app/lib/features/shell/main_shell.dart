import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/widgets/brand_logo.dart';
import 'package:redream_app/core/widgets/theme_mode_toggle.dart';
import 'package:redream_app/features/chat/chat_actions.dart';
import 'package:redream_app/features/chat/chat_history_drawer.dart';
import 'package:redream_app/features/chat/chat_screen.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/home/home_screen.dart';
import 'package:redream_app/features/home/progress_state.dart';
import 'package:redream_app/features/journal/journal_screen.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/features/settings/profile_state.dart';
import 'package:redream_app/features/settings/settings_screen.dart';
import 'package:redream_app/features/shell/shell_tabs.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

/// Signed-in root: app bar, three tabs, chat-history drawer on the session
/// tab. Preloads user data and re-syncs offline work when the app resumes.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final ShellTabs _tabs = context.read<ShellTabs>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<JournalState>().load());
      unawaited(context.read<ProgressState>().load());
      unawaited(context.read<ProfileState>().load());
      unawaited(context.read<ChatState>().loadChats());
    });
  }

  /// A chat session is only resumed or started once the user opens the
  /// session tab, so app launches don't create empty chats.
  void _onTabChanged() {
    if (_tabs.current != ShellTab.session || !mounted) return;
    final chat = context.read<ChatState>();
    if (chat.chatId == null && !chat.loadingChat && !chat.sending) {
      unawaited(context.resumeOrStartChat());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final journal = context.read<JournalState>();
    if (journal.hasUnsynced) unawaited(journal.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return const _ShellScaffold();
  }
}

class _ShellScaffold extends StatefulWidget {
  const _ShellScaffold();

  @override
  State<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<_ShellScaffold> {
  final _scaffold = GlobalKey<ScaffoldState>();
  bool _drawerOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = context.watch<ShellTabs>();
    final onSession = tabs.current == ShellTab.session;

    // An open drawer does not register with the system back gesture on its
    // own, so Android's Back would leave the app instead of closing it.
    return PopScope<Object?>(
      canPop: !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _scaffold.currentState?.closeDrawer();
      },
      child: Scaffold(
        key: _scaffold,
        onDrawerChanged: (open) => setState(() => _drawerOpen = open),
        appBar: AppBar(
          leading: onSession
              ? Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: l10n.chatHistoryTooltip,
                    onPressed: Scaffold.of(ctx).openDrawer,
                  ),
                )
              : null,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(height: 34),
              const SizedBox(width: 10),
              Flexible(
                child: Text(l10n.appTitle, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          actions: [
            const ThemeModeToggle(),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settingsTooltip,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        drawer: onSession ? const ChatHistoryDrawer() : null,
        body: IndexedStack(
          index: tabs.current.index,
          children: const [HomeScreen(), ChatScreen(), JournalScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tabs.current.index,
          onDestinationSelected: (i) => tabs.select(ShellTab.values[i]),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              selectedIcon: const Icon(Icons.chat_bubble),
              label: l10n.navSession,
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: l10n.navJournal,
            ),
          ],
        ),
      ),
    );
  }
}
