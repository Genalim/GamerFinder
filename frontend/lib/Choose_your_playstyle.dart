import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'Language_Selection_screen.dart';
import 'profile_setup_manager.dart'; // 1. ІМПОРТУЄМО МЕНЕДЖЕР

class PlayStyleScreen extends StatefulWidget {
  const PlayStyleScreen({super.key});

  @override
  State<PlayStyleScreen> createState() => _PlayStyleScreenState();
}

class _PlayStyleScreenState extends State<PlayStyleScreen> {
  // === 2. ПІДКЛЮЧАЄМО МЕНЕДЖЕР СТАНУ ===
  final _manager = ProfileSetupManager.instance;

  late Set<String> _selectedStyles;
  late Set<String> _selectedTimes;  // Повертаємо на повноцінний late сет
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

  // === 3. ПІДТЯГУЄМО СТАН З ПАМ'ЯТІ ===
  @override
  void initState() {
    super.initState();
    _selectedStyles = Set.from(_manager.selectedPlayStyles);
    // ОНОВЛЕНО: Тепер залізно підтягуємо повноцінний сет часу
    _selectedTimes = Set.from(_manager.selectedTimes);
    _useVoiceChat = _manager.useVoiceChat;
  }

  // ОНОВЛЕНО: Повертаємо чистий множинний вибір для обох сетів
  void _toggleSelection(Set<String> selectionSet, String value) {
    setState(() {
      if (selectionSet.contains(value)) {
        selectionSet.remove(value);
      } else {
        selectionSet.add(value);
      }
      _manager.selectedTimes = _selectedTimes;
    });
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
                _buildAppBar('Choose your play style'),
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
                            final isSelected = _selectedStyles.contains(
                                style['name']);
                            return _buildStyleCard(
                                style, isSelected, accentColor);
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
                            return _buildTimeChip(
                                time, isSelected, accentColor);
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
              child: _buildContinueButton(),
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
                        color: _useVoiceChat ? accentColor : const Color(
                            0xFF2B2B3B),
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
            icon: const Icon(
                Icons.arrow_back_ios_new, color: Colors.white, size: 24),
            onPressed: () {
              // ОНОВЛЕНО: Фіксуємо повноцінний малтипл-сет при виході назад
              _manager.selectedPlayStyles = _selectedStyles;
              _manager.selectedTimes = _selectedTimes;
              _manager.useVoiceChat = _useVoiceChat;
              Navigator.pop(context);
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

  Widget _buildStyleCard(Map<String, String> style, bool isSelected,
      Color accentColor) {
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
          border: isSelected
              ? Border.all(color: accentColor, width: 1.5)
              : null,
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

  Widget _buildContinueButton() {
    bool canContinue = _selectedStyles.isNotEmpty && _selectedTimes.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeonGameButton(
        isActive: canContinue,
        onTap: () {
          if (canContinue) {
            print("Styles: $_selectedStyles, Times: $_selectedTimes, Voice: $_useVoiceChat");

            // ОНОВЛЕНО: Фіксуємо повноцінний малтипл-сет при переході вперед
            _manager.selectedPlayStyles = _selectedStyles;
            _manager.selectedTimes = _selectedTimes;
            _manager.useVoiceChat = _useVoiceChat;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectionScreen(),
              ),
            );
          }
        },
      ),
    );
  }
}