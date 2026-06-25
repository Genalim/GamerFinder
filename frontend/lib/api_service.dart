import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'user_session.dart';
import 'Home_Feed_screen.dart';
import 'notifications_overlay.dart';

class ApiService {
  // Базові заголовки з токеном
  static Future<Map<String, String>> getHeaders() async {
    final token = await UserSession.getToken(); // Припустимо, у вас є такий метод
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // Перевірка статусу дружби
  static Future<String> getFriendStatus(int friendId) async {
    final headers = await getHeaders();
    print("DEBUG: Заголовки запиту: $headers");

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/friends/status/$friendId'),
      headers: await getHeaders(),
    );
    print("DEBUG: Відповідь сервера: ${response.statusCode}, Body: ${response.body}");

    if (response.statusCode == 200) {
      return json.decode(response.body)['status']; // поверне "pending", "accepted", "none"
    }
    return "none";
  }

  // Надіслати запит
  static Future<bool> sendFriendRequest(int friendId) async {
    final headers = await getHeaders();

    // ВАЖЛИВО: Обов'язково додайте body, закодований у JSON
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/friends/request'),
      headers: headers,
      body: json.encode({"friend_id": friendId}), // <--- Ось це тіло!
    );

    print("DEBUG: Статус відповіді на запит: ${response.statusCode}");
    print("DEBUG: Тіло відповіді: ${response.body}");

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> acceptFriendRequest(int friendshipId) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/friends/accept/$friendshipId'),
      headers: await getHeaders(),
    );
    return response.statusCode == 200;
  }

  // Видалити друга або скасувати запит (DELETE)
  static Future<bool> removeFriend(int friendId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/friends/remove/$friendId'),
      headers: await getHeaders(),
    );
    return response.statusCode == 200;
  }

  static Future<bool> blockUser(int friendId) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/friends/block/$friendId'),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Помилка блокування: $e");
      return false;
    }
  }

  static Future<bool> unblockUser(int friendId) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/friends/unblock/$friendId'),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Помилка при розблокуванні: $e');
      return false;
    }
  }

  static Future<bool> declineFriendRequest(int friendshipId) async {
    final response = await http.delete( // Використовуємо DELETE
      Uri.parse('${ApiConfig.baseUrl}/friends/decline/$friendshipId'),
      headers: await getHeaders(),
    );
    return response.statusCode == 200;
  }

  // === НОВИЙ МЕТОД: Оцінювання користувача ===
  static Future<bool> rateUser(int userId, int ratingValue) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId/rate'),
        headers: await getHeaders(),
        body: json.encode({"rating": ratingValue}),
      );

      print("DEBUG: Статус відповіді на оцінку: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print('Помилка при оцінюванні користувача: $e');
      return false;
    }
  }
  // === Отримання оцінки користувача він нас самих (зірочки) ===
  static Future<Map<String, dynamic>> getMyRating(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId/my-rating'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Помилка при отриманні рейтингу: $e');
    }
    return {"rating": 0, "is_rated": false};
  }

 //====Оповіщення Match
  static Future<bool> sendInvite(int targetId, String gameName) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/send-invite'),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer ${UserSession().token}"},
      body: jsonEncode({
        "recipient_id": targetId, // Передаємо як ціле число (int)
        "game": gameName,
        "message": "Invited you to play"
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> acceptInvite(String inviteId) async {
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/accept-invite/$inviteId'));
    return response.statusCode == 200;
  }

  static Future<List<dynamic>> getNotifications() async {
    try {
      final token = await UserSession.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body); // Повертаємо список JSON-об'єктів
      } else {
        return []; // Повертаємо порожній список у разі помилки
      }
    } catch (e) {
      print("Error fetching notifications: $e");
      return [];
    }
  }

  static Future<bool> updateNotificationStatus(String notificationId, String newStatus) async {
    try {
      // Додаємо ?new_status=... в кінець URL
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/notifications/$notificationId/update-status?new_status=$newStatus'),
        headers: await getHeaders(), // Використовуйте свої заголовки з токеном!
      );

      if (response.statusCode == 200) return true;
      return false;
    } catch (e) {
      print("Exception при оновленні статусу: $e");
      return false;
    }
  }

  static Future<bool> deleteNotification(String id) async {
    final token = UserSession().token;
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/notifications/$id'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    return response.statusCode == 200;
  }

  static Future<bool> acceptGameInvite(String inviteId) async {
    final token = UserSession().token;
    final response = await http.patch( // Використовуємо PATCH, як у вас на бекенді
      Uri.parse('${ApiConfig.baseUrl}/notifications/$inviteId/accept'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    return response.statusCode == 200;
  }

  static Future<GamerProfile> getUserProfile(String userId) async {
    // Замініть URL на ваш реальний ендпоінт для отримання профілю
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/users/$userId/profile'));

    if (response.statusCode == 200) {
      // Припускаємо, що у вас є метод fromJson у моделі GamerProfile
      return GamerProfile.fromJson(json.decode(response.body));
    } else {
      throw Exception('Не вдалося завантажити профіль');
    }
  }

  //Archivation methods
  static Future<bool> _patchRequest(String url) async {
    final token = UserSession().token;
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}$url'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Помилка запиту ($url): $e");
      return false;
    }
  }
  static Future<bool> archiveNotification(String id) =>
      _patchRequest('/notifications/$id/archive');

  static Future<bool> archiveAllNotifications() =>
      _patchRequest('/notifications/archive-all');

  static Future<List<NotificationModel>> getHistory() async {
    final token = UserSession().token;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications/history'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        List body = json.decode(response.body);
        return body.map((e) => NotificationModel.fromJson(e)).toList();
      }
    } catch (e) {
      print("Помилка отримання історії: $e");
    }
    return [];
  }

  // 2. Остаточне видалення всього архіву
  static Future<bool> deleteAllHistory() async {
    final token = UserSession().token;
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/notifications/history/clear'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Помилка видалення історії: $e");
      return false;
    }
  }

}
