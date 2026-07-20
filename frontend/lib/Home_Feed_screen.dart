import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'notifications_overlay.dart';
import 'custom_widgets.dart';
import 'gamer_profile_screen.dart';
import 'user_session.dart';
import 'api_config.dart';
import 'edit_game_selection_screen.dart';
import 'package:flutter/gestures.dart';
import 'api_service.dart';
import 'new_chat_room_screen.dart';
import 'services/chat_manager.dart';


class GamerProfile {
  final int id;
  final String nickname;
  final String email;
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
  final double rating;
  final String password;
  final int timezoneOffset;

  GamerProfile({
    required this.id,
    required this.nickname,
    required this.email,
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
    this.rating = 0,
    required this.password,
    this.timezoneOffset = 0,
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
    print("--- DEBUG JSON START ---");
    print(json);
    print("--- DEBUG JSON END ---");
    return GamerProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nickname: (json['nickname'] ?? 'Unknown').toString(),
      email: (json['email'] ?? '').toString(),
      avatar: json['avatar']?.toString(),
      isPro: json['is_pro'] == true,

      // Парсимо ігри з урахуванням того, що прийшло в консолі
      gamesWithDetails: (json['games'] as List?)
          ?.map((item) => {
        'name': item['game']['name']?.toString() ?? 'Unknown',
        'image': item['game']['image_url']?.toString() ?? '',
      })
          .toList() ?? [],

      gamesList: (json['games'] as List?)
          ?.map((item) => item['game']['name'].toString())
          .toList() ?? [],

      mainGame: (json['games'] as List?)?.isNotEmpty == true
          ? (json['games'] as List).first['game']['name'].toString()
          : 'None',

      tags: (json['styles'] as List?)?.map((s) => s['style'].toString()).toList() ?? [],
      platform: 'Unknown',
      chatType: 'Text',
      languages: (json['languages'] as List?)?.map((l) => l['lang'].toString()).toList() ?? [],
      hasVoice: json['voice_chat'] == true,
      isOnline: json['is_online'] == true,
      platformsList: (json['platforms'] as List?)?.map((p) => p['platform'].toString()).toList() ?? [],
      connectedPlatforms: (json['accounts'] as List?)?.fold<Map<String, String>>({}, (map, item) {
        map[item['service'].toString()] = item['username'].toString();
        return map;
      }) ?? {},
      times: (json['availability'] as List?)?.map((a) => (a['utc_hour'] as num).toInt()).toList() ?? [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      password: '',
      timezoneOffset: json['timezone_offset'] ?? 0,
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

  String getBestGame(List<String> activeFilters) {
    if (gamesWithDetails.isEmpty) return 'No games';

    // 1. Отримуємо список ВАШИХ ігор (з сесії)
    final myGames = UserSession().currentUser?.gamesList ?? [];

    // 2. Створюємо список ігор, які є спільними у нас з гравцем
    final commonGames = gamesWithDetails
        .where((g) => myGames.contains(g['name']))
        .toList();

    // 3. Якщо є активний фільтр (activeFilters), намагаємося знайти гру,
    // яка є і спільною, і входить у фільтр
    if (activeFilters.isNotEmpty) {
      final filteredCommon = commonGames.where((g) => activeFilters.contains(g['name'])).toList();
      if (filteredCommon.isNotEmpty) {
        return filteredCommon.first['name'] ?? 'Unknown';
      }
    }

    // 4. Якщо фільтрів немає, або вони не збігаються,
    // повертаємо першу зі списку СПІЛЬНИХ ігор
    if (commonGames.isNotEmpty) {
      return commonGames.first['name'] ?? 'Unknown';
    }

    // 5. Якщо взагалі немає спільних ігор (хоча матчі фільтруються за цим),
    // повертаємо першу з будь-яких його ігор
    return gamesWithDetails.first['name'] ?? 'Unknown';
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
  final double rating;

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
    required this.rating,
  });

  factory MatchProfile.fromJson(Map<String, dynamic> json) {
    debugPrint("DEBUG JSON RATING: ${json['rating']}");
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
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});


  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true; // Кажемо Flutter "тримай цей екран у пам'яті"


  Future<void> _loadUserProfile() async {
    try {
      // 1. Отримуємо ID користувача, який ми зберегли при логіні
      final userId = await UserSession.getUserId();
      if (userId == null) return;

      // 2. Отримуємо збережений токен (припустімо, що у вас є метод getToken, за аналогією до getUserId)
      final token = await UserSession.getToken();

      // 3. Робимо запит до бекенду з додаванням заголовка Authorization
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      debugPrint('Статус відповіді: ${response.statusCode}');
      debugPrint('Тіло відповіді: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final profile = GamerProfile.fromJson(data);
        print("Профіль успішно створено! Нікнейм: ${profile.nickname}, Мови: ${profile.languages}");

        setState(() {
          UserSession().currentUser = GamerProfile.fromJson(data);
          _myAvailableGames = (UserSession().currentUser?.gamesWithDetails ?? []).map((g) => {
            'name': g['name'] ?? '',
            'image': g['image'] ?? ''
          }).toList();
        });

        _loadGamers(); // Завантажуємо стрічку після отримання профілю
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
  bool _hasUnreadNotifications = false;
  List<GamerProfile> _loadedGamers = [];
  bool _isLoadingGamers = true;
  double _minRatingFilter = 0.0;
  String _activeNotificationTab = 'All';


  // 1. Додаємо список для ігор поточного користувача
  List<Map<String, String>> _myAvailableGames = <Map<String, String>>[];

  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    //Clean the matchs
    AppState.shownIds.clear();
    // Викликаємо дані лише якщо вони порожні
    if (UserSession().currentUser == null) {
      _loadUserProfile();
    } else if (_loadedGamers.isEmpty) {
      _loadGamers(); // Якщо профіль є, а матчів немає — завантажуємо
    }

    _fetchNotifications();
    _syncService.startSync(() {
      if (mounted) _fetchNotifications();
    });

    ChatManager().socket?.on('new_notification', (data) {
      debugPrint("DEBUG: Прийшла нова нотифікація через сокет: $data");
      if (mounted) {
        // Можна або викликати _fetchNotifications(),
        // або просто додати нову нотифікацію в список:
        _handleNewNotification(data);
      }
    });
  }

  void _handleNewNotification(dynamic data) {
    final newNotif = NotificationModel.fromJson(data);

    // Перевіряємо, чи немає вже нотифікації з таким ID
    bool exists = _notifications.any((n) => n.id == newNotif.id);

    if (!exists) {
      setState(() {
        _notifications.insert(0, newNotif);
        _hasUnreadNotifications = true;
      });
    }
  }


  Future<void> _loadGamers() async {
    if (!mounted) return;
    setState(() => _isLoadingGamers = true);
    try {
      final userId = await UserSession.getUserId();
      if (userId == null) return;

      // 1. Формуємо базовий URL
      String url = '${ApiConfig.baseUrl}/find-matches?current_user_id=$userId';

      // 2. Якщо бекенд не вміє парсити "4,2", відправте ID по одному:
      // ?excluded_ids=4&excluded_ids=2
      if (AppState.shownIds.isNotEmpty) {
        for (var id in AppState.shownIds) {
          url += '&excluded_ids=$id';
        }
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint("Отримано матчів: ${data.length}");
        List<MatchProfile> matches = data.map((json) => MatchProfile.fromJson(json)).toList();

        setState(() {
          for (var m in matches) {
            AppState.shownIds.add(m.id);
          }

          _loadedGamers = matches.map((m) {
            return GamerProfile(
              id: m.id,
              nickname: m.nickname,
              email: '',
              avatar: m.avatar,
              isPro: m.isPro,
              isOnline: m.isOnline,
              platform: m.platforms.isNotEmpty ? m.platforms.first : 'Unknown',
              chatType: 'Text',
              tags: m.styles,
              languages: m.languages,
              hasVoice: false,
              connectedPlatforms: m.connectedPlatforms,
              gamesWithDetails: m.games.map((g) => {
                'name': g['game']['name'].toString(),
                'image': g['game']['image_url'].toString(),
              }).toList(),
              gamesList: m.games.map((g) => g['game']['name'].toString()).toList(),
              platformsList: m.platforms,
              times: m.availability,
              rating: m.rating,
              password: '',
              mainGame: m.games.isNotEmpty ? m.games.first['game']['name'].toString() : 'None',
            );
          }).toList();
        });
      } else {
        debugPrint("Помилка сервера: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error loading matches: $e");
    } finally {
      setState(() => _isLoadingGamers = false);
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
    _syncService.stopSync(); // ВАЖЛИВО: зупиняємо таймер, коли екран закривається
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _confirmedActiveGames.clear();
      _temporarilySelectedGames.clear();
      _selectedPlayStyles.clear();
      _selectedPlatforms.clear();
      _voiceChatOn = false;
      _minRatingFilter = 0.0; // Скидаємо фільтр рейтингу
      AppState.shownIds.clear();
    });
  }


  List<NotificationModel> _notifications = []; // Глобальний список для HomeFeed

  Future<void> _fetchNotifications() async {
    try {
      final List<dynamic> data = await ApiService.getNotifications();
      if (mounted) {
        setState(() {
          final newNotifications = data.map((json) => NotificationModel.fromJson(json)).toList();

          // 1. ПЕРЕВІРКА НА НОВЕ:
          // Якщо кількість повідомлень стала більшою, ніж була раніше,
          // значить, прийшло щось нове — запалюємо крапку!
          if (newNotifications.length > _notifications.length) {
            _hasUnreadNotifications = true;
          }

          // 2. Якщо ми відкрили оверлей, ми "прочитали" все, що там було
          if (_isNotificationsOpen) {
            _hasUnreadNotifications = false;
          }

          _notifications = newNotifications;
        });
      }
    } catch (e) {
      print("Помилка: $e");
    }
  }

  void _archiveCurrentTab() {
    setState(() {
      if (_activeNotificationTab == 'All') {
        _notifications.clear();
      } else {
        NotificationType? typeToClear;
        if (_activeNotificationTab == 'Match') typeToClear = NotificationType.match;
        if (_activeNotificationTab == 'Rating') typeToClear = NotificationType.rating;
        if (_activeNotificationTab == 'PRO') typeToClear = NotificationType.pro;

        if (typeToClear != null) {
          _notifications.removeWhere((n) => n.type == typeToClear);
        }
      }
    });
  }

  Widget _buildLetterAvatar(String nickname) {
    return Center(
      child: Text(
        nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
        style: const TextStyle(
          fontFamily: 'Love Light',
          fontSize: 18, // Можна налаштувати розмір під 33х33 контейнер
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
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
      if (_minRatingFilter > 0) {
        if (gamer.rating < _minRatingFilter) return false;
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Your matches',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () {
                            _resetFilters();
                            //_loadUserProfile();
                            _loadGamers();
                          },
                          // Прибираємо Container з BoxDecoration зовсім
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: RefreshIcon(color: accentColor, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoadingGamers
                      ? const Center(child: CircularProgressIndicator(color: accentColor))
                      : _loadedGamers.isEmpty
                      ? const Center(
                    child: Text(
                      'No matches for your games',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8E8EA9),
                        fontFamily: 'Poppins',
                        fontSize: 16,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: filteredGamers.length,
                    itemBuilder: (context, index) {
                      final gamer = filteredGamers[index];
                      final bool isInviteAllowed = UserSession.instance.canInvite(gamer.id);

                      return GamerCard(
                        profile: gamer,
                        accentColor: accentColor,
                        activeGames: _confirmedActiveGames,
                        parentContext: context,
                        onUpdate: () {
                          if (mounted) setState(() {});
                        },
                        isInviteAllowed: isInviteAllowed, // Новий параметр
                        onInviteSent: () {
                          setState(() {
                            UserSession.instance.registerInvite(gamer.id);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_isGameDropdownOpen) _buildGamesDropdown(),
            Visibility(
              visible: _isNotificationsOpen,
              child: Positioned(
                top: 50,
                left: 24,
                right: 24,
                child: NotificationsOverlay(
                  notifications: _notifications,
                  onClose: () => setState(() => _isNotificationsOpen = false),
                  activeTab: _activeNotificationTab, // Додайте цю змінну в стан State
                  onTabChange: (tab) => setState(() => _activeNotificationTab = tab),
                  onAccept: (item) async {
                    // Викликаємо оновлений метод
                    final response = await ApiService.acceptGameInvite(item.id);

                    if (response != null && response.containsKey('chat_id') && mounted) {
                      String chatId = response['chat_id']; // Беремо ID чату з відповіді

                      // Видаляємо з UI
                      setState(() => _notifications.removeWhere((n) => n.id == item.id));

                      // Закриваємо оверлей
                      setState(() => _isNotificationsOpen = false);

                      // Відкриваємо чат
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatRoomScreen(
                            friendName: item.userNickname,
                            chatId: chatId,
                            friendId: item.senderId,
                            onBack: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    } else {
                      // Обробка помилки
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Could not accept invite")),
                      );
                    }
                  },
                  onRemove: (id) async {
                    // ЗАМІСТЬ deleteNotification, викликаємо архівування:
                    bool success = await ApiService.archiveNotification(id);
                    if (success && mounted) {
                      _fetchNotifications(); // Список оновиться і нотифікація зникне завдяки фільтру is_archived == False
                    }
                  },
                  onArchiveAll: (List<String> ids, String tabName) async {
                    // Перетворюємо назву таби на тип, який розуміє бекенд (наприклад, 'Match' -> 'match')
                    // Якщо таба 'All', передаємо null або нічого не передаємо
                    String? typeParam = tabName == 'All' ? null : tabName.toLowerCase();

                    // Викликаємо нову версію API
                    bool success = await ApiService.archiveAllNotifications(notificationType: typeParam);

                    if (success && mounted) {
                      _fetchNotifications();
                    }
                  },
                  onProfileTap: (int gamerId) async {
                    // 1. Отримуємо повний профіль гравця за його ID (або беремо з _loadedGamers)
                    final profile = _loadedGamers.firstWhere((g) => g.id == gamerId);

                    // 2. Навігація
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GamerProfileScreen(profile: profile),
                      ),
                    ).then((_) {
                      // Коли користувач повертається з профілю,
                      // оверлей або сам HomeFeed оновиться
                      if (mounted) setState(() {});
                    });
                  },
                  onDecline: (item) async {
                    // ЦЕ НОВА ЛОГІКА: статус "declined" для сендера
                    bool success = await ApiService.updateNotificationStatus(item.id, "declined");
                    if (success) {
                      _fetchNotifications(); // Оновлюємо, щоб сендер побачив "declined"
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(Color accentColor) {
    final currentUser = UserSession().currentUser;
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
            // 2. Логіка відображення аватарки
            child: ClipOval(
              child: (currentUser != null && currentUser.avatar != null && currentUser.avatar!.isNotEmpty)
                  ? Image.asset(
                currentUser.avatar!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(currentUser.nickname),
              )
                  : _buildLetterAvatar(currentUser?.nickname ?? '?'), // ВИПРАВЛЕНО ТУТ
            ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 600, // Максимальна висота, після якої з'явиться прокрутка
        ),
        child: Container(
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
            mainAxisSize: MainAxisSize.min, // Колонка стискається під вміст
            children: [
              Flexible(
                child: searchedGames.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No matching games found.',
                    style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 13),
                  ),
                )
                    : GridView.builder(
                  shrinkWrap: true, // GridView займає рівно стільки місця, скільки треба
                  physics: const BouncingScrollPhysics(), // Плавна прокрутка
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: searchedGames.length,
                  itemBuilder: (context, index) {
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
                                Expanded(
                                  child: gameImage.isNotEmpty
                                      ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      gameImage,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF00F5A0) : Colors.white,
                                      fontSize: 13,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: "Don’t see your game here?\n",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                              color: Color(0xFF8E8EA9),
                            ),
                          ),
                          const TextSpan(
                            text: "Manage your games in ",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              color: Color(0xFF8E8EA9),
                            ),
                          ),
                          TextSpan(
                            text: 'Settings',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00F5A0),
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                setState(() {
                                  _isGameDropdownOpen = false;
                                });
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const EditGameSelectionScreen()),
                                );
                                _loadUserProfile();
                              },
                          ),
                        ],
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
                      width: 75,
                      height: 45,
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
                            fontSize: 16,
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
          //Rating Filter
          Row(
            children: [
              const Text(
                'Rating',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 16),
              ),
              const SizedBox(width: 10),
              // Якщо користувач PRO — показуємо ваші FigmaRatingStar, інакше — замок
              if (UserSession().currentUser?.isPro ?? false) ...[
                ...List.generate(5, (index) {
                  final starValue = (index + 1).toDouble();
                  return GestureDetector(
                    onTap: () => setState(() {
                      // Перемикач: вибір зірки або скидання фільтра
                      _minRatingFilter = (_minRatingFilter == starValue) ? 0.0 : starValue;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FigmaRatingStar(
                        size: 16,
                        // Зірка заповнена, якщо її значення <= обраному фільтру
                        isFilled: _minRatingFilter >= starValue,
                      ),
                    ),
                  );
                }),
              ] else ...[
                const Icon(Icons.lock, color: Color(0xFF6F6F80), size: 16),
                const SizedBox(width: 4),
                const Text(
                  'Unlock in PRO',
                  style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 16),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class GamerCard extends StatefulWidget {
  final GamerProfile profile;
  final Color accentColor;
  final List<String> activeGames;
  final BuildContext parentContext; // Додали context як аргумент
  final VoidCallback onUpdate;
  final bool isInviteAllowed;
  final VoidCallback onInviteSent;


  const GamerCard({
    super.key,
    required this.profile,
    required this.accentColor,
    required this.activeGames,
    required this.parentContext,
    required this.onUpdate,
    required this.isInviteAllowed,
    required this.onInviteSent,
  });

  @override
  State<GamerCard> createState() => _GamerCardState();
}

class _GamerCardState extends State<GamerCard> {

  @override
  Widget build(BuildContext context) {
    final String bestGame = widget.profile.getBestGame(widget.activeGames);
    final int extraCount = widget.profile.getExtraMatchesCount(widget.activeGames);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(16),
        border: widget.profile.isPro ? Border.all(color: widget.accentColor.withValues(alpha: 0.2), width: 1.5) : null,
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
                              color: widget.profile.isOnline
                                  ? widget.accentColor.withValues(alpha: 0.4) // Яскравіше для онлайн
                                  : const Color(0xFF505060).withValues(alpha: 0.4), // Темніший сірий для офлайн
                              blurRadius: widget.profile.isOnline ? 4 : 2, // Менше розмиття для офлайн — тінь стає чіткішою
                              spreadRadius: widget.profile.isOnline ? 2 : 3, // Не розповсюджуємо тінь для офлайн
                            ),
                          ],
                        ),
                        child: (widget.profile.avatar != null && widget.profile.avatar!.isNotEmpty)
                            ? ClipOval(
                          child: Image.asset(
                            widget.profile.avatar!,
                            fit: BoxFit.cover,
                            width: 72,
                            height: 72,
                          ),
                        )
                            : _buildLetterAvatar(widget.profile.nickname, widget.profile.isOnline),
                      ),
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.profile.isOnline ? widget.accentColor : const Color(0xFF8E8EA9), shape: BoxShape.circle)), const SizedBox(width: 8), Text(widget.profile.isOnline ? 'Online' : 'Offline', style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 13, fontWeight: FontWeight.w500))]),
                          const SizedBox(height: 10),
                          Row(children: [Icon(widget.profile.hasVoice ? Icons.mic : Icons.mic_off, color: widget.profile.hasVoice ? widget.accentColor : const Color(0xFF8E8EA9), size: 16), const SizedBox(width: 6), Text('Voice', style: TextStyle(color: widget.profile.hasVoice ? widget.accentColor : const Color(0xFF8E8EA9), fontSize: 13, fontWeight: FontWeight.w500))]),
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
                                  widget.profile.nickname,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              if (widget.profile.isPro) ...[
                                const SizedBox(width: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [widget.accentColor, Color(0xFF0066FF)]),
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
                          children: widget.profile.tags.map((t) => _buildTag(t)).toList(),
                        ),

                        const SizedBox(height: 4),

                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.profile.platformsList.map((p) => _buildTag(p)).toList(),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Languages: ${widget.profile.languages.join(" • ")}',
                          style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                Positioned(
                top: 2,
                right: 0,
                child: Row(
                  children: [
                    FigmaRatingStar(isFilled: true, size: 14),
                    SizedBox(width: 4),
                    Text(
                      (UserSession().currentUser?.isPro ?? false)
                          ? widget.profile.rating.toStringAsFixed(1)
                          : 'PRO only',
                      style: TextStyle(
                        color: (UserSession().currentUser?.isPro ?? false)
                            ? const Color(0xFF00F5A0) // колір рейтингу
                            : const Color(0xFF8E8EA9), // колір PRO only
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        // Логіка розміру:
                        fontSize: (UserSession().currentUser?.isPro ?? false) ? 15 : 10,
                      ),
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

  Widget _buildLetterAvatar(String nickname, bool isOnline) {
    return Center(
      child: Text(
        nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
        style: TextStyle(
          fontFamily: 'Love Light',
          fontSize: 30, // Можете поставити 34, як у вас в методі було
          fontWeight: FontWeight.w400,
          color: isOnline ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9),
        ),
      ),
    );
  }

  Widget _buildButton(String label, bool isAccent) {
    // Визначаємо, чи це кнопка інвайту
    final bool isInviteButton = label == 'Invite to play';
    // Кнопка заблокована, якщо це інвайт ТА він заборонений (widget.isInviteAllowed == false)
    final bool isDisabled = isInviteButton && !widget.isInviteAllowed;

    return GestureDetector(
      // Якщо isDisabled — onTap повертає null, кнопка не клікабельна
      onTap: isDisabled
          ? null
          : () async {
        if (label == 'View profile') {
          await Navigator.push(
            widget.parentContext,
            MaterialPageRoute(builder: (context) => GamerProfileScreen(profile: widget.profile)),
          ).then((_) {
            // Ось тут правильний виклик callback-у:
            widget.onUpdate();
          });
        } else if (label == 'Invite to play') {
          await _showInviteDialog(context, widget.profile, widget.onInviteSent);
        }
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          // Якщо кнопка заблокована - сірий колір, інакше - звичайний акцентний
          color: isDisabled
              ? Colors.grey.withOpacity(0.3)
              : (isAccent ? widget.accentColor : Colors.transparent),
          border: isAccent
              ? null
              : Border.all(color: isDisabled ? Colors.grey : widget.accentColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            isDisabled ? 'Invite to play' : label, // Текст змінюється на таймер
            style: TextStyle(
              // Колір тексту: якщо isDisabled — сірий/білий, інакше як було
              color: isDisabled
                  ? Colors.grey
                  : (isAccent ? const Color(0xFF0F0F1A) : widget.accentColor),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFF2B2B3B), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
  );

  Future<void> _showInviteDialog(BuildContext context, GamerProfile profile, VoidCallback onInviteSent) async {
    String? selectedGame;

    // Беремо спільні ігри (переконайся, що доступ до widget.profile є)
    final myGames = UserSession().currentUser?.gamesList ?? [];
    final commonGames = widget.profile.gamesList.where((g) => myGames.contains(g)).toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Локальний стан для діалогу
          bool isSending = false;

          return Dialog(
            backgroundColor: const Color(0xFF181826),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Invite to play in:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  ...commonGames.map((game) => RadioListTile<String>(
                    title: Text(game, style: const TextStyle(color: Colors.white)),
                    value: game,
                    groupValue: selectedGame,
                    onChanged: isSending ? null : (val) => setState(() => selectedGame = val),
                    activeColor: const Color(0xFF00F5A0),
                  )),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: isSending ? null : () => Navigator.pop(context),
                          child: const Text('Cancel')
                      ),
                      ElevatedButton(
                        onPressed: (selectedGame == null || isSending) ? null : () async {
                          setState(() => isSending = true);

                          // Відправляємо запит на сервер
                          bool success = await ApiService.sendInvite(widget.profile.id, selectedGame!);

                          if (success && mounted) {
                            // Успіх: оновлюємо батька і закриваємо
                            widget.onInviteSent();
                            Navigator.pop(context);
                          } else if (mounted) {
                            // Помилка: зупиняємо лоадер і показуємо SnackBar
                            setState(() => isSending = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Wait 10 minutes before next invite")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5A0)),
                        child: isSending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))
                            : const Text('Send', style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }


}

class SyncService {
  Timer? _timer;

  void startSync(Function onSync) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 90), (timer) {
      onSync();
    });
  }

  void stopSync() {
    _timer?.cancel();
  }
}

