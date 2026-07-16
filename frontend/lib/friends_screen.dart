import 'package:flutter/material.dart';
import 'custom_widgets.dart'; // Звідси беремо FigmaArrowIcon
import 'api_config.dart';
import 'api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'Home_Feed_screen.dart';
import 'gamer_profile_screen.dart';
import 'user_session.dart';
import 'new_chat_room_screen.dart';

// =============================================================================
// МОДЕЛЬ ДАНИХ ДЛЯ ЕКРАНУ
// =============================================================================
class FriendItem {
  final int userId;
  final String nickname;
  final String? avatarUrl;
  final bool isOnline;
  final bool isVoiceOn;
  final bool isPro;
  final bool isProOnly;
  final double rating;
  final String gameName;
  final String platform;
  final String playStyle;
  final int friendshipId;
  final List<String> allGames;

  const FriendItem({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.isOnline,
    required this.isVoiceOn,
    required this.isPro,
    required this.isProOnly,
    required this.rating,
    required this.gameName,
    required this.platform,
    required this.playStyle,
    required this.friendshipId,
    required this.allGames,
  });

  factory FriendItem.fromJson(Map<String, dynamic> json, {bool isRequest = false}) {
    // Якщо це запит (Requests), то дані користувача лежать у полі 'user'
    // Якщо це список друзів, дані можуть бути в корені або в 'user'
    final data = json['user'] ?? json;

    // Парсимо ВСІ ігри, а не тільки першу
    List<String> games = (data['games'] != null)
    ? (data['games'] as List).map((g) => g['game']['name'].toString()).toList()
        : [];

    return FriendItem(
      // friendshipId беремо з кореня (це id запису дружби)
      friendshipId: json['id'] ?? 0,
      userId: data['id'] ?? 0,
      nickname: data['nickname'] ?? 'Unknown',
      avatarUrl: data['avatar'],
      isOnline: data['is_online'] ?? false,
      isVoiceOn: false,
      isPro: data['is_pro'] ?? false,
      isProOnly: false,
      rating: (data['rating'] ?? 0.0).toDouble(),
      gameName: (data['games'] != null && (data['games'] as List).isNotEmpty)
          ? data['games'][0]['game']['name']
          : 'No games',
      platform: (data['platforms'] != null && (data['platforms'] as List).isNotEmpty)
          ? data['platforms'][0]['platform']
          : 'Unknown',
      playStyle: (data['styles'] != null && (data['styles'] as List).isNotEmpty)
          ? data['styles'][0]['style']
          : 'Default',
      allGames: games,
    );
  }
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _selectedTab = 0; // 0 - Friends, 1 - Requests, 2 - Blocked
  bool _hasUnreadRequests = true; // Стан для керування кружечком нотифікації
  DateTime? _lastInviteTime;

  void refreshData() {
    _loadData(); //метод для таби запитів (Requests in friends)
    _loadFriends();  //метод для таби друзів
    _loadBlocked();  //метод для таби заблокованих
  }

  Future<void> _openProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        final profile = GamerProfile.fromJson(userData);

        if (!mounted) return;

        // 1. Чекаємо, поки користувач закриє екран профілю
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GamerProfileScreen(profile: profile)),
        ).then((_) {
          setState(() {}); // Синхронізує кнопку при поверненні
        });

        // 2. Тільки ТЕПЕР оновлюємо дані (після повернення назад)
        if (mounted) {
          refreshData();
        }
      }
    } catch (e) {
      print("Помилка відкриття профілю: $e");
    }
  }
  bool _isProcessing = false;
  Future<void> _loadFriends() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/friends/list'),
        headers: await ApiService.getHeaders(),
      );
      if (response.statusCode == 200 && mounted) {
        List<dynamic> list = json.decode(response.body);
        setState(() {
          _friendsList = list.map((item) => FriendItem.fromJson(item)).toList();
        });
      }
    } catch (e) {
      debugPrint("Помилка друзів: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _loadBlocked() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/friends/blocked'),
        headers: await ApiService.getHeaders(),
      );

      print("DEBUG: Raw blocked response: ${response.body}");

      if (response.statusCode == 200 && mounted) {
        List<dynamic> list = json.decode(response.body);
        setState(() {
          _blockedList = list.map((item) => FriendItem.fromJson(item)).toList();
        });
      }
    } catch (e) {
      debugPrint("Помилка заблокованих: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startChatWithFriend(FriendItem friend) async {
    // 1. Спінер
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00F5A0))));

    try {
      // 2. Викликаємо АПІ (використовуємо той самий метод, що ми створили для профілю)
      final response = await ApiService.getOrCreateChat(friend.userId);
      final String chatId = response['chat_id'];

      if (mounted) {
        Navigator.pop(context); // Закриваємо спінер

        // 3. Відкриваємо чат
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              friendName: friend.nickname,
              chatId: chatId,
              friendId: friend.userId.toString(),
              onBack: () {
                Navigator.pop(context);
                refreshData(); // Оновлюємо список, якщо щось змінилось
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Помилка відкриття чату")));
    }
  }

  Widget _buildProBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0066FF)]),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }

  final Map<String, dynamic> myPreferences = {
    'games': ['Valorant', 'CS2'],
    'platforms': ['PC', 'PS5'],
    'styles': ['Competitive', 'Casual'],
  };

  // Списки
  List<FriendItem> _friendsList = [];
  List<FriendItem> _requestsList = [];
  List<FriendItem> _blockedList = [];

  @override
  void initState() {
    super.initState();
    _loadData();      // Запити
    _loadFriends();   // Друзі
    _loadBlocked();   // Заблоковані
  }
  Future<void> _loadData() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final reqResponse = await http.get(Uri.parse('${ApiConfig.baseUrl}/friends/requests'), headers: await ApiService.getHeaders());
      final friendsResponse = await http.get(Uri.parse('${ApiConfig.baseUrl}/friends/list'), headers: await ApiService.getHeaders());

      if (!mounted) return;

      if (reqResponse.statusCode == 200 && friendsResponse.statusCode == 200) {
        List<dynamic> reqList = json.decode(reqResponse.body);
        List<dynamic> frList = json.decode(friendsResponse.body);

        Set<int> seenRequestIds = {};
        List<FriendItem> uniqueRequests = [];
        for (var item in reqList) {
          final req = FriendItem.fromJson(item, isRequest: true);
          if (!seenRequestIds.contains(req.friendshipId)) {
            uniqueRequests.add(req);
            seenRequestIds.add(req.friendshipId);
          }
        }
        setState(() {
          _requestsList = uniqueRequests;
          _friendsList = frList.map((item) => FriendItem.fromJson(item)).toList();
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження даних: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showInviteDialog(BuildContext context, FriendItem friend, VoidCallback onInviteSent) async {
    String? selectedGame;
    final myGames = UserSession().currentUser?.gamesList ?? [];
    final commonGames = friend.allGames.where((g) => myGames.contains(g)).toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
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
                  onChanged: (val) => setModalState(() => selectedGame = val),
                  activeColor: const Color(0xFF00F5A0),
                )),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: selectedGame == null ? null : () async {
                        bool success = await ApiService.sendInvite(friend.userId, selectedGame!);
                        if (success && mounted) {
                          UserSession.instance.registerInvite(friend.userId); // Оновлюємо локально
                          onInviteSent();
                          Navigator.pop(context);
                        } else {
                          // Додаємо SnackBar, якщо сервер відмовив (наприклад 429)
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Wait 10 minutes before next invite")),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        // ОСЬ ТУТ МАГІЯ:
                        backgroundColor: (selectedGame == null)
                            ? Colors.grey.withOpacity(0.3)
                            : const Color(0xFF00F5A0),
                      ),
                      child: const Text('Send', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget activeTabContent;
    if (_selectedTab == 0) {
      activeTabContent = _buildFriendsTab();
    } else if (_selectedTab == 1) {
      activeTabContent = _buildRequestsTab();
    } else {
      activeTabContent = _buildBlockedTab();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Вкладки (Friends / Requests / Blocked) з нотифікацією
              _buildTabsRow(),
              const SizedBox(height: 15),
              // 2. Списки карток
              Expanded(
                child: activeTabContent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabsRow() {
    bool showDot = _hasUnreadRequests && _requestsList.isNotEmpty;

    return Row(
      children: [
        // Кнопка Friends
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTab = 0),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF181826),
                border: Border.all(
                  color: _selectedTab == 0 ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Friends',
                  style: TextStyle(
                    color: _selectedTab == 0 ? const Color(0xFF00F5A0) : const Color(0xFFFFFFFF),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Кнопка Requests з автоматичним зникненням кружечка при натисканні
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = 1;
                    _hasUnreadRequests = false; // Прочитано! Кружечок зникає
                  });
                },
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF181826),
                    border: Border.all(
                      color: _selectedTab == 1 ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Requests',
                      style: TextStyle(
                        color: _selectedTab == 1 ? const Color(0xFF00F5A0) : const Color(0xFFFFFFFF),
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              if (showDot)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00F5A0),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Кнопка Blocked
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedTab = 2);
              _loadBlocked(); // ПРИМУСОВИЙ ВИКЛИК ПРИ НАТИСКАННІ
            },
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF181826),
                border: Border.all(
                  color: _selectedTab == 2 ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Blocked',
                  style: TextStyle(
                    color: _selectedTab == 2 ? const Color(0xFF00F5A0) : const Color(0xFFFFFFFF),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsTab() {
    if (_friendsList.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 324,
          height: 39,
          child: Text(
            'You don’t have friends yet\n\nFind players and add them to play again later',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 13 / 14,
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 10),
        itemCount: _friendsList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildFriendCard(_friendsList[index]),
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_requestsList.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 110,
          height: 13,
          child: Text(
            'No requests yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 13 / 14,
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 10),
        itemCount: _requestsList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildRequestCard(_requestsList[index], index),
      ),
    );
  }

  Widget _buildBlockedTab() {
    if (_blockedList.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 150,
          height: 13,
          child: Text(
            'No blocked users',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 13 / 14,
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadBlocked();
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 10),
        itemCount: _blockedList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildBlockedCard(_blockedList[index], index),
      ),
    );
  }

  // =============================================================================
  // КАРТКА ДРУГА (FRIENDS TAB) - Висота 106px
  // =============================================================================
  Widget _buildFriendCard(FriendItem friend) {
    final bool amIPro = UserSession().currentUser?.isPro ?? false;
    final bool canInvite = UserSession.instance.canInvite(friend.userId);
    return Container(
      width: 327,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 10.5,
            top: 13,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openProfile(friend.userId),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF181826),
                  boxShadow: [
                    BoxShadow(
                      color: friend.isOnline ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty)
                      ? Image.asset(
                    friend.avatarUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(friend.nickname),
                  )
                      : _buildLetterAvatar(friend.nickname),
                ),
              ),
            ),
          ),
          Positioned(
            left: 60, top: 5, right: 12,
            child: Row(
              children: [
                Text(friend.nickname, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),

                if (friend.isPro) ...[
                  _buildProBadge(),
                  const SizedBox(width: 6),
                ],

                // Універсальна зірочка перед обома варіантами
                const FigmaRatingStar(isFilled: true, size: 12),
                const SizedBox(width: 3),

                // Логіка вибору тексту після зірочки
                amIPro
                    ? Text(
                    friend.rating.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700)
                )
                    : const Text(
                    'PRO only',
                    style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 9, fontWeight: FontWeight.w700)
                ),
              ],
            ),
          ),
          Positioned(
            left: 60,
            top: 26,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: friend.isOnline ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(friend.isOnline ? 'Online' : 'Offline', style: const TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 10)),
                const SizedBox(width: 48),
                Icon(friend.isVoiceOn ? Icons.mic : Icons.mic_off, color: friend.isVoiceOn ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9), size: 10),
                const SizedBox(width: 3),
                const Text('Voice', style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 10)),
              ],
            ),
          ),
          Positioned(
            left: 58,
            top: 42,
            child: Row(
              children: [
                Text(
                  friend.gameName,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 12),
                ),
                const SizedBox(width: 6),
                Container(width: 3, height: 3, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  friend.platform,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 12),
                ),
                const SizedBox(width: 6),
                Container(width: 3, height: 3, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  friend.playStyle,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 12),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            top: 66,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00F5A0), width: 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: GestureDetector(
                      onTap: () => _startChatWithFriend(friend), // <-- Додай це
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Start chat', style: TextStyle(color: Color(0xFF00F5A0), fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w500)),
                          SizedBox(width: 10),
                          FigmaArrowIcon(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 23),
                Expanded(
                  child: GestureDetector(
                      onTap: (canInvite && !_isProcessing)
                          ? () async {
                        setState(() => _isProcessing = true);
                        await _showInviteDialog(context, friend, () {
                          setState(() {
                            UserSession.instance.registerInvite(friend.userId);
                          });
                        });
                        setState(() => _isProcessing = false);
                      }
                          : null,
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          // ВИПРАВЛЕНО: Сірий колір, якщо не можна інвайтити
                          color: canInvite ? const Color(0xFF00F5A0) : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Invite to play',
                            style: TextStyle(
                              color: canInvite ? const Color(0xFF0F0F1A) : Colors.white,
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // КАРТКА ЗАПИТУ (REQUESTS TAB) - Висота 99px з функціями Accept/Decline
  // =============================================================================
  Widget _buildRequestCard(FriendItem friend, int index) {
    return Container(
      width: 327,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 11,
            top: 13,
            child: GestureDetector(
              onTap: () => _openProfile(friend.userId),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF181826),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF8E8EA9),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty)
                      ? Image.asset(
                    friend.avatarUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(friend.nickname),
                  )
                      : _buildLetterAvatar(friend.nickname),
                ),
              ),
            ),
          ),
          Positioned(
            left: 59,
            top: 5,
            right: 12,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openProfile(friend.userId),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    friend.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  if (friend.isPro) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0066FF)]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 59,
            top: 32,
            child: Text(
              '${friend.nickname} sent you a friend request',
              style: const TextStyle(
                color: Color(0xFF8E8EA9),
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 65,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final friendshipId = _requestsList[index].friendshipId;
                      final success = await ApiService.declineFriendRequest(friendshipId);

                      if (success && mounted) {
                        setState(() {
                          _requestsList.removeAt(index);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Friend request declined.')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to decline request')),
                        );
                      }
                    },
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF00F5A0), width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Decline',
                          style: TextStyle(color: Color(0xFF00F5A0), fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 23),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final friendshipId = _requestsList[index].friendshipId;
                      final success = await ApiService.acceptFriendRequest(friendshipId);

                      if (success && mounted) {
                        setState(() {
                          FriendItem accepted = _requestsList.removeAt(index);
                          _friendsList.add(accepted);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Friend request accepted!')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to accept request')),
                        );
                      }
                    },
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F5A0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Accept',
                          style: TextStyle(
                            color: Color(0xFF0F0F1A),
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // КАРТКА БЛОКУВАННЯ (BLOCKED TAB) - Точно така ж сама, як запит, але з кнопкою Unblock
  // =============================================================================
  Widget _buildBlockedCard(FriendItem friend, int index) {
    return Container(
      width: 327,
      height: 105,
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 11,
            top: 13,
            child: GestureDetector(
              onTap: () => _openProfile(friend.userId),
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF181826),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF8E8EA9),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty)
                      ? Image.asset(
                    friend.avatarUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(friend.nickname),
                  )
                      : _buildLetterAvatar(friend.nickname),
                ),
              ),
            ),
          ),
          Positioned(
            left: 59,
            top: 5,
            right: 12,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openProfile(friend.userId),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    friend.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  if (friend.isPro) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0066FF)]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 59,
            top: 32,
            child: Text(
              'You blocked ${friend.nickname}',
              style: const TextStyle(
                color: Color(0xFF8E8EA9),
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 59,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 27,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.transparent, width: 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 23),
                // Кнопка Unblock — розблоковує користувача
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final userId = _blockedList[index].userId;
                      try {
                        // Припустимо, у тебе є такий метод в ApiService, якщо ні - заміни на відповідний роут розблокування
                        final response = await http.patch(
                          Uri.parse('${ApiConfig.baseUrl}/friends/unblock/$userId'),
                          headers: await ApiService.getHeaders(),
                        );

                        if (response.statusCode == 200 && mounted) {
                          setState(() {
                            _blockedList.removeAt(index);
                          });

                          _loadFriends();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User unblocked successfully')),
                          );
                        }
                      } catch (e) {
                        print("Помилка розблокування: $e");
                      }
                    },
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F5A0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Unblock',
                          style: TextStyle(
                            color: Color(0xFF0F0F1A),
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Универсальный генератор літери з твоїм шрифтом 'Love Light' із Figma
  Widget _buildLetterAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFF00F5A0),
          fontFamily: 'Love Light',
          fontWeight: FontWeight.w400,
          fontSize: 20,
          height: 1.0,
        ),
      ),
    );
  }
}