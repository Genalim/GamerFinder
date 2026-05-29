import 'dart:convert';

class ProfileSetupManager {
  Set<String> selectedLanguages = {};

  // Приватний конструктор та єдиний екземпляр (Синглтон)
  ProfileSetupManager._internal();
  static final ProfileSetupManager instance = ProfileSetupManager._internal();

  // === ТАЙМЗОНА ===
  // Фіксуємо зміщення поясу користувача в годинах (наприклад, +3 для Києва)
  int timezoneOffset = DateTime.now().timeZoneOffset.inHours;

  // === 1-2 КРОК: ІГРИ ===
  List<dynamic> savedGamesList = [];
  Set<String> selectedGames = {};

  // === 3 КРОК: ПЛАТФОРМИ ===
  Set<String> selectedPlatforms = {};

  // === 4-5 КРОК: СТИЛІ ТА ЧАС ===
  Set<String> selectedPlayStyles = {};
  Set<String> selectedTimes = {};

  // === МЕТОД ДЛЯ КОНВЕРТАЦІЇ ЧАСУ В UTC ГОДИНИ ===
  List<int> get utcHours {
    Set<int> hours = {};
    final Map<String, List<int>> timeMap = {
      'Morning': [6, 7, 8, 9, 10, 11],
      'Afternoon': [12, 13, 14, 15, 16, 17],
      'Evening': [18, 19, 20, 21, 22],
      'Late night': [23, 0, 1, 2, 3, 4, 5],
    };

    for (var category in selectedTimes) {
      if (timeMap.containsKey(category)) {
        for (int localHour in timeMap[category]!) {
          // Формула: UTC = (LocalHour - Offset + 24) % 24
          int utcHour = (localHour - timezoneOffset + 24) % 24;
          hours.add(utcHour);
        }
      }
    }
    return hours.toList()..sort();
  }

  // === 6 Голосовий чат ===
  bool useVoiceChat = false;

  // === 7-8 КРОК: ФІНАЛЬНИЙ СЕТАП ПРОФІЛЮ ===
  String nickname = '';
  String email = '';
  String password = '';
  String? selectedAvatarPath;

  // === ДОДАТКОВІ ПОЛЯ ДЛЯ ТЕСТУВАННЯ ===
  bool isOnline = true;
  bool isPro = false;

  Map<String, String> connectedAccounts = {};

  // === МЕТОД ДЛЯ ФОРМУВАННЯ ДАНИХ (JSON) ===
  String toJson() {
    final Map<String, dynamic> data = {
      'nickname': nickname,
      'email': email,
      'password': password,
      'avatar': selectedAvatarPath,
      'games': selectedGames.toList(),
      'platforms': selectedPlatforms.toList(),
      'play_styles': selectedPlayStyles.toList(),
      // Тепер записуємо години UTC (як список чисел)
      'times': utcHours,
      // Додаємо часовий пояс для матчингу
      'timezone_offset': timezoneOffset,
      'voice_chat': useVoiceChat,
      'languages': selectedLanguages.toList(),
      'connected_accounts': connectedAccounts,
      'is_online': isOnline,
      'is_pro': isPro,
    };
    return jsonEncode(data);
  }

  // Метод для повного скидання даних
  void reset() {
    savedGamesList.clear();
    selectedGames.clear();
    selectedPlatforms.clear();
    selectedPlayStyles.clear();
    selectedTimes.clear();
    timezoneOffset = DateTime.now().timeZoneOffset.inHours; // Оновлюємо пояс при ресеті
    nickname = '';
    email = '';
    password = '';
    selectedAvatarPath = null;
    connectedAccounts.clear();
    isOnline = true;
    isPro = false;
  }
}