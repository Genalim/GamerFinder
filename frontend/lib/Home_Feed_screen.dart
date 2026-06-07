import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'notifications_overlay.dart';
import 'custom_widgets.dart';
import 'gamer_profile_screen.dart';
import 'user_session.dart';
import 'api_config.dart';

class GamerProfile {
  final int id;
  final String nickname;
  final String? avatar;
  final bool isPro;
  final String mainGame;
  final String platform;
  final String chatType;
  final List<String> tags; // Це play_styles
  final List<String> languages;
  final bool hasVoice; // Це voice_chat
  final bool isOnline;
  final List<Map<String, String>> gamesWithDetails;
  final List<String> gamesList;
  final List<String> platformsList;
  final Map<String, String> connectedPlatforms;
  final List<int> times; // ДОДАНО: для матчингу
  final String password;

  GamerProfile({
    required this.id,
    required this.nickname,
    this.avatar,
    required this.isPro,
    this.mainGame = 'None',
    required this.platform,
    required this.chatType,
    required this.tags,
    required this.languages,
    required this.hasVoice,
    required this.isOnline,
    required this.gamesWithDetails,
    required this.gamesList,
    required this.platformsList,
    required this.connectedPlatforms,
    required this.times, // ДОДАНО в конструктор
    required this.password,
  });
  ///Перероблюємо години у назви частини доби для відображення.
  String get readablePlayTime {
    if (times.isEmpty) return "Not specified";

    // 1. Створюємо список назв
    List<String> parts = [];

    // 2. Проходимо по унікальних годинах
    final uniqueTimes = times.toSet().toList()..sort();

    for (var hour in uniqueTimes) {
      if (hour >= 6 && hour < 11) {
        if (!parts.contains("Morning")) parts.add("Morning");
      } else if (hour >= 12 && hour <= 17) {
        if (!parts.contains("Afternoon")) parts.add("Afternoon");
      } else if (hour >= 18 && hour < 23) {
        if (!parts.contains("Evening")) parts.add("Evening");
      } else {
        if (!parts.contains("Night")) parts.add("Night");
      }
    }

    // 3. З'єднуємо через крапку
    return parts.join(' • ');
  }

  factory GamerProfile.fromJson(Map<String, dynamic> json) {
    // 1. Парсимо ігри з урахуванням імені ТА картинки
    final List<Map<String, String>> parsedGamesWithDetails = json['games'] is List
        ? (json['games'] as List)
        .where((item) => item is Map && item.containsKey('game') && item['game'] is Map)
        .map((item) => {
      'name': item['game']['name']?.toString() ?? 'Unknown',
      'image': item['game']['image_url']?.toString() ?? '',
    })
        .toList()
        : [];

    // 2. Для зворотної сумісності (якщо десь у коді ще треба просто список назв)
    final List<String> parsedGamesNames = parsedGamesWithDetails.map((g) => g['name']!).toList();

    return GamerProfile(
      id: json['id'],
      nickname: json['nickname']?.toString() ?? 'Unknown',
      avatar: json['avatar']?.toString(),
      isPro: json['is_pro'] == true,

      // Встановлюємо нову структуру
      gamesWithDetails: parsedGamesWithDetails,
      // gamesList залишається для сумісності (якщо метод сортування ще його потребує)
      gamesList: parsedGamesNames,

      mainGame: parsedGamesNames.isNotEmpty ? parsedGamesNames.first : 'None',

      tags: json['styles'] is List
          ? (json['styles'] as List).map((s) => s['style'].toString()).toList()
          : [],

      platform: 'Unknown',
      chatType: 'Text',

      languages: json['languages'] is List
          ? (json['languages'] as List)
          .where((item) => item is Map && item.containsKey('lang'))
          .map((item) => item['lang'].toString())
          .toList()
          : [],

      hasVoice: json['voice_chat'] == true,
      isOnline: json['is_online'] == true,

      platformsList: json['platforms'] is List
          ? (json['platforms'] as List)
          .where((item) => item is Map && item.containsKey('platform'))
          .map((item) => item['platform'].toString())
          .toList()
          : [],

      connectedPlatforms: json['accounts'] is List
          ? Map.fromEntries((json['accounts'] as List)
          .where((item) => item is Map && item.containsKey('service') && item.containsKey('username'))
          .map((item) => MapEntry(item['service'].toString(), item['username'].toString())))
          : {},

      times: json['availability'] is List
          ? (json['availability'] as List)
          .where((item) => item is Map && item.containsKey('utc_hour'))
          .map((item) => (item['utc_hour'] as num).toInt())
          .toList()
          : [],

      password: '',
    );
  }

  // Розрахунок балів матчу
  int calculateMatchScore(GamerProfile myProfile) {
    int score = 0;

    // 1. Ігри (ФУНДАМЕНТ)
    var myGameNames = myProfile.gamesWithDetails.map((g) => g['name']).toSet();

    var commonGames = gamesWithDetails.where((g) => myGameNames.contains(g['name'])).toList();

    if (commonGames.isEmpty) return -1; // Матч неможливий, якщо немає спільних ігор

    score += (commonGames.length * 100);

    // 2. Онлайн статус
    if (isOnline) score += 60;
    else score -= 20;

    // 3. PRO-статус
    if (isPro) score += 40;

    // 4. Мова
    var commonLanguages = languages.where((l) => myProfile.languages.contains(l)).toList();
    score += (commonLanguages.length * 30);

    // 5. Войс чат
    if (hasVoice == myProfile.hasVoice) score += 20;

    // 6. Платформи
    var commonPlatforms = platformsList.where((p) => myProfile.platformsList.contains(p)).toList();
    score += (commonPlatforms.length * 15);

    // 7. Стилі гри
    var commonStyles = tags.where((s) => myProfile.tags.contains(s)).toList();
    score += (commonStyles.length * 10);

    // 8. Час
    var commonTimes = times.where((t) => myProfile.times.contains(t)).toList();
    score += (commonTimes.length * 5);

    return score;
  }

  String getBestGame(List<String> myActiveFilters) {
    // Тепер використовуємо gamesWithDetails (список Map)
    if (gamesWithDetails.isEmpty) return 'No games';

    // 1. Спочатку пробуємо знайти ту гру, яка збігається з активними фільтрами
    for (var gameMap in gamesWithDetails) {
      String gameName = gameMap['name'] ?? '';
      if (myActiveFilters.contains(gameName)) {
        return gameName;
      }
    }

    // 2. Якщо збігів немає, повертаємо назву першої гри зі списку
    return gamesWithDetails.first['name'] ?? 'No games';
  }

  int getExtraMatchesCount(List<String> myGames) {
    // Ми шукаємо назви ігор у списку Map (gamesWithDetails)
    // myGames — це список рядків (назв ігор)
    var common = gamesWithDetails
        .where((gameMap) => myGames.contains(gameMap['name']))
        .toList();

    return common.length > 1 ? common.length - 1 : 0;
  }
}

class MatchProfile {
  final int id;
  final String nickname;
  final String? avatar;
  final bool isOnline;
  final bool isPro;
  final List<dynamic> games; // Список ігор
  final List<String> languages;
  final List<String> styles;
  final List<String> platforms;
  final List<int> availability;
  final Map<String, String> connectedPlatforms;

  MatchProfile({
    required this.id,
    required this.nickname,
    this.avatar,
    required this.isOnline,
    required this.isPro,
    required this.games,
    required this.languages,
    required this.styles,
    required this.platforms,
    required this.availability,
    required this.connectedPlatforms,
  });

  factory MatchProfile.fromJson(Map<String, dynamic> json) {
    return MatchProfile(
      id: json['id'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      isOnline: json['is_online'] == true,
      isPro: json['is_pro'] == true,
      games: json['games'] ?? [],
      languages: (json['languages'] as List).map((item) => item['lang'] as String).toList(),
      styles: (json['styles'] as List).map((item) => item['style'] as String).toList(),
      platforms: (json['platforms'] as List).map((item) => item['platform'] as String).toList(),
      availability: (json['availability'] as List).map((item) => (item['utc_hour'] as num).toInt()).toList(),
      connectedPlatforms: json['accounts'] != null
          ? Map.fromEntries((json['accounts'] as List)
          .map((item) => MapEntry(item['service'].toString(), item['username'].toString())))
          : {},
    );
  }
}

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  Future<void> _loadUserProfile() async {
    try {
      // 1. Отримуємо ID користувача, який ми зберегли при логіні
      final userId = await UserSession.getUserId();
      if (userId == null) return;

      // 2. Робимо запит до вашого бекенду
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'), // або ваш ендпоінт для профілю
        headers: {"Content-Type": "application/json"},
      );

      debugPrint('Статус відповіді: ${response.statusCode}');
      debugPrint('Тіло відповіді: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final profile = GamerProfile.fromJson(data);
        print("Профіль успішно створено! Нікнейм: ${profile.nickname}, Мови: ${profile.languages}");
        // 3. Тепер безпечно ініціалізуємо профіль
        setState(() {
          UserSession().currentUser = GamerProfile.fromJson(data);
          // Оновлюємо _myAvailableGames як список MAP, а не рядків
          _myAvailableGames = (UserSession().currentUser?.gamesWithDetails ?? []).map((g) => {
            'name': g['name'] ?? '',
            'image': g['image'] ?? ''
          }).toList();
        });

        _loadGamers(); // Завантажуємо стрічку після того, як отримали дані профілю
      }
    } catch (e) {
      print("Помилка завантаження профілю: $e");
    }
  }

  List<GamerProfile> _sortGamersByMatch(List<GamerProfile> allGamers) {
    final me = UserSession().currentUser;
    if (me == null) return allGamers;

    // Витягуємо список назв моїх ігор для швидкого порівняння
    final myGameNames = me.gamesWithDetails.map((g) => g['name']).toSet();

    // 1. Фільтруємо: шукаємо, чи є хоча б одна назва гри в списку ігор іншого гравця
    List<GamerProfile> matches = allGamers.where((g) =>
        g.gamesWithDetails.any((game) => myGameNames.contains(game['name']))
    ).toList();

    // 2. Сортуємо
    matches.sort((a, b) {
      return b.calculateMatchScore(me).compareTo(a.calculateMatchScore(me));
    });
    return matches;
  }

  bool _isNotificationsOpen = false;
  bool _hasUnreadNotifications = true;
  List<GamerProfile> _loadedGamers = [];

  // 1. Додаємо список для ігор поточного користувача
  List<Map<String, String>> _myAvailableGames = <Map<String, String>>[];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadGamers() async {
    try {
      final userId = await UserSession.getUserId();
      if (userId == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/find-matches?current_user_id=$userId'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // 1. Спочатку парсимо дані в MatchProfile
        List<MatchProfile> matches = data.map((json) => MatchProfile.fromJson(json)).toList();

        // 2. Тепер перетворюємо їх у GamerProfile, використовуючи РЕАЛЬНІ дані з 'm'
        setState(() {
          _loadedGamers = matches.map((m) => GamerProfile(
            id: m.id,
            nickname: m.nickname,
            avatar: m.avatar,
            isPro: m.isPro,
            isOnline: m.isOnline,
            platform: m.platforms.isNotEmpty ? m.platforms.first : 'Unknown',
            chatType: 'Text',
            tags: m.styles,
            languages: m.languages,
            hasVoice: false,
            connectedPlatforms: m.connectedPlatforms,

            // ПЕРЕДАЄМО ОБИДВА ПОЛЯ:
            // 1. Нова структура для картинок:
            gamesWithDetails: m.games.map((g) => {
              'name': g['game']['name'].toString(),
              'image': g['game']['image_url'].toString(),
            }).toList(),

            // 2. Стара структура для фільтрів/сортування:
            gamesList: m.games.map((g) => g['game']['name'].toString()).toList(),

            platformsList: m.platforms,
            times: m.availability,
            password: '',
          )).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading matches: $e");
    }
  }


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

    final currentUser = UserSession().currentUser;

    List<GamerProfile> filteredGamers = _loadedGamers.where((gamer) {
      if (currentUser != null && gamer.nickname == currentUser.nickname) {
        return false;
      }

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
                    itemBuilder: (context, index) { // context доступний тут!
                      return GamerCard(
                        profile: filteredGamers[index],
                        accentColor: accentColor,
                        activeGames: _confirmedActiveGames,
                        parentContext: context, // Передаємо сюди
                      );
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
    // Використовуємо _myAvailableGames замість _userSavedGames
    List<Map<String, String>> searchedGames = _myAvailableGames.where((gameMap) {
      return gameMap['name']!.toLowerCase().contains(_searchController.text.toLowerCase());
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
                  // Припустимо, тепер у вас список Map
                  final game = searchedGames[index];
                  final String gameName = game['name']!;
                  final String gameImage = game['image']!;
                  final isSelected = _temporarilySelectedGames.contains(gameName);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _temporarilySelectedGames.remove(gameName);
                        } else {
                          _temporarilySelectedGames.add(gameName);
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
                              // ТУТ МИ МІНЯЄМО ІКОНКУ НА КАРТИНКУ:
                              Expanded(
                                child: gameImage.isNotEmpty
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    gameImage,
                                    width: double.infinity, // Розтягується на всю ширину контейнера
                                    height: double.infinity,
                                    fit: BoxFit.cover, // Заповнює область гарно
                                    errorBuilder: (c, o, s) => const Icon(Icons.gamepad, color: Colors.white30, size: 28),
                                  ),
                                )
                                    : const Icon(Icons.gamepad, color: Colors.white30, size: 28),
                              ),

                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  gameName,
                                  textAlign: TextAlign.center,
                                  maxLines: 2, // Дозволяємо назві займати до 2 рядків
                                  overflow: TextOverflow.ellipsis, // Якщо назва задовга — додасть "..."
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF00F5A0) : Colors.white,
                                    fontSize: 13,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4), // Невеличкий відступ знизу, щоб текст не "прилипав" до краю
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
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
  final BuildContext parentContext; // Додали context як аргумент

  const GamerCard({
    super.key,
    required this.profile,
    required this.accentColor,
    required this.activeGames,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final String bestGame = profile.getBestGame(activeGames);
    final int extraCount = profile.getExtraMatchesCount(activeGames);

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
                        width: 64,
                        height: 64,
                        // Перетворюємо CSS властивості на BoxDecoration
                        decoration: BoxDecoration(
                          color: const Color(0xFF181826), // background
                          borderRadius: BorderRadius.circular(100), // border-radius
                          boxShadow: [
                            BoxShadow(
                              // Якщо онлайн — яскраве акцентне сяйво
                              // Якщо офлайн — глибока, "важча" сіра тінь (менше радіус, більше кольору)
                              color: profile.isOnline
                                  ? accentColor.withValues(alpha: 0.4) // Яскравіше для онлайн
                                  : const Color(0xFF505060).withValues(alpha: 0.4), // Темніший сірий для офлайн
                              blurRadius: profile.isOnline ? 4 : 2, // Менше розмиття для офлайн — тінь стає чіткішою
                              spreadRadius: profile.isOnline ? 2 : 3, // Не розповсюджуємо тінь для офлайн
                            ),
                          ],
                        ),
                        // Властивості Flex для центрування тексту ("S")
                        child:(profile.avatar != null && profile.avatar!.isNotEmpty)
                            ? ClipOval(
                          child: Image.asset(
                            profile.avatar!,
                            fit: BoxFit.cover,
                            width: 72,
                            height: 72,
                          ),
                        )

                        :Center(
                          child: Text(
                            // Беремо першу літеру і переводимо у верхній регістр
                            profile.nickname.isNotEmpty
                                ? profile.nickname[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontFamily: 'Love Light',
                              fontSize: 30,
                              fontWeight: FontWeight.w400,
                              color: profile.isOnline
                                  ? const Color(0xFF00F5A0)
                                  : const Color(0xFF8E8EA9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                  // ПРАВА ЧАСТИНА: Нік, Гра, Теги

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Рядок з іменем та тегом PRO
                        Padding(
                          padding: const EdgeInsets.only(right: 60), // "Стіна" для захисту від зірочки
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.nickname,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              if (profile.isPro) ...[
                                const SizedBox(width: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [accentColor, Color(0xFF0066FF)]),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 7), // Трохи простору під ніком

                        Text(
                          bestGame,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                        ),

                        if (extraCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              extraCount == 1 ? '+1 more match' : '+$extraCount more matches',
                              style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),

                        const SizedBox(height: 4),

                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: profile.tags.map((t) => _buildTag(t)).toList(),
                        ),

                        const SizedBox(height: 4),

                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: profile.platformsList.map((p) => _buildTag(p)).toList(),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Languages: ${profile.languages.join(" • ")}',
                          style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Positioned(
                top: 7,
                right: 0,
                child: Row(
                  children: [
                    FigmaRatingStar(isFilled: true, size: 11),
                    SizedBox(width: 4),
                    Text(
                        'PRO only',
                        style: TextStyle(
                            color: Color(0xFF8E8EA9),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 7
                        )
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _buildButton('View profile', false)),
            const SizedBox(width: 12),
            Expanded(child: _buildButton('Invite to play', true))
          ]),
        ],
      ),
    );
  }
  //Логіка обрізання тексту

  Map<String, dynamic> _getGameDisplayInfo(List<String> gamerProfileGames, List<String> activeGames) {
    // 1. Визначаємо, які ігри рахувати як матчі:
    // Якщо користувач вибрав фільтр (activeGames), то матчі - це перетин ігор гравця і фільтра.
    // Якщо фільтр порожній, то матчі - це перетин ігор гравця і ВАШИХ ігор (_myAvailableGames)

    // ПРИМІТКА: Для доступу до _myAvailableGames, якщо воно не передається,
    // нам треба переконатися, що логіка перетину правильна.

    // Виправляємо: беремо ваші ігри з UserSession (це список усіх ваших ігор)
    final myGames = UserSession().currentUser?.gamesList ?? [];

    // Формуємо список ігор, які дійсно є і у вас, і у гравця
    List<String> common = gamerProfileGames.where((g) => myGames.contains(g)).toList();

    // Якщо активовано фільтр пошуку (наприклад, тільки Apex), звужуємо ще сильніше
    if (activeGames.isNotEmpty) {
      common = common.where((g) => activeGames.contains(g)).toList();
    }

    // 2. Формуємо рядок
    List<String> displayList = common.take(2).toList();
    String result = displayList.join(', '); // Змінив " — " на ", "

    // 3. Обрізаємо, якщо текст довгий
    bool isTruncated = false;
    if (result.length > 27) {
      result = '${result.substring(0, 24)}...';
      isTruncated = true;
    }

    return {
      'text': result.isEmpty ? 'No matches' : result,
      'count': common.length,
      'isTruncated': isTruncated
    };
  }

  Widget _buildLetterAvatar() {
    return Center(
      child: Text(
          profile.nickname[0].toUpperCase(),
          style: TextStyle(
              fontFamily: 'Love Light',
              fontSize: 34,
              color: profile.isOnline ? accentColor : const Color(0xFF8E8EA9)
          )
      ),
    );
  }

  Widget _buildButton(String label, bool isAccent) {
    return GestureDetector(
      onTap: () {
        if (label == 'View profile') {
          Navigator.push(
            parentContext, // Використовуємо переданий контекст
            MaterialPageRoute(
              builder: (context) => GamerProfileScreen(profile: profile),
            ),
          );
        } else if (label == 'Invite to play') {
          debugPrint("Invite sent to ${profile.nickname}");
        }
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
            color: isAccent ? accentColor : Colors.transparent,
            border: isAccent ? null : Border.all(color: accentColor),
            borderRadius: BorderRadius.circular(12)
        ),
        child: Center(
            child: Text(
                label,
                style: TextStyle(color: isAccent ? const Color(0xFF0F0F1A) : accentColor, fontWeight: FontWeight.w700, fontSize: 15)
            )
        ),
      ),
    );
  }

  Widget _buildTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFF2B2B3B), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
  );
}

