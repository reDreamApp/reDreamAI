import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class IAuthService implements Listenable {
  String? get accessToken;
  bool get isSignedIn;
  String? get userEmail;
  Stream<bool> get authChanges;

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> sendPasswordReset(String email);
  Future<void> updateEmail(String newEmail);
  Future<void> updatePassword(String newPassword);
  Future<void> signOut();
}

class SupabaseAuthService extends ChangeNotifier implements IAuthService {
  SupabaseAuthService(this._client) {
    _sub = _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final SupabaseClient _client;
  late final dynamic _sub;

  @override
  String? get accessToken => _client.auth.currentSession?.accessToken;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  String? get userEmail => _client.auth.currentUser?.email;

  @override
  Stream<bool> get authChanges =>
      _client.auth.onAuthStateChange.map((_) => isSignedIn);

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    await _client.auth.updateUser(UserAttributes(email: newEmail));
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
