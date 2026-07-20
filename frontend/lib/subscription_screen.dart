import 'package:flutter/material.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'user_session.dart';
import 'Home_Feed_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  Future<void> _simulateTestActivation(BuildContext context) async {
    try {
      final token = await UserSession.getToken();
      if (token == null) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/pro/activate');
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          "trial": false,
          "test_hours": 12, // Передаємо 12 годин для тесту
        }),
      );

      if (response.statusCode == 200) {
        // Оновлюємо локальну сесію профілю свіжими даними з бази
        final userId = await UserSession.getUserId();
        if (userId != null) {
          final profileResponse = await http.get(
            Uri.parse("${ApiConfig.baseUrl}/users/$userId"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
          );
          if (profileResponse.statusCode == 200) {
            UserSession().currentUser = GamerProfile.fromJson(json.decode(profileResponse.body));
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test PRO activated for 12 hours!')),
          );
          Navigator.pop(context);
        }
      } else {
        print("Помилка активації: ${response.body}");
      }
    } catch (e) {
      print("Помилка мережі: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'GamerFinder PRO',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // PRO Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF0066FF).withOpacity(0.2), const Color(0xFF0F0F1A)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0066FF)),
            ),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium, size: 64, color: Color(0xFF0066FF)),
                const SizedBox(height: 16),
                const Text('Unlock PRO Features', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Get advanced filters, unlimited matches, and priority support.',
                    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8E8EA9))),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Features List
          _buildFeatureRow('Advanced player filters'),
          _buildFeatureRow('Unlimited daily matches'),
          _buildFeatureRow('Priority profile visibility'),

          const SizedBox(height: 40),

          // Action Button (Основна кнопка оплати)
          GestureDetector(
            onTap: () {
              // Тут буде логіка виклику Payment Gateway
              print("Proceed to payment...");
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0085FF)]),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('Upgrade for \$1.99/ 30 days', style: TextStyle(color: Color(0xFF0F0F1A), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

          const SizedBox(height: 16),

          // Кнопка "Тест Актівейшн" (додає 12 годин для тестування)
          GestureDetector(
            onTap: () => _simulateTestActivation(context),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00F5A0), width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('Тест Актівейшн (+12 годин)', style: TextStyle(color: Color(0xFF00F5A0), fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF00F5A0), size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}