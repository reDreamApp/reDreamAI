import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sign-in state the UI listens to. Implemented by [SupabaseAuthService] in
/// production and by fakes in tests.
abstract class AuthService extends ChangeNotifier {
  String? get accessToken;
  bool get isSignedIn;

  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
}

class SupabaseAuthService extends AuthService {
  SupabaseAuthService(this._client) {
    _sub = _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _sub;

  @override
  String? get accessToken => _client.auth.currentSession?.accessToken;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
