import 'package:flutter/foundation.dart';

/// Bottom navigation tabs of the signed-in shell.
enum ShellTab { home, session, journal, learn }

class ShellTabs extends ChangeNotifier {
  ShellTab _current = ShellTab.home;

  ShellTab get current => _current;

  void select(ShellTab tab) {
    if (tab == _current) return;
    _current = tab;
    notifyListeners();
  }
}
