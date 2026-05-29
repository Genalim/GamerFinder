import 'Home_Feed_screen.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  GamerProfile? currentUser;
}