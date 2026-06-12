import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'custom_widgets.dart';
import 'api_config.dart';
import 'user_session.dart';
import 'Home_Feed_screen.dart'; // Для доступу до GamerProfile.fromJson

class EditPlatformSelectionScreen extends StatefulWidget {
  const EditPlatformSelectionScreen({super.key});

  @override
  State<EditPlatformSelectionScreen> createState() => _EditPlatformSelectionScreenState();
}

class _EditPlatformSelectionScreenState extends State<EditPlatformSelectionScreen> {
  late Set<String> _selectedPlatforms;

  // Оновлюємо список: додаємо точне ім'я файлу для кожної платформи
  final List<Map<String, String>> _platforms = [
    {'name': 'PC', 'file': 'Personal_computer.png'},
    {'name': 'PS', 'file': 'Play_station.png'},
    {'name': 'Mobile', 'file': 'Mobile.png'},
    {'name': 'Switch', 'file': 'Switch.png'},
    {'name': 'Xbox', 'file': 'Xbox.png'},
  ];

  @override
  void initState() {
    super.initState();
    // Підтягуємо актуальні платформи з поточної сесії користувача
    final currentPlatforms = UserSession().currentUser?.platformsList ?? [];
    _selectedPlatforms = Set.from(currentPlatforms);
  }

  void _togglePlatform(String name) {
    setState(() {
      if (_selectedPlatforms.contains(name)) {
        _selectedPlatforms.remove(name);
      } else {
        _selectedPlatforms.add(name);
      }
    });
  }

  // Метод відправки оновлених платформ на бекенд
  Future<void> _applyChanges() async {
    try {
      final userId = await UserSession.getUserId();
      final token = await UserSession.getToken();
      if (userId == null) return;

      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/users/$userId/platforms"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: json.encode(_selectedPlatforms.toList()),
      );

      if (response.statusCode == 200) {
        // Оновлюємо локальний кеш профілю
        final updatedProfileResponse = await http.get(
          Uri.parse("${ApiConfig.baseUrl}/users/$userId"),
          headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
        );
        if (updatedProfileResponse.statusCode == 200) {
          final data = json.decode(updatedProfileResponse.body);
          setState(() {
            UserSession().currentUser = GamerProfile.fromJson(data);
          });
        }

        Navigator.pop(context); // Повертаємось на SettingsScreen після успішного збереження
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Не вдалося оновити платформи")),
        );
      }
    } catch (e) {
      debugPrint("Помилка збереження платформ: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00F5A0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar('Edit Platform Selection'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 0, 26, 120),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'You can select multiple',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: Color(0xFFA3A3B5),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Wrap(
                          spacing: 15,
                          runSpacing: 15,
                          alignment: WrapAlignment.center,
                          children: _platforms.map((platform) {
                            final isSelected = _selectedPlatforms.contains(platform['name']);
                            return _buildPlatformCard(platform, isSelected, accentColor);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildApplyButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.pop(context); // Просто вихід без збереження (Cancel)
            },
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(Map<String, String> platform, bool isSelected, Color accentColor) {
    return GestureDetector(
      onTap: () => _togglePlatform(platform['name']!),
      child: Container(
        width: 156,
        height: 170,
        decoration: BoxDecoration(
          color: const Color(0xFF181826),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: accentColor, width: 2) : null,
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 140,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D17),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/Platforms/${platform['file']}',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              platform['name']!,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isSelected ? accentColor : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Кнопка застосування змін для екрану налаштувань
  Widget _buildApplyButton() {
    return Container(
      color: const Color(0xFF0F0F1A),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F5A0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _selectedPlatforms.isEmpty ? null : _applyChanges,
              child: const Text(
                'APPLY CHANGES',
                style: TextStyle(
                  color: Color(0xFF0F0F13),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}