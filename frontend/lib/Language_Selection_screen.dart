import 'package:flutter/material.dart';
import 'custom_widgets.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedLanguages = {};
  String _searchQuery = '';

  final List<Map<String, String>> _allLanguages = [
    {'name': 'English', 'sub': 'English', 'code': 'EN'},
    {'name': 'Українська', 'sub': 'Ukrainian', 'code': 'UK'},
    {'name': 'Italiano', 'sub': 'Italian', 'code': 'IT'},
    {'name': 'Español', 'sub': 'Spanish', 'code': 'ES'},
    {'name': 'Deutsch', 'sub': 'German', 'code': 'DE'},
    {'name': 'Français', 'sub': 'French', 'code': 'FR'},
    {'name': 'العربية', 'sub': 'Arabic', 'code': 'AR'},
    {'name': 'Português', 'sub': 'Portuguese', 'code': 'PT'},
    {'name': 'Русский', 'sub': 'Russian', 'code': 'RU'},
    {'name': 'Polski', 'sub': 'Polish', 'code': 'PL'},
    {'name': 'Türkçe', 'sub': 'Turkish', 'code': 'TR'},
    {'name': '中文', 'sub': 'Chinese (Mandarin)', 'code': 'ZH'},
    {'name': '한국어', 'sub': 'Korean', 'code': 'KO'},
    {'name': '日本語', 'sub': 'Japanese', 'code': 'JA'},
    {'name': 'हिन्दी', 'sub': 'Hindi', 'code': 'HI'},
    {'name': 'Bahasa Indonesia', 'sub': 'Indonesian', 'code': 'ID'},
    {'name': 'Tiếng Việt', 'sub': 'Vietnamese', 'code': 'VI'},
    {'name': 'עברית', 'sub': 'Hebrew', 'code': 'HE'},
    {'name': 'ไทย', 'sub': 'Thai', 'code': 'TH'},
    {'name': 'فарсі', 'sub': 'Persian (Farsi)', 'code': 'FA'},
    {'name': 'Nederlands', 'sub': 'Dutch', 'code': 'NL'},
    {'name': 'Svenska', 'sub': 'Swedish', 'code': 'SV'},
    {'name': 'Norsk', 'sub': 'Norwegian', 'code': 'NO'},
    {'name': 'Dansk', 'sub': 'Danish', 'code': 'DA'},
    {'name': 'Čеština', 'sub': 'Czech', 'code': 'CS'},
    {'name': 'Slovenčina', 'sub': 'Slovak', 'code': 'SK'},
    {'name': 'Български', 'sub': 'Bulgarian', 'code': 'BG'},
    {'name': 'Română', 'sub': 'Romanian', 'code': 'RO'},
    {'name': 'Ελληνικά', 'sub': 'Greek', 'code': 'EL'},
    {'name': 'Српски', 'sub': 'Serbian', 'code': 'SR'},
    {'name': 'Lietuvių', 'sub': 'Lithuanian', 'code': 'LT'},
    {'name': 'Hrvatski', 'sub': 'Croatian', 'code': 'HR'},
    {'name': 'Latviešu', 'sub': 'Latvian', 'code': 'LV'},
    {'name': 'Eesti', 'sub': 'Estonian', 'code': 'ET'},
    {'name': 'Íslenska', 'sub': 'Icelandic', 'code': 'IS'},
    {'name': 'Slovenščina', 'sub': 'Slovenian', 'code': 'SL'},
    {'name': 'Malti', 'sub': 'Maltese', 'code': 'MT'},
    {'name': 'Македонски', 'sub': 'Macedonian', 'code': 'MK'},
    {'name': 'Bahasa Melayu', 'sub': 'Malay', 'code': 'MS'},
    {'name': 'ქართული', 'sub': 'Georgian', 'code': 'KA'},
    {'name': 'Tagalog', 'sub': 'Tagalog', 'code': 'TL'},
    {'name': 'বাংলা', 'sub': 'Bengali', 'code': 'BN'},
  ];

  List<Map<String, String>> get _filteredLanguages {
    if (_searchQuery.isEmpty) return _allLanguages;
    return _allLanguages.where((lang) {
      final name = lang['name']!.toLowerCase();
      final sub = lang['sub']!.toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || sub.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00F5A0);
    const backgroundColor = Color(0xFF0F0F1A);

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar('Which languages do you\nwant to chat/speak?'),
                const Text(
                  'Choose one or more languages you’re comfortable with',
                  style: TextStyle(
                      color: Color(0xFFA3A3B5),
                      fontSize: 12,
                      fontFamily: 'Poppins'
                  ),
                ),
                const SizedBox(height: 20),
                _buildSearchInput(accentColor),
                const SizedBox(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                    child: Center(
                      child: SizedBox(
                        width: 360, // Ширина збігається з рядком пошуку
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          spacing: 10, // Мінімальна щелина між картками
                          runSpacing: 12,
                          children: _filteredLanguages.map((lang) {
                            final isSelected = _selectedLanguages.contains(lang['code']);
                            return _buildLanguageCard(lang, isSelected, accentColor);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: const BoxDecoration(color: backgroundColor),
                alignment: Alignment.center,
                child: _buildContinueButton(),
              ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
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

  Widget _buildSearchInput(Color accentColor) {
    return Container(
      width: 360,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search, color: accentColor, size: 20),
          Expanded(
            child: TextField(
              controller: _searchController,
              autocorrect: false,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Poppins'
              ),
              decoration: const InputDecoration(
                hintText: 'Search language...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(Icons.close, color: Colors.white54, size: 20),
            )
          else
            const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(Map<String, String> lang, bool isSelected, Color accentColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedLanguages.remove(lang['code']);
          } else {
            _selectedLanguages.add(lang['code']!);
          }
        });
      },
      child: Container(
        width: 175, // Збільшена ширина для заповнення простору
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF181826),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: accentColor, width: 1.5) : null,
        ),
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 11,
              child: Container(
                width: 31,
                height: 26,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: isSelected ? accentColor : Colors.white,
                      width: 1
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  lang['code']!,
                  style: TextStyle(
                    color: isSelected ? accentColor : Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 50,
              right: 4,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    lang['name']!,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? accentColor : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang['sub']!,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFA3A3B5),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    bool canContinue = _selectedLanguages.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeonGameButton(
        isActive: canContinue,
        onTap: () {
          if (canContinue) {
            print("Selected languages: $_selectedLanguages");
          }
        },
      ),
    );
  }
}