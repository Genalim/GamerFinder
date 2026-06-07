import 'package:shared_preferences/shared_preferences.dart';
import 'Home_Feed_screen.dart'; // або де в тебе лежить модель GamerProfile

class UserSession {
  // Синглтон
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  GamerProfile? currentUser;

  // Метод збереження ID
  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
  }

  // Метод отримання ID (якщо потрібно буде при старті)
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  // Метод для очищення (при логауті)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    _instance.currentUser = null;
  }

  static String? _token;

  // Додайте цей метод:
  static Future<String?> getToken() async {
    // Якщо токен вже в пам'яті, повертаємо його
    return _token;
  }

  // І не забудьте метод для збереження токена після логіну
  static void setToken(String token) {
    _token = token;
  }
}