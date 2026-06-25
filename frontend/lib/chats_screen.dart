import 'package:flutter/material.dart';
import 'custom_widgets.dart' show FigmaNewChatIcon, ChatsHeaderCheckbox, FigmaRatingStar;
import 'chat_new_screen.dart';
import 'new_chat_room_screen.dart';
import 'models.dart'; // Імпортуємо ваші моделі

class ChatItem {
  final String title;
  final String lastMessage;
  final String time;
  int unreadCount;
  final bool isPro;
  final bool isGroupChat;
  final List<String> userInitials;
  final String status;

  ChatItem({
    required this.title,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    this.isPro = false,
    this.isGroupChat = false,
    required this.userInitials,
    required this.status,
  });
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

  // Додаємо цей список, щоб передавати його в ChatRoomScreen
  final List<FriendItem> _allFriends = [
    FriendItem(name: 'ALEX', status: 'online', initial: 'A', isOnline: true),
    FriendItem(name: 'NOVA', status: 'was online 1 hour ago', initial: 'N', isOnline: false),
    FriendItem(name: 'Peter', status: 'was online a year ago', initial: 'P', isOnline: false),
    FriendItem(name: 'MMA_boxer', status: 'was online yesterday at 10:05 PM', initial: 'M', isOnline: false),
  ];

  final List<ChatItem> _chats = [
    ChatItem(title: 'Mario_gamer', lastMessage: 'Last message', time: '5min ago', unreadCount: 2, isPro: true, userInitials: ['M'], status: 'unread'),
    ChatItem(title: 'Sam', lastMessage: 'Last message', time: '5min agi', unreadCount: 12, isPro: false, userInitials: ['S'], status: 'unread'),
    ChatItem(title: 'NOVA', lastMessage: 'Last message...', time: '13:39', unreadCount: 0, isPro: true, userInitials: ['N'], status: 'read'),
    ChatItem(title: 'Valorant Squad', lastMessage: 'GG WP', time: '1h ago', unreadCount: 5, isPro: true, isGroupChat: true, userInitials: ['N', 'A', 'M', 'P'], status: 'unread'),
    ChatItem(title: 'Player_4', lastMessage: 'Hey, let\'s play!', time: '10m ago', unreadCount: 0, isPro: false, userInitials: ['P'], status: 'sent'),
    ChatItem(title: 'Alex', lastMessage: 'See you later', time: '2h ago', unreadCount: 0, isPro: false, userInitials: ['A'], status: 'delivered'),
    ChatItem(title: 'Max', lastMessage: 'What is the plan?', time: '3h ago', unreadCount: 1, isPro: true, userInitials: ['M'], status: 'unread'),
  ];

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
                    prefixIcon: SizedBox(width: 40, child: Icon(Icons.search, color: Color(0xFF00F5A0), size: 20)),
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
                    onTap: () => _openChat(filteredChats[index].title),
                    child: _buildChatTile(filteredChats[index])
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ВИПРАВЛЕНИЙ МЕТОД: тепер передаємо allFriends
  void _openChat(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          friendName: name,
          onBack: () => Navigator.pop(context),
          // Параметр allFriends видалено, бо ChatRoomScreen тепер універсальний
        ),
      ),
    );
  }

  Widget _buildChatTile(ChatItem chat) {
    // (Решта коду _buildChatTile, _buildStatusIcon, _buildSingleAvatar, _buildGroupAvatar залишається без змін)
    final backgroundColor = chat.unreadCount > 0 ? const Color(0xFF232336) : const Color(0xFF181826);
    return Container(
      height: 66,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(
            width: 40, height: 40,
            child: (chat.isGroupChat) ? _buildGroupAvatar(chat.userInitials) : _buildSingleAvatar(chat.userInitials.first),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(chat.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  if (chat.isPro) ...[
                    const SizedBox(width: 4),
                    const FigmaRatingStar(isFilled: true, size: 10),
                    const SizedBox(width: 4),
                    const Text('PRO only', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 7, fontWeight: FontWeight.bold)),
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
              if (chat.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF00F5A0), borderRadius: BorderRadius.circular(9)),
                  child: Text('${chat.unreadCount}', style: const TextStyle(color: Color(0xFF0F0F1A), fontSize: 11, fontWeight: FontWeight.w500)),
                )
              else
                _buildStatusIcon(chat.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color = const Color(0xFF8E8EA9);
    switch (status) {
      case 'sent': icon = Icons.check; break;
      case 'delivered': icon = Icons.done_all; break;
      case 'read': icon = Icons.done_all; color = const Color(0xFF00F5A0); break;
      default: icon = Icons.check;
    }
    return Icon(icon, size: 16, color: color);
  }

  Widget _buildSingleAvatar(String initial) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF181826), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF00F5A0).withOpacity(0.3), blurRadius: 6)]),
      child: Center(child: Text(initial, style: const TextStyle(fontFamily: 'Love Light', fontSize: 25, color: Color(0xFF00F5A0)))),
    );
  }

  Widget _buildGroupAvatar(List<String> initials) {
    return Wrap(
      spacing: 2, runSpacing: 2,
      children: initials.take(4).map((i) => Container(
        width: 18, height: 18, decoration: const BoxDecoration(color: Color(0xFF181826), shape: BoxShape.circle),
        child: Center(child: Text(i, style: const TextStyle(fontFamily: 'Love Light', fontSize: 10, color: Color(0xFF00F5A0)))),
      )).toList(),
    );
  }
}