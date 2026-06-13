import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_toggle.dart';
import '../../l10n/generated/app_localizations.dart';
import '../chat/chat_drawer.dart';
import '../chat/chat_screen.dart';
import '../collection/collection_screen.dart';
import '../collection/collection_state.dart';
import '../home/home_screen.dart';
import '../learn/learn_screen.dart';
import '../record/record_screen.dart';
import '../settings/settings_drawer.dart';
import 'tab_navigator.dart';

/// 5-tab shell ported from legacy screens/main_screen.dart: Home, Chat,
/// Collection, Record, Learn. Settings live in the end-drawer; the chat tab
/// gets the chat-history drawer on the leading side.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DreamCollectionState>().preload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = context.watch<TabNavigator>();
    final isChatTab = tabs.index == AppTabs.chat;

    const pages = [
      HomeScreen(),
      ChatScreen(),
      CollectionScreen(),
      RecordScreen(),
      LearnScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('reDreamAI', style: TextStyle(fontSize: 26)),
        centerTitle: true,
        scrolledUnderElevation: 2,
        leading: isChatTab
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, size: 28),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        actions: [
          const ThemeToggleButton(),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings, size: 28),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      drawer: isChatTab ? const ChatHistoryDrawer() : null,
      endDrawer: const SettingsDrawer(),
      body: IndexedStack(index: tabs.index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabs.index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.onPrimaryContainer,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        selectedFontSize: 16,
        unselectedFontSize: 14,
        iconSize: 26,
        onTap: tabs.goTo,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            label: l10n.tabHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            label: l10n.tabChat,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_outlined),
            label: l10n.tabCollection,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.edit_note_outlined),
            label: l10n.tabRecord,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.school_outlined),
            label: l10n.tabLearn,
          ),
        ],
      ),
    );
  }
}
