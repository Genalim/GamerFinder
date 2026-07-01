import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../api_service.dart';

class UserCacheService {
  // Singleton: гарантує, що у нас є лише один екземпляр сервісу
  static final UserCacheService _instance = UserCacheService._internal();
  factory UserCacheService() => _instance;
  UserCacheService._internal();

  // "Сховище" даних користувачів
  final Map<int, dynamic> _userCache = {};

  /// Отримати дані користувача
  /// Якщо дані вже є в кеші — повертає їх миттєво.
  /// Якщо немає — йде на сервер і зберігає в кеш.
  Future<dynamic> getUser(int userId) async {
    // 1. Перевіряємо, чи є в кеші
    if (_userCache.containsKey(userId)) {
      debugPrint("DEBUG: Повертаю дані юзера $userId з кешу");
      return _userCache[userId];
    }

    // 2. Якщо немає, йдемо в API
    try {
      debugPrint("DEBUG: Завантажую дані юзера $userId з API");
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _userCache[userId] = data; // Зберігаємо в кеш
        return data;
      }
    } catch (e) {
      debugPrint("Помилка при запиті юзера $userId: $e");
    }
    return null;
  }

  /// Метод для оновлення кешу (корисно після редагування свого профілю)
  void updateCache(int userId, dynamic userData) {
    _userCache[userId] = userData;
  }

  /// Очистити конкретного юзера (якщо, наприклад, він видалив аккаунт)
  void invalidate(int userId) {
    _userCache.remove(userId);
  }

  /// Повністю очистити кеш (наприклад, при логауті)
  void clearAll() {
    _userCache.clear();
  }
}