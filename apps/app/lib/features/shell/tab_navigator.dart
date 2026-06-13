import 'package:flutter/foundation.dart';

/// Bottom-nav tab indices. Keep in sync with MainScreen's pages list.
abstract final class AppTabs {
  static const int home = 0;
  static const int chat = 1;
  static const int collection = 2;
  static const int record = 3;
  static const int learn = 4;
}

/// Lets any feature switch the active bottom tab without holding a reference
/// to MainScreen (e.g. chat's "look at your new dream" card → collection).
class TabNavigator extends ChangeNotifier {
  int _index = AppTabs.home;

  int get index => _index;

  void goTo(int tab) {
    if (tab == _index) return;
    _index = tab;
    notifyListeners();
  }
}
