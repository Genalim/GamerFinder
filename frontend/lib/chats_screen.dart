import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'chat_new_screen.dart';
import 'new_chat_room_screen.dart';
import 'models.dart';
import 'dart:convert'; // Для json.decode
import 'package:http/http.dart' as http; // Для http.get
import 'api_service.dart';
import 'api_config.dart';
import 'user_session.dart';
import 'package:flutter/scheduler.dart';

class ChatItem {
  final String id;
  final String title;
  final int? recipientId; // <-- ID того, з ким ча
  final String lastMessage;
  final String time;
  int unreadCount;
  final bool isPro;
  final bool isGroupChat;
  final List<String> userInitials;
  final String status;
  final double? rating;
  final String? avatarUrl;

  ChatItem({
    required this.id,
    required this.title,
    this.recipientId,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    this.isPro = false,
    this.isGroupChat = false,
    required this.userInitials,
    required this.status,
    this.rating,
    this.avatarUrl,
  });

  // --- ОСЬ СЮДИ ВСТАВЛЯЄМО ФАБРИКУ ---
  factory ChatItem.fromJson(Map<String, dynamic> json) {
    debugPrint("DEBUG: Вхідний JSON: $json");
    return ChatItem(
      id: json['chat_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown',
      lastMessage: json['last_message'] ?? '',
      time: json['last_message_time'] ?? '',
      unreadCount: json['unread_count'] ?? 0,
      isPro: json['is_pro'] ?? false,
      isGroupChat: json['is_group'] ?? false,
      userInitials: List<String>.from(json['initials'] ?? []),
      status: json['last_message_status'] ?? 'sent',
      rating: json['rating']?.toDouble(),
      avatarUrl: json['avatar_url'],
      recipientId: json['recipient_id'],
    );
  }
}


class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (context) => const ChatListWidget()),
    );
  }
}

class ChatListWidget extends StatefulWidget {
  const ChatListWidget({super.key});
  @override
  State<ChatListWidget> createState() => _ChatListWidgetState();
}

class _ChatListWidgetState extends State<ChatListWidget> {
  String _searchQuery = "";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Це спрацює, коли ми повернемося на цей екран
    _fetchChats();
  }

  // Додаємо цей список, щоб передавати його в ChatRoomScreen
  //final List<FriendItem> _allFriends = [
   // FriendItem(name: 'ALEX', status: 'online', initial: 'A', isOnline: true),
   // FriendItem(name: 'NOVA', status: 'was online 1 hour ago', initial: 'N', isOnline: false),
   // FriendItem(name: 'Peter', status: 'was online a year ago', initial: 'P', isOnline: false),
   // FriendItem(name: 'MMA_boxer', status: 'was online yesterday at 10:05 PM', initial: 'M', isOnline: false),
 // ];

  //final List<ChatItem> _chats = [
   // ChatItem(title: 'Mario_gamer', lastMessage: 'Last message', time: '5min ago', unreadCount: 2, isPro: true, userInitials: ['M'], status: 'unread'),
    //ChatItem(title: 'Sam', lastMessage: 'Last message', time: '5min agi', unreadCount: 12, isPro: false, userInitials: ['S'], status: 'unread'),
    //ChatItem(title: 'NOVA', lastMessage: 'Last message...', time: '13:39', unreadCount: 0, isPro: true, userInitials: ['N'], status: 'read'),
    //ChatItem(title: 'Valorant Squad', lastMessage: 'GG WP', time: '1h ago', unreadCount: 5, isPro: true, isGroupChat: true, userInitials: ['N', 'A', 'M', 'P'], status: 'unread'),
    //ChatItem(title: 'Player_4', lastMessage: 'Hey, let\'s play!', time: '10m ago', unreadCount: 0, isPro: false, userInitials: ['P'], status: 'sent'),
    //ChatItem(title: 'Alex', lastMessage: 'See you later', time: '2h ago', unreadCount: 0, isPro: false, userInitials: ['A'], status: 'delivered'),
    //ChatItem(title: 'Max', lastMessage: 'What is the plan?', time: '3h ago', unreadCount: 1, isPro: true, userInitials: ['M'], status: 'unread'),
  //];

  @override
  void initState() {
    super.initState();
    _fetchChats(); // Завантажуємо дані при старті екрану
  }

  List<ChatItem> _chats = []; // Спочатку порожній

  Future<void> _fetchChats() async {
    // Ми не робимо setState відразу, якщо є дані
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/list'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Оновлюємо дані БЕЗ прямого впливу на поточний кадр
        final List<ChatItem> newChats = data.map((json) => ChatItem.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            _chats = newChats;
          });
        }
      }
    } catch (e) {
      debugPrint("Помилка: $e");
    }
  }

  void _closeAndRefresh() {
    // 1. Спочатку закриваємо екран чату
    Navigator.pop(context);
    // 2. Потім запускаємо оновлення в фоні
    _fetchChats();
  }

  void _openChat(dynamic chatOrName) {
    print("DEBUG: Відкриваємо чат з title: '${chatOrName.title}', id: '${chatOrName.id}'");

    if (chatOrName is ChatItem) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            friendName: chatOrName.title,
            chatId: chatOrName.id,
            friendId: chatOrName.recipientId?.toString(),
            onBack: _closeAndRefresh, // Викликаємо наш новий метод
          ),
        ),
      );
    } else if (chatOrName is String) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            friendName: chatOrName,
            onBack: _closeAndRefresh, // І тут також
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _chats.where((chat) {return chat.title.toLowerCase().contains(_searchQuery) || chat.lastMessage.toLowerCase().contains(_searchQuery);}).toList();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                              onTap: () => setState(() => _chats.forEach((c) => c.unreadCount = 0)),
                              child: Row(children: [
                                ChatsHeaderCheckbox(isChecked: _chats.every((c) => c.unreadCount == 0)),
                                const SizedBox(width: 8),
                                const Text('Read All', style: TextStyle(color: Color(0xFF00F5A0), fontSize: 11))
                              ])
                          )
                      )
                  ),
                  const Text('Chats', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  Expanded(
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NewMessageScreen(onClose: () => Navigator.pop(context), onChatSelected: (n) => _openChat(n)))),
                              child: const FigmaNewChatIcon()
                          )
                      )
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: const SizedBox(
                      width: 40,
                      child: Center(child: FigmaSearchIcon()), // Тут викликаємо наш новий клас
                    ),
                    suffixIcon: SizedBox(width: 40),
                    hintText: 'Search players or chats',
                    hintStyle: TextStyle(color: Color(0xFFA3A3B5), fontSize: 14),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 10),
                itemCount: filteredChats.length,
                itemBuilder: (context, index) => GestureDetector(
                    onTap: () => _openChat(filteredChats[index]),
                    child: _buildChatTile(filteredChats[index])
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAvatar(ChatItem chat) {
    // 1. Якщо у чату є власна аватарка (кейс "в" - групова аватарка чату)
    if (chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty) {
      // Тут ми викликаємо buildAvatar, який у тебе вже є нижче
      return ClipOval(child: buildAvatar(chat.avatarUrl!, '?', 40));
    }

    // 2. Якщо це чат 1 на 1
    if (!chat.isGroupChat) {
      final initial = chat.userInitials.isNotEmpty ? chat.userInitials.first : '?';
      return _buildSingleAvatar(initial);
    }

    // 3. Якщо група
    return _buildGroupAvatar(chat.userInitials);
  }

  Widget _buildChatTile(ChatItem chat) {
    // (Решта коду _buildChatTile, _buildStatusIcon, _buildSingleAvatar, _buildGroupAvatar залишається без змін)
    final backgroundColor = chat.unreadCount > 0 ? const Color(0xFF232336) : const Color(0xFF181826);
    final bool amIPro = UserSession().currentUser?.isPro ?? false;
    return Container(
      height: 66,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(width: 40, height: 40, child: _buildChatAvatar(chat)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(chat.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),

                  // Кейс: Тільки приватний чат (не група)
                  if (!chat.isGroupChat) ...[

                    // Якщо Я - Про, бачу зірку та РЕЙТИНГ співрозмовника
                    if (amIPro) ...[
                      const FigmaRatingStar(isFilled: true, size: 10),
                      const SizedBox(width: 4),
                      Text(
                          chat.rating != null ? chat.rating!.toStringAsFixed(1) : '0.0',
                          style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 7, fontWeight: FontWeight.bold)
                      ),
                    ]
                    // Якщо Я - НЕ Про, бачу зірку та "PRO Only"
                    else ...[
                      const FigmaRatingStar(isFilled: true, size: 10),
                      const SizedBox(width: 4),
                      const Text(
                          'PRO only',
                          style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 7, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ],
                ]),
                const SizedBox(height: 4),
                Text(chat.lastMessage, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(chat.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 6)),
              const SizedBox(height: 4),

              // Твоя умова: показуємо тільки якщо є непрочитані від інших
              if (chat.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF00F5A0), borderRadius: BorderRadius.circular(9)),
                  child: Text('${chat.unreadCount}', style: const TextStyle(color: Color(0xFF0F0F1A), fontSize: 11, fontWeight: FontWeight.w500)),
                )
              else if (['sent', 'delivered', 'read'].contains(chat.status)) // <--- ТЕПЕР ДОЗВОЛЯЄМО ВСІ СТАТУСИ
                _buildStatusIcon(chat.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLetterAvatar(String initial) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF181826),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: 'Love Light',
            fontSize: 18,
            color: Color(0xFF00F5A0),
          ),
        ),
      ),
    );
  }

  Widget buildAvatar(String? avatarUrl, String initial, double size) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildLetterAvatar(initial);
    }
    if (avatarUrl.startsWith('http')) {
      return Image.network(
        avatarUrl,
        width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial),
      );
    }
    return Image.asset(
      avatarUrl,
      width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial),
    );
  }


  Widget _buildStatusIcon(String status) {
    if (status == 'read') {
      // Використовуємо твою Figma-іконку, якщо вона у тебе є
      return const FigmaDoubleCheckIcon(color: Colors.white);
    } else if (status == 'delivered') {
      return const FigmaDoubleCheckIcon(color: Color(0xFF8E8EA9));
    } else {
      return const FigmaSingleCheckIcon(color: Color(0xFF8E8EA9));
    }
  }

  Widget _buildSingleAvatar(String initial) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF181826), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF00F5A0).withOpacity(0.3), blurRadius: 6)]),
      child: Center(child: Text(initial, style: const TextStyle(fontFamily: 'Love Light', fontSize: 25, color: Color(0xFF00F5A0)))),
    );
  }

  Widget _buildGroupAvatar(List<String> initials) {
    // Кейс 3 і 4: беремо максимум 4
    final displayInitials = initials.take(4).toList();

    return Container(
      width: 40, height: 40,
      decoration: const BoxDecoration(color: Color(0xFF181826), shape: BoxShape.circle),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 2, runSpacing: 2,
        children: displayInitials.map((i) => Text(
            i,
            style: const TextStyle(fontFamily: 'Love Light', fontSize: 10, color: Color(0xFF00F5A0))
        )).toList(),
      ),
    );
  }
}