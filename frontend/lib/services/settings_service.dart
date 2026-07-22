import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _chatSoundKey = 'chat_sound_enabled';
  static const String _matchAlertsKey = 'match_alerts_enabled';

  // Отримати стан звуку чату (за замовчуванням true)
  static Future<bool> isChatSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chatSoundKey) ?? true;
  }

  // Змінити стан звуку чату
  static Future<void> setChatSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatSoundKey, value);
  }

  // Отримати стан десктопних/матч сповіщень (за замовчуванням true)
  static Future<bool> isMatchAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_matchAlertsKey) ?? true;
  }

  // Змінити стан сповіщень
  static Future<void> setMatchAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_matchAlertsKey, value);
  }
}