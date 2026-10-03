import 'package:redream_app/core/auth/auth_service.dart';

class FakeAuth extends AuthService {
  FakeAuth({this.userId, this.email});

  @override
  String? userId;
  @override
  String? email;

  final signIns = <String>[];

  @override
  String? get accessToken => userId == null ? null : 'token-$userId';

  @override
  Future<void> signIn({required String email, required String password}) async {
    signIns.add(email);
    userId = 'user-1';
    this.email = email;
    notifyListeners();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    userId = 'user-new';
    this.email = email;
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    userId = null;
    email = null;
    notifyListeners();
  }

  @override
  Future<void> refreshSession() async {}

  @override
  Future<void> updateEmail(String email, {required String redirectUrl}) async {}

  @override
  Future<void> updatePassword(String password) async {}
}
