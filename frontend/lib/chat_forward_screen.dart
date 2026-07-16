import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'user_session.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chats_screen.dart'; // Щоб мати доступ до ChatItem

class ChatForwardScreen extends StatefulWidget {
  final String messageId;
  final String messageContent;

  const ChatForwardScreen({super.key, required this.messageId, required this.messageContent});

  @override
  State<ChatForwardScreen> createState() => _ChatForwardScreenState();
}

class _ChatForwardScreenState extends State<ChatForwardScreen> {
  bool _isShowingChats = true;
  final Set<String> _selectedIds = {};
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _items = []; });
    final endpoint = _isShowingChats ? '/chats/list' : '/friends/list';
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await ApiService.getHeaders(),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() => _items = json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Error loading: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getOrCreateChat(String friendId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chats/get-or-create?recipient_id=$friendId'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['chat_id'].toString();
      } else {
        debugPrint("Помилка створення чату: ${response.statusCode}");
        return ""; // Або оброби помилку інакше
      }
    } catch (e) {
      debugPrint("Помилка мережі при створенні чату: $e");
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F5A0)))
                  : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) => _isShowingChats
                    ? _buildChatTileWrapper(_items[index])
                    : _buildFriendTileWrapper(_items[index]),
              ),
            ),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        FigmaGreenCloseButton(onTap: () => Navigator.pop(context)),
        const Text("Forward", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: () => setState(() { _isShowingChats = !_isShowingChats; _loadData(); }),
          child: Text(_isShowingChats ? "Friends" : "Chats", style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 14)),
        ),
      ],
    ),
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Container(
      height: 40,
      decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(10)),
      child: const TextField(
        style: TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: SizedBox(width: 40, child: Center(child: FigmaSearchIcon())),
          hintText: 'Search...',
          hintStyle: TextStyle(color: Color(0xFFA3A3B5)),
          border: InputBorder.none,
        ),
      ),
    ),
  );

  // Огортаємо твої tile у GestureDetector для вибору
  Widget _buildChatTileWrapper(dynamic chatData) {
    // Конвертуємо JSON у ChatItem, щоб використати твій метод _buildChatTile
    final chat = ChatItem.fromJson(chatData);
    final isSelected = _selectedIds.contains(chat.id);
    return GestureDetector(
      onTap: () => setState(() => isSelected ? _selectedIds.remove(chat.id) : _selectedIds.add(chat.id)),
      child: Stack(
        children: [
          _buildChatTile(chat),
          if (isSelected) _chatSelectionOverlay(),
        ],
      ),
    );
  }

  Widget _buildFriendTileWrapper(dynamic friendData) {
    final String id = friendData['id'].toString();
    final bool isSelected = _selectedIds.contains(id);
    return GestureDetector(
      onTap: () => setState(() => isSelected ? _selectedIds.remove(id) : _selectedIds.add(id)),
      child: Stack(
        children: [
          // Тут використовуєш свій метод _buildFriendTile з NewMessageScreen
          _buildFriendTile(friendData),
          if (isSelected) _friendSelectionOverlay(),
        ],
      ),
    );
  }

  Widget _chatSelectionOverlay() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    height: 66, // Твоя висота картки чату
    decoration: BoxDecoration(
      color: const Color(0xFF00F5A0).withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF00F5A0), width: 2),
    ),
    child: const Align(
      alignment: Alignment.centerRight,
      //child: Padding(padding: EdgeInsets.only(right: 30), child: Icon(Icons.check_circle, color: Color(0xFF00F5A0))),
    ),
  );

// Для друзів (висота 50)
  Widget _friendSelectionOverlay() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    height: 50, // Твоя висота картки друга
    decoration: BoxDecoration(
      color: const Color(0xFF00F5A0).withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF00F5A0), width: 2),
    ),
    child: const Align(
      alignment: Alignment.centerRight,
      //child: Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.check_circle, color: Color(0xFF00F5A0))),
    ),
  );

  Widget _buildSendButton() => Padding(
    padding: const EdgeInsets.all(16.0),
    child: GestureDetector(
      onTap: _sendForwardedMessage,
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: const Color(0xFF00F5A0), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text("Send message to ${_selectedIds.length} chats/friends", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black))),
      ),
    ),
  );

  Future<void> _sendForwardedMessage() async {
    // 1. Спочатку підготуємо список chatId (якщо обрали друзів, перетворимо їх на чати)
    List<String> chatIds = [];

    for (var id in _selectedIds) {
      if (id.contains('-')) { // Це вже UUID чату
        chatIds.add(id);
      } else { // Це ID користувача (friendId)
        String chatId = await _getOrCreateChat(id);
        chatIds.add(chatId);
      }
    }

    // 2. Відправляємо запит на бекенд
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/messages/forward'),
        headers: await ApiService.getHeaders(),
        body: json.encode({
          'message_id': widget.messageId,
          'target_chat_ids': chatIds
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context); // Закриваємо екран форварду
        // Можна показати SnackBar "Forwarded successfully!"
      }
    } catch (e) {
      debugPrint("Forward error: $e");
    }
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
                          style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 13, fontWeight: FontWeight.bold)
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


  Widget _buildFriendTile(dynamic friendData) {
    // friendData — це map, який приходить з API (JSON)
    final String id = friendData['id'].toString();
    final String nickname = friendData['nickname'] ?? 'Unknown';
    final String initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
    final String? avatar = friendData['avatar'];

    final bool isSelected = _selectedIds.contains(id);

    return Container(
      height: 50, // Зробив трохи вище, щоб було зручніше клікати
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2B2B3B) : const Color(0xFF181826),
        border: Border.all(color: isSelected ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => setState(() => isSelected ? _selectedIds.remove(id) : _selectedIds.add(id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: ClipOval(child: buildAvatar(avatar, initial, 32)),
              ),
              const SizedBox(width: 12),
              Text(nickname, style: const TextStyle(color: Colors.white, fontSize: 14)),
              const Spacer(),
              //if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF00F5A0), size: 20),
            ],
          ),
        ),
      ),
    );
  }

// --- ТУТ ПОВИННІ БУТИ ТВОЇ МЕТОДИ _buildChatTile ТА _buildOriginalFriendTile ---
// Скопіюй їх сюди прямо з ChatsScreen та NewMessageScreen, щоб дизайн був ідентичним
}