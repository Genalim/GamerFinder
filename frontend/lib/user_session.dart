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
    _instance._sentInvites.clear(); // Очищаємо інвайти конкретної сесії
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
  final Map<String, DateTime> _sentInvites = {};

  // Метод перевірки (тепер екземплярний)
  bool canInvite(int gamerId) {
    final myId = currentUser?.id;
    if (myId == null) return true;

    // Ключ із ID юзера — це те, що вирішує проблему "бачу чужі інвайти"
    final key = "${myId}_$gamerId";

    if (!_sentInvites.containsKey(key)) return true;

    return DateTime.now().difference(_sentInvites[key]!).inMinutes >= 10;
  }

  // Метод реєстрації (тепер екземплярний)
  void registerInvite(int gamerId) {
    final myId = currentUser?.id;
    if (myId != null) {
      final key = "${myId}_$gamerId";
      _sentInvites[key] = DateTime.now();
    }
  }
//====== Invite send synchronization end ====////:

}

