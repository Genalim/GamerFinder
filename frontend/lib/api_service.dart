import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'user_session.dart';

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

}
