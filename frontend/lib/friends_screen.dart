import 'package:flutter/material.dart';
import 'custom_widgets.dart'; // Звідси беремо FigmaArrowIcon

// =============================================================================
// МОДЕЛЬ ДАНИХ ДЛЯ ЕКРАНУ
// =============================================================================
class FriendItem {
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

  const FriendItem({
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
  });
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _isFriendsTab = true;
  bool _hasUnreadRequests = true; // Стан для керування кружечком нотифікації

  final Map<String, dynamic> myPreferences = {
    'games': ['Valorant', 'CS2'],
    'platforms': ['PC', 'PS5'],
    'styles': ['Competitive', 'Casual'],
  };

  // Список друзів
  final List<FriendItem> _friendsList = [
    const FriendItem(
      nickname: 'NOVA',
      avatarUrl: null,
      isOnline: true,
      isVoiceOn: true,
      isPro: true,
      isProOnly: true,
      rating: 5.0,
      gameName: 'Valorant',
      platform: 'PC',
      playStyle: 'Competitive',
    ),
    const FriendItem(
      nickname: 'ShadowNinja',
      avatarUrl: 'https://images.unsplash.com/photo-1566492031773-4f4e44671857?auto=format&fit=crop&w=100&q=80',
      isOnline: false,
      isVoiceOn: false,
      isPro: true,
      isProOnly: false,
      rating: 4.8,
      gameName: 'Apex Legends',
      platform: 'PC',
      playStyle: 'Competitive',
    ),
  ];

  // Список запитів
  final List<FriendItem> _requestsList = [
    const FriendItem(
      nickname: 'ShadowNinja123',
      avatarUrl: null,
      isOnline: true,
      isVoiceOn: false,
      isPro: true,
      isProOnly: false,
      rating: 4.2,
      gameName: 'Valorant',
      platform: 'PC',
      playStyle: 'Competitive',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 33, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Вкладки (Friends / Requests) з нотифікацією
              _buildTabsRow(),
              const SizedBox(height: 15),
              // 2. Списки карток
              Expanded(
                child: _isFriendsTab ? _buildFriendsTab() : _buildRequestsTab(),
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
            onTap: () => setState(() => _isFriendsTab = true),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF181826),
                border: Border.all(
                  color: _isFriendsTab ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Friends',
                  style: TextStyle(
                    color: _isFriendsTab ? const Color(0xFF00F5A0) : const Color(0xFFFFFFFF),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 17),
        // Кнопка Requests з автоматичним зникненням кружечка при натисканні
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isFriendsTab = false;
                    _hasUnreadRequests = false; // Прочитано! Кружечок зникає
                  });
                },
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF181826),
                    border: Border.all(
                      color: !_isFriendsTab ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Requests',
                      style: TextStyle(
                        color: !_isFriendsTab ? const Color(0xFF00F5A0) : const Color(0xFFFFFFFF),
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
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
              height: 13 / 14, // На основі line-height: 13px для font-size: 14px
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 10),
      itemCount: _friendsList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildFriendCard(_friendsList[index]),
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
              height: 13 / 14, // На основі line-height: 13px для font-size: 14px
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 10),
      itemCount: _requestsList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildRequestCard(_requestsList[index], index),
    );
  }

  // =============================================================================
  // КАРТКА ДРУГА (FRIENDS TAB) - Висота 106px
  // =============================================================================
  Widget _buildFriendCard(FriendItem friend) {
    return Container(
      width: 327,
      height: 106,
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Аватарка з літерою або картинкою
          Positioned(
            left: 10.5,
            top: 13,
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
                child: friend.avatarUrl != null
                    ? Image.network(
                  friend.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(friend.nickname),
                )
                    : _buildLetterAvatar(friend.nickname),
              ),
            ),
          ),
          // Нікнейм та PRO (Підкориговано під CSS)
          Positioned(
            left: 59,
            top: 13,
            right: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  friend.nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (friend.isPro) ...[
                  const SizedBox(width: 6),
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
                if (friend.isProOnly) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 10),
                  const SizedBox(width: 2),
                  const Text('PRO only', style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 7, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          // Статуси (Online/Voice)
          Positioned(
            left: 60,
            top: 28,
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
          // Game list (Тепер крапочки-квадратики стоять точно МІЖ словами за Фігмою!)
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
                Container(width: 3, height: 3, color: Colors.white), // Rectangle 113
                const SizedBox(width: 6),
                Text(
                  friend.platform,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 12),
                ),
                const SizedBox(width: 6),
                Container(width: 3, height: 3, color: Colors.white), // Rectangle 114
                const SizedBox(width: 6),
                Text(
                  friend.playStyle,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 12),
                ),
              ],
            ),
          ),
          // Кнопки дій
          Positioned(
            left: 12,
            top: 66,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 27,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00F5A0), width: 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Start chat', style: TextStyle(color: Color(0xFF00F5A0), fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500)),
                        SizedBox(width: 10),
                        FigmaArrowIcon(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 23),
                Expanded(
                  child: Container(
                    height: 27,
                    decoration: BoxDecoration(color: const Color(0xFF00F5A0), borderRadius: BorderRadius.circular(10)),
                    child: const Center(
                      child: Text('Invite to play', style: TextStyle(color: Color(0xFF0F0F1A), fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700)),
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
  // КАРТКА ЗАПИТУ (REQUESTS TAB) - Висота 99px з функціями Accept/Decline
  // =============================================================================
  Widget _buildRequestCard(FriendItem friend, int index) {
    return Container(
      width: 327,
      height: 99,
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Маленька аватарка реквесту за CSS (30x30, shadow 8px)
          Positioned(
            left: 11,
            top: 13,
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
                child: friend.avatarUrl != null
                    ? Image.network(
                  friend.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(friend.nickname),
                )
                    : _buildLetterAvatar(friend.nickname),
              ),
            ),
          ),
          // Нікнейм та PRO (top: 13px, left: 59px)
          Positioned(
            left: 59,
            top: 13,
            right: 12,
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
          // Текст: "sent you a friend request" (top: 32px)
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
          // Кнопки дій Decline та Accept з робочою логікою
          Positioned(
            left: 12,
            top: 59,
            right: 12,
            child: Row(
              children: [
                // Кнопка Decline — видаляє запит
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _requestsList.removeAt(index);
                      });
                    },
                    child: Container(
                      height: 27,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF00F5A0), width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Decline',
                          style: TextStyle(
                            color: Color(0xFF00F5A0),
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 23),
                // Кнопка Accept — переносить у список друзів
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        // Видаляємо з реквестів та додаємо у друзі
                        FriendItem accepted = _requestsList.removeAt(index);
                        _friendsList.add(accepted);
                        _isFriendsTab = true; // Відразу перемикаємо на вкладку друзів для результату
                      });
                    },
                    child: Container(
                      height: 27,
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

  // Універсальний генератор літери з твоїм шрифтом 'Love Light' із Figma
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