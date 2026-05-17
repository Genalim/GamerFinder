import 'package:flutter/material.dart';

// 1. МОДЕЛЬ ДАНИХ ГЕЙМЕРА
class GamerProfile {
  final String nickname;
  final bool isPro;
  final String mainGame;
  final String platform;
  final String chatType;
  final List<String> tags;
  final List<String> languages;
  final bool hasVoice;
  final bool isOnline;

  GamerProfile({
    required this.nickname,
    required this.isPro,
    required this.mainGame,
    required this.platform,
    required this.chatType,
    required this.tags,
    required this.languages,
    required this.hasVoice,
    required this.isOnline,
  });
}

class GameItem {
  final String name;
  final String imagePath;
  final String genre;

  GameItem({required this.name, required this.imagePath, required this.genre});
}

// 2. ГОЛОВНИЙ ЕКРАН HOME FEED
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final List<GamerProfile> _mockGamers = [
    GamerProfile(
      nickname: 'ShadowNinja123',
      isPro: true,
      mainGame: 'Valorant',
      platform: 'PC',
      chatType: 'Discord (+2)',
      tags: ['Co-op', 'Competitive', 'Casual', 'Training'],
      languages: ['English', 'German'],
      hasVoice: true,
      isOnline: true,
    ),
    GamerProfile(
      nickname: 'MMA_boxer',
      isPro: true,
      mainGame: 'Dota 2',
      platform: 'Xbox',
      chatType: 'Steam chat',
      tags: ['Co-op', 'Casual', 'Training'],
      languages: ['English'],
      hasVoice: false,
      isOnline: true,
    ),
    GamerProfile(
      nickname: 'Mario_gamer',
      isPro: false,
      mainGame: 'Apex Legends',
      platform: 'PC',
      chatType: '',
      tags: ['Competitive', 'Casual'],
      languages: ['German'],
      hasVoice: false,
      isOnline: false,
    ),
  ];

  final List<GameItem> _userSavedGames = [
    GameItem(name: 'Valorant', imagePath: 'assets/games/valorant.png', genre: 'FPS/Shooters'),
    GameItem(name: 'SMITE', imagePath: 'assets/games/smite.png', genre: 'MOBA'),
    GameItem(name: 'Overwatch 2', imagePath: 'assets/games/overwatch.png', genre: 'FPS/Shooters'),
    GameItem(name: 'Fall Guys', imagePath: 'assets/games/fall_guys.png', genre: 'Battle Royale'),
    GameItem(name: 'World of Warcraft', imagePath: 'assets/games/wow.png', genre: 'RPG/MMO'),
  ];

  bool _isGameDropdownOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _temporarilySelectedGames = [];
  List<String> _confirmedActiveGames = [];

  final List<String> _selectedPlayStyles = [];
  final List<String> _selectedPlatforms = [];
  bool _voiceChatOn = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<GamerProfile> filteredGamers = _mockGamers.where((gamer) {
      if (_confirmedActiveGames.isNotEmpty && !_confirmedActiveGames.contains(gamer.mainGame)) {
        return false;
      }
      if (_selectedPlayStyles.isNotEmpty) {
        bool hasMatchingTag = gamer.tags.any((tag) => _selectedPlayStyles.contains(tag));
        if (!hasMatchingTag) return false;
      }
      if (_selectedPlatforms.isNotEmpty && !_selectedPlatforms.contains(gamer.platform)) {
        return false;
      }
      if (_voiceChatOn && !gamer.hasVoice) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchHeader(),
                const SizedBox(height: 6),
                _buildPlayStyleFilter(),
                const SizedBox(height: 6),
                _buildPlatformFilter(),
                const SizedBox(height: 8),
                _buildToggleAndRatingSection(),
                const SizedBox(height: 8),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Your matches',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredGamers.isEmpty
                      ? const Center(
                    child: Text(
                      'No matches found for active filters.',
                      style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 14),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: filteredGamers.length,
                    itemBuilder: (context, index) {
                      return GamerCard(profile: filteredGamers[index]);
                    },
                  ),
                ),
              ],
            ),
            if (_isGameDropdownOpen) _buildGamesDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    String placeholderText = _confirmedActiveGames.isNotEmpty
        ? _confirmedActiveGames.join(' / ')
        : 'What do you want to play now?';

    // Перевірка умови для хрестика (пункт 2): якщо є текст або є підтверджена гра
    bool showClearButton = _searchController.text.isNotEmpty || _confirmedActiveGames.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6), // Ущільнено сам хедер
      child: Row(
        children: [
          Container(
            width: 33,
            height: 33,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF181826),
              border: Border.all(color: const Color(0xFF00F5A0).withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F5A0).withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.person_outline, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF181826),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    // 2) Клікабельність усього вікна активує випадаючий список
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() {
                          _isGameDropdownOpen = true;
                        });
                      },
                      child: TextField(
                        controller: _searchController,
                        onTap: () {
                          setState(() {
                            _isGameDropdownOpen = true;
                          });
                        },
                        onChanged: (value) {
                          setState(() {});
                        },
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
                        decoration: InputDecoration(
                          hintText: placeholderText,
                          hintStyle: TextStyle(
                            color: _confirmedActiveGames.isNotEmpty ? Colors.white : const Color(0xFF8E8EA9),
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),

                  // 2) Логіка хрестика: очищає, але НЕ відкриває список знову
                  if (showClearButton)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _confirmedActiveGames.clear();
                          _temporarilySelectedGames.clear();
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6, left: 6),
                        child: Icon(Icons.close, color: Color(0xFF8E8EA9), size: 18),
                      ),
                    ),

                  // Стрілочка: відкриває/закриває вікно при натисканні
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isGameDropdownOpen = !_isGameDropdownOpen;
                      });
                    },
                    child: RotatedBox(
                      quarterTurns: _isGameDropdownOpen ? 1 : 0,
                      child: Icon(
                        Icons.play_arrow,
                        color: _isGameDropdownOpen ? const Color(0xFF00F5A0) : Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.notifications_none, color: Colors.white, size: 24),
        ],
      ),
    );
  }

  Widget _buildGamesDropdown() {
    List<GameItem> searchedGames = _userSavedGames.where((game) {
      return game.name.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();

    return Positioned(
      top: 54,
      left: 24,
      right: 24,
      child: Container(
        height: 302,
        decoration: BoxDecoration(
          color: const Color(0xFF181826),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2B2B3B), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF181826).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: searchedGames.isEmpty
                  ? const Center(
                child: Text(
                  'No matching games found.',
                  style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 13),
                ),
              )
                  : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemCount: searchedGames.length,
                itemBuilder: (context, index) {
                  final game = searchedGames[index];
                  final isSelected = _temporarilySelectedGames.contains(game.name);

                  return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _temporarilySelectedGames.remove(game.name);
                          } else {
                            _temporarilySelectedGames.add(game.name);
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF00F5A0) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            color: const Color(0xFF2B2B3B),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.gamepad, color: Colors.white30, size: 28),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    game.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF00F5A0) : Colors.white,
                                      fontSize: 11,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  game.genre,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF8E8EA9),
                                    fontSize: 8,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // ВИПРАВЛЕНО (Пункт 2 та 3): Текст розбитий на 2 рядки, прибрано переповнення
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isGameDropdownOpen = false;
                      });
                    },
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'Inter', height: 1.3),
                        children: [
                          TextSpan(text: 'Don’t see your game here?\nManage your games in '),
                          TextSpan(
                            text: 'Settings',
                            style: TextStyle(
                              color: Color(0xFF00F5A0), // Тільки слово Settings зелене
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _temporarilySelectedGames.isEmpty
                      ? null
                      : () {
                    setState(() {
                      _confirmedActiveGames = List.from(_temporarilySelectedGames);
                      _isGameDropdownOpen = false;
                      _searchController.clear();
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF181826), // Фон завжди темний за специфікацією контуру
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        // ОНОВЛЕНО: Тільки неоновий контур стає активним
                        color: _temporarilySelectedGames.isNotEmpty
                            ? const Color(0xFF00F5A0)
                            : const Color(0xFF2B2B3B),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'GO',
                        style: TextStyle(
                          // ОНОВЛЕНО: Текст теж підсвічується зеленим, коли активний
                          color: _temporarilySelectedGames.isNotEmpty
                              ? const Color(0xFF00F5A0)
                              : const Color(0xFF8E8EA9),
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayStyleFilter() {
    final List<String> styles = ['Casual', 'Competitive', 'Co-op', 'Training'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: styles.map((style) {
          final isSelected = _selectedPlayStyles.contains(style);
          return _buildFilterChip(
            label: style,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedPlayStyles.remove(style);
                } else {
                  _selectedPlayStyles.add(style);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlatformFilter() {
    final List<String> platforms = ['PS', 'Mobile', 'PC', 'Xbox', 'Switch'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: platforms.map((platform) {
          final isSelected = _selectedPlatforms.contains(platform);
          return _buildFilterChip(
            label: platform,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedPlatforms.remove(platform);
                } else {
                  _selectedPlatforms.add(platform);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F0F1A) : Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleAndRatingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Voice chat',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 16, letterSpacing: -0.04),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _voiceChatOn = !_voiceChatOn),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 25,
                  decoration: BoxDecoration(
                    color: _voiceChatOn ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (_voiceChatOn)
                        BoxShadow(
                          color: const Color(0xFF00F5A0).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        left: _voiceChatOn ? 10 : 34,
                        top: 6,
                        child: Text(
                          _voiceChatOn ? 'ON' : 'OFF',
                          style: TextStyle(
                            color: _voiceChatOn ? const Color(0xFF0F0F1A) : const Color(0xFFA3A3B5),
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        left: _voiceChatOn ? 36 : 2,
                        top: 2,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 21,
                          height: 21,
                          decoration: BoxDecoration(
                            color: _voiceChatOn ? const Color(0xFF181826) : const Color(0xFF2B2B3B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _voiceChatOn ? const Color(0xFF181826) : const Color(0xFF00F5A0),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'Rating',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 16),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.lock, color: Color(0xFF6F6F80), size: 16),
              const SizedBox(width: 4),
              const Text(
                'Unlock in PRO',
                style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GamerCard extends StatelessWidget {
  final GamerProfile profile;

  const GamerCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(16),
        border: profile.isPro
            ? Border.all(color: const Color(0xFF00F5A0).withOpacity(0.2), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF181826),
                      boxShadow: [
                        if (profile.isOnline)
                          BoxShadow(
                            color: const Color(0xFF00F5A0).withOpacity(0.25),
                            blurRadius: 5,
                            spreadRadius: 0,
                          )
                        else
                          BoxShadow(
                            color: const Color(0xFF8E8EA9).withOpacity(0.15),
                            blurRadius: 4,
                            spreadRadius: 0,
                          ),
                      ],
                      border: Border.all(
                        color: profile.isOnline
                            ? const Color(0xFF00F5A0).withOpacity(0.8)
                            : const Color(0xFF8E8EA9).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        profile.nickname[0].toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Love Light',
                          fontSize: 30,
                          fontWeight: FontWeight.w400,
                          height: 27 / 30,
                          color: profile.isOnline ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.nickname,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        if (profile.isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0066FF)]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PRO', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 10)),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star, color: Color(0xFFFFD700), size: 12),
                          const SizedBox(width: 2),
                          const Text('PRO only', style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 8)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${profile.mainGame} — ${profile.platform} ${profile.chatType.isNotEmpty ? "| " + profile.chatType : ""}',
                      style: const TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text('+3 more matches', style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: profile.isOnline ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(profile.isOnline ? 'Online' : 'Offline', style: const TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 11)),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Icon(profile.hasVoice ? Icons.mic : Icons.mic_off, color: profile.hasVoice ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9), size: 13),
                  const SizedBox(width: 4),
                  Text('Voice', style: TextStyle(color: profile.hasVoice ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 11)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Languages: ${profile.languages.join(" • ")}', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: profile.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF2B2B3B), borderRadius: BorderRadius.circular(8)),
                child: Text(tag, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 10)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00F5A0), width: 1), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('View profile', style: TextStyle(color: Color(0xFF00F5A0), fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14))),
                  ),
                ),
              ),
              const SizedBox(width: 21),
              Expanded(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF00F5A0), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('Invite to play', style: TextStyle(color: Color(0xFF0F0F1A), fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}