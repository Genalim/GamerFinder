import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notifications_overlay.dart';
import 'custom_widgets.dart';
import 'gamer_profile_screen.dart';

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
  final List<String> gamesList;
  final List<String> platformsList;
  final Map<String, String> connectedPlatforms;
  final String playTime;
  final String password;

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
    required this.gamesList,
    required this.platformsList,
    required this.connectedPlatforms,
    required this.playTime,
    required this.password,
  });

  factory GamerProfile.fromJson(Map<String, dynamic> json) {
    List<String> games = List<String>.from(json['games'] ?? []);
    return GamerProfile(
      nickname: json['nickname'] ?? 'Unknown',
      isPro: json['is_pro'] ?? false,
      mainGame: games.isNotEmpty ? games[0] : 'None',
      platform: (json['platforms'] as List).isNotEmpty ? json['platforms'][0] : 'None',
      chatType: json['connected_accounts'] != null && (json['connected_accounts'] as Map).isNotEmpty
          ? (json['connected_accounts'] as Map).keys.first
          : 'None',
      tags: List<String>.from(json['play_styles'] ?? []),
      languages: List<String>.from(json['languages'] ?? []),
      hasVoice: json['voice_chat'] ?? false,
      isOnline: json['is_online'] ?? false,
      gamesList: games,
      platformsList: List<String>.from(json['platforms'] ?? []),
      connectedPlatforms: Map<String, String>.from(json['connected_accounts'] ?? {}),
      playTime: (json['times'] as List).join(' • '),
      password: json['password'] ?? '',
    );
  }

  String getBestMatchingGame(List<String> myGames) {
    var common = gamesList.where((g) => myGames.contains(g)).toList();
    return common.isNotEmpty ? common[0] : (gamesList.isNotEmpty ? gamesList[0] : 'None');
  }

  int getExtraMatchesCount(List<String> myGames) {
    var common = gamesList.where((g) => myGames.contains(g)).toList();
    return common.length > 1 ? common.length - 1 : 0;
  }
}

class GameItem {
  final String name;
  final String imagePath;
  final String genre;
  GameItem({required this.name, required this.imagePath, required this.genre});
}

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  bool _isNotificationsOpen = false;
  bool _hasUnreadNotifications = true;
  List<GamerProfile> _loadedGamers = [];

  @override
  void initState() {
    super.initState();
    _loadGamers();
  }

  Future<void> _loadGamers() async {
    try {
      final String response = await rootBundle.loadString('assets/users.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _loadedGamers = data.map((json) => GamerProfile.fromJson(json)).toList();
      });
    } catch (e) {
      debugPrint("Error loading JSON: $e");
    }
  }

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
    const accentColor = Color(0xFF00F5A0);

    List<GamerProfile> filteredGamers = _loadedGamers.where((gamer) {
      if (_confirmedActiveGames.isNotEmpty && !gamer.gamesList.any((g) => _confirmedActiveGames.contains(g))) {
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
                _buildSearchHeader(accentColor),
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
                  child: _loadedGamers.isEmpty
                      ? const Center(
                    child: CircularProgressIndicator(color: accentColor),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: filteredGamers.length,
                    itemBuilder: (context, index) {
                      return GamerCard(profile: filteredGamers[index], accentColor: accentColor, activeGames: _confirmedActiveGames);
                    },
                  ),
                ),
              ],
            ),
            if (_isGameDropdownOpen) _buildGamesDropdown(),
            if (_isNotificationsOpen)
              Positioned(
                top: 50,
                left: 24,
                right: 24,
                child: NotificationsOverlay(
                  onClose: () => setState(() => _isNotificationsOpen = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(Color accentColor) {
    String placeholderText = _confirmedActiveGames.isNotEmpty
        ? _confirmedActiveGames.join(' / ')
        : 'What do you want to play now?';

    bool showClearButton = _searchController.text.isNotEmpty || _confirmedActiveGames.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 33,
            height: 33,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF181826),
              border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.5),
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
                        color: _isGameDropdownOpen ? accentColor : Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          NeonNotificationBell(
            hasUnread: _hasUnreadNotifications,
            isOpen: _isNotificationsOpen,
            onTap: () {
              setState(() {
                _isNotificationsOpen = !_isNotificationsOpen;
                if (_isNotificationsOpen) {
                  _hasUnreadNotifications = false;
                }
              });
            },
          ),
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
              color: const Color(0xFF181826).withValues(alpha: 0.25),
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
                      ));
                },
              ),
            ),
            const SizedBox(height: 8),
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
                          TextSpan(text: 'Don’t see your game here? Manage your games in '),
                            TextSpan(
                            text: 'Settings',
                            style: TextStyle(
                              color: Color(0xFF00F5A0),
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
                      color: const Color(0xFF181826),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
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
                child: Container(
                  width: 60,
                  height: 25,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2B3B), // Статичний темний фон
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Текст ON/OFF (статичний, під бігунком)
                      Positioned(
                        left: _voiceChatOn ? 8 : 37,
                        top: 8,
                        child: Text(
                          _voiceChatOn ? 'ON' : 'OFF',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8E8EA9),
                          ),
                        ),
                      ),
                      // Анімований бігунок-капсула
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        left: _voiceChatOn ? 27 : 2,
                        top: 3,
                        child: Container(
                          width: 31,
                          height: 19,
                          decoration: BoxDecoration(
                            color: _voiceChatOn ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B),
                            borderRadius: BorderRadius.circular(10), // Робить форму капсули
                            border: Border.all(
                              color: const Color(0xFF00F5A0),
                              width: 1,
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
            children: const [
              Text(
                'Rating',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 16),
              ),
              SizedBox(width: 6),
              Icon(Icons.lock, color: Color(0xFF6F6F80), size: 16),
              SizedBox(width: 4),
              Text(
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
  final Color accentColor;
  final List<String> activeGames;

  const GamerCard({
    super.key,
    required this.profile,
    required this.accentColor,
    required this.activeGames,
  });

  @override
  Widget build(BuildContext context) {
    var common = profile.gamesList.where((g) => activeGames.contains(g)).toList();
    String bestGame = common.isNotEmpty ? common[0] : (profile.gamesList.isNotEmpty ? profile.gamesList[0] : 'None');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(16),
        border: profile.isPro ? Border.all(color: accentColor.withValues(alpha: 0.2), width: 1.5) : null,
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ЛІВА ЧАСТИНА: Аватар + Статуси
                  Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF181826),
                          border: Border.all(color: profile.isOnline ? accentColor.withValues(alpha: 0.8) : const Color(0xFF8E8EA9).withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: Center(
                          child: Text(profile.nickname[0].toUpperCase(), style: TextStyle(fontFamily: 'Love Light', fontSize: 34, color: profile.isOnline ? accentColor : const Color(0xFF8E8EA9))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: profile.isOnline ? accentColor : const Color(0xFF8E8EA9), shape: BoxShape.circle)), const SizedBox(width: 8), Text(profile.isOnline ? 'Online' : 'Offline', style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 13, fontWeight: FontWeight.w500))]),
                          const SizedBox(height: 10),
                          Row(children: [Icon(profile.hasVoice ? Icons.mic : Icons.mic_off, color: profile.hasVoice ? accentColor : const Color(0xFF8E8EA9), size: 16), const SizedBox(width: 6), Text('Voice', style: TextStyle(color: profile.hasVoice ? accentColor : const Color(0xFF8E8EA9), fontSize: 13, fontWeight: FontWeight.w500))]),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // ПРАВА ЧАСТИНА: Нік, Гра, Теги + Languages
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(profile.nickname, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18))),
                            if (profile.isPro) ...[
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(gradient: LinearGradient(colors: [accentColor, const Color(0xFF0066FF)]), borderRadius: BorderRadius.circular(6)), child: const Text('PRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                            ],
                          ],
                        ),
                        Text(bestGame, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 15)),
                        const SizedBox(height: 10),
                        // Теги (збільшений padding для вирівнювання з Voice)
                        Wrap(spacing: 6, runSpacing: 6, children: profile.tags.map((t) => _buildTag(t)).toList()),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: profile.platformsList.map((p) => _buildTag(p)).toList()),
                        const SizedBox(height: 12),
                        // Languages - повна назва, все сірим
                        Text('Languages: ${profile.languages.join(" • ")}', style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile.isPro)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    children: [
                      FigmaRatingStar(isFilled: true, size: 14),
                      SizedBox(width: 4),
                      Text('PRO only', style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(children: [Expanded(child: _buildButton('View profile', false)), const SizedBox(width: 12), Expanded(child: _buildButton('Invite to play', true))]),
        ],
      ),
    );
  }

  Widget _buildTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFF2B2B3B), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
  );

  Widget _buildButton(String label, bool isAccent) => Container(
    height: 44,
    decoration: BoxDecoration(color: isAccent ? accentColor : Colors.transparent, border: isAccent ? null : Border.all(color: accentColor), borderRadius: BorderRadius.circular(12)),
    child: Center(child: Text(label, style: TextStyle(color: isAccent ? const Color(0xFF0F0F1A) : accentColor, fontWeight: FontWeight.w700, fontSize: 15))),
  );
}

