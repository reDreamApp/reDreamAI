import 'package:flutter/foundation.dart';

/// Bottom navigation tabs of the signed-in shell.
enum ShellTab { home, session, journal, learn }

class ShellTabs extends ChangeNotifier {
  ShellTab _current = ShellTab.home;
  ShellTab _previous = ShellTab.home;

  ShellTab get current => _current;

  void select(ShellTab tab) {
    if (tab == _current) return;
    _previous = _current;
    _current = tab;
    notifyListeners();
  }

  /// Returns to the tab the user came from; for a tab with a back arrow.
  void back() => select(_previous);
}
