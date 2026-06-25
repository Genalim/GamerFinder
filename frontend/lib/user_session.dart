import 'package:shared_preferences/shared_preferences.dart';
import 'Home_Feed_screen.dart'; // або де в тебе лежить модель GamerProfile

class AppState {
  static Set<int> shownIds = {};
}

class UserSession {
  // Синглтон
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  // Додаємо гетер instance, щоб можна було писати UserSession.instance
  static UserSession get instance => _instance;

  GamerProfile? currentUser;

  static String? _token;

  // Гетер для токена, який використовується в екземплярі (UserSession.instance.token)
  String? get token => _token;

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


  // Додайте цей метод:
  static Future<String?> getToken() async {
    // Якщо токен вже в пам'яті, повертаємо його
    return _token;
  }

  // І не забудьте метод для збереження токена після логіну
  static void setToken(String token) {
    _token = token;
  }


  //====== Invite send synchronization start ====////:
  static final Map<int, DateTime> sentInvites = {};

  // Метод для перевірки, чи пройшло 10 хвилин
  static bool canInvite(int gamerId) {
    if (!sentInvites.containsKey(gamerId)) return true;
    final lastInvite = sentInvites[gamerId]!;
    return DateTime.now().difference(lastInvite).inMinutes >= 10;
  }

  // Метод для фіксації успішного інвайту
  static void registerInvite(int gamerId) {
    sentInvites[gamerId] = DateTime.now();
  }
  //====== Invite send synchronization end ====////:

}