import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'custom_widgets.dart';
import 'api_config.dart';
import 'user_session.dart';
import 'Home_Feed_screen.dart'; // Для GamerProfile.fromJson

class EditPlayStyleScreen extends StatefulWidget {
  const EditPlayStyleScreen({super.key});

  @override
  State<EditPlayStyleScreen> createState() => _EditPlayStyleScreenState();
}

class _EditPlayStyleScreenState extends State<EditPlayStyleScreen> {
  late Set<String> _selectedStyles;
  late Set<String> _selectedTimes;
  late bool _useVoiceChat;

  final List<Map<String, String>> _styles = [
    {
      'name': 'Casual',
      'desc': 'Play to relax and have fun',
      'file': 'Casual.png'
    },
    {
      'name': 'Competitive',
      'desc': 'Focused on ranked and winning',
      'file': 'Competitive.png'
    },
    {
      'name': 'Co-op',
      'desc': 'Team up for missions and raids',
      'file': 'Co_op.png'
    },
    {
      'name': 'Training',
      'desc': 'Practice and improve your skills',
      'file': 'Training.png'
    },
  ];

  final List<String> _times = ['Morning', 'Afternoon', 'Evening', 'Late night'];

  @override
  void initState() {
    super.initState();
    final user = UserSession().currentUser;

    // 1. Підтягуємо стилі гри (використовуємо поле tags замість неіснуючого styles)
    _selectedStyles = Set.from(user?.tags ?? []);

    // 2. Конвертуємо години (times) з профілю назад у текстові слоти
    Set<String> mappedTimes = {};
    for (var hour in user?.times ?? []) {
      if (hour >= 6 && hour < 12) {
        mappedTimes.add('Morning');
      } else if (hour >= 12 && hour <= 17) {
        mappedTimes.add('Afternoon');
      } else if (hour >= 18 && hour < 23) {
        mappedTimes.add('Evening');
      } else {
        mappedTimes.add('Late night');
      }
    }
    _selectedTimes = mappedTimes;

    // 3. Голосовий чат (використовуємо hasVoice замість hasVoiceChat, як у вашій моделі)
    _useVoiceChat = user?.hasVoice ?? false;
  }

  void _toggleSelection(Set<String> selectionSet, String value) {
    setState(() {
      if (selectionSet.contains(value)) {
        selectionSet.remove(value);
      } else {
        selectionSet.add(value);
      }
    });
  }

  // Метод конвертації слотів у години та відправки на бекенд
  List<int> _convertTimesToHours(Set<String> times) {
    Set<int> hours = {};
    if (times.contains('Morning')) hours.addAll([8, 9, 10]);
    if (times.contains('Afternoon')) hours.addAll([13, 14, 15]);
    if (times.contains('Evening')) hours.addAll([19, 20, 21]);
    if (times.contains('Late night')) hours.addAll([1, 2, 3]);
    return hours.toList();
  }

  Future<void> _applyChanges() async {
    try {
      final userId = await UserSession.getUserId();
      final token = await UserSession.getToken();
      if (userId == null) return;

      final List<int> hoursList = _convertTimesToHours(_selectedTimes);

      // Відправляємо оновлення (припускаємо, що у вас є відповідні ручки на бекенді для апдейту профілю/налаштувань)
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/users/$userId/playstyle-preferences"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: json.encode({
          "styles": _selectedStyles.toList(),
          "times": hoursList,
          "voice_chat": _useVoiceChat,
        }),
      );

      if (response.statusCode == 200) {
        // Оновлюємо локальний кеш
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

        Navigator.pop(context); // Повертаємось на SettingsScreen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Не вдалося оновити налаштування стилю")),
        );
      }
    } catch (e) {
      debugPrint("Помилка збереження стилю гри: $e");
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
                _buildAppBar('Edit Play Style'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 0, 26, 120),
                    child: Column(
                      children: [
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 15,
                          runSpacing: 15,
                          alignment: WrapAlignment.center,
                          children: _styles.map((style) {
                            final isSelected = _selectedStyles.contains(style['name']);
                            return _buildStyleCard(style, isSelected, accentColor);
                          }).toList(),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'When do you usually play?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _times.map((time) {
                            final isSelected = _selectedTimes.contains(time);
                            return _buildTimeChip(time, isSelected, accentColor);
                          }).toList(),
                        ),
                        const SizedBox(height: 35),
                        _buildVoiceChatToggle(accentColor),
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

  Widget _buildVoiceChatToggle(Color accentColor) {
    return SizedBox(
      width: 197,
      height: 25,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Prefer voice chat',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 15 / 14,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _useVoiceChat = !_useVoiceChat),
            child: Container(
              width: 60,
              height: 25,
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B3B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: _useVoiceChat ? 7 : 39,
                    top: _useVoiceChat ? 9 : 8,
                    child: Text(
                      _useVoiceChat ? 'ON' : 'OFF',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 8,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFA3A3B5),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: _useVoiceChat ? 27 : 2,
                    top: 3,
                    child: Container(
                      width: 31,
                      height: 19,
                      decoration: BoxDecoration(
                        color: _useVoiceChat ? accentColor : const Color(0xFF2B2B3B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
              Navigator.pop(context); // Вихід без збереження
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

  Widget _buildStyleCard(Map<String, String> style, bool isSelected, Color accentColor) {
    return GestureDetector(
      onTap: () => _toggleSelection(_selectedStyles, style['name']!),
      child: Container(
        width: 156,
        height: 190,
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
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D17),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/PlayStyles/${style['file']}',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              style['name']!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isSelected ? accentColor : Colors.white,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                style['desc']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFA3A3B5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String time, bool isSelected, Color accentColor) {
    return GestureDetector(
      onTap: () => _toggleSelection(_selectedTimes, time),
      child: Container(
        width: 156,
        height: 44,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF181826),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: accentColor, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          time,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            height: 15 / 14,
            color: isSelected ? accentColor : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    bool canApply = _selectedStyles.isNotEmpty && _selectedTimes.isNotEmpty;
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
              onPressed: !canApply ? null : _applyChanges,
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