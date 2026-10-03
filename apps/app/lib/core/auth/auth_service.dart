import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session state the UI listens to. Implemented by [SupabaseAuthService] in
/// production and by fakes in tests.
abstract class AuthService extends ChangeNotifier {
  String? get accessToken;
  String? get userId;
  String? get email;
  bool get isSignedIn => userId != null;

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();
  Future<void> refreshSession();
  Future<void> updateEmail(String email, {required String redirectUrl});
  Future<void> updatePassword(String password);
}

class SupabaseAuthService extends AuthService {
  SupabaseAuthService(this._client) {
    _sub = _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _sub;

  GoTrueClient get _auth => _client.auth;

  @override
  String? get accessToken => _auth.currentSession?.accessToken;

  @override
  String? get userId => _auth.currentUser?.id;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithPassword(email: email, password: password);

  @override
  Future<void> signUp({required String email, required String password}) =>
      _auth.signUp(email: email, password: password);

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> refreshSession() => _auth.refreshSession();

  @override
  Future<void> updateEmail(String email, {required String redirectUrl}) => _auth
      .updateUser(UserAttributes(email: email), emailRedirectTo: redirectUrl);

  @override
  Future<void> updatePassword(String password) =>
      _auth.updateUser(UserAttributes(password: password));

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
