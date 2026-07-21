import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'custom_widgets.dart';
import 'new_chat_room_screen.dart';
import 'models.dart';
import 'api_config.dart';
import 'api_service.dart';

class NewMessageScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String) onChatSelected;

  const NewMessageScreen({
    super.key,
    required this.onClose,
    required this.onChatSelected,
  });

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  String? _selectedFriendName;
  // Мапа для збереження ID по нікнейму (це наш "міст")
  final Map<String, int> _friendIdMap = {};
  List<FriendItem> _friends = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/friends/list'),
        headers: await ApiService.getHeaders(),
      );
      if (response.statusCode == 200 && mounted) {
        List<dynamic> list = json.decode(response.body);

        setState(() {
          _friends = list.map((item) {
            final data = item['user'] ?? item;
            final nickname = data['nickname'] ?? 'Unknown';
            final userId = data['id'] ?? 0;
            final avatar = data['avatar']?.toString(); // Отримуємо URL аватарки

            _friendIdMap[nickname] = userId;

            return FriendItem(
              id: userId,
              name: nickname,
              status: data['is_online'] == true ? 'online' : 'offline',
              initial: nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
              isOnline: data['is_online'] ?? false,
              avatarUrl: avatar, // Передаємо сюди!
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження друзів: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Фільтруємо список перед відображенням
    final filteredFriends = _friends.where((f) =>
        f.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Column(
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
              child: Row(
                children: [
                  FigmaGreenCloseButton(onTap: widget.onClose),
                  const Expanded(
                      child: Text('Write a new message',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700)
                      )
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // --- ПОШУКОВИЙ РЯДОК ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: SizedBox(width: 40, child: Center(child: FigmaSearchIcon())), // Твоя іконка
                    hintText: 'Search friends...',
                    hintStyle: TextStyle(color: Color(0xFFA3A3B5), fontSize: 14),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Список друзів
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredFriends.length,
                itemBuilder: (context, index) => _buildFriendTile(filteredFriends[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(FriendItem friend) {
    final bool isSelected = _selectedFriendName == friend.name;

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2B2B3B) : const Color(0xFF181826),
        border: Border.all(color: isSelected ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() { _selectedFriendName = friend.name; });

          final friendId = _friendIdMap[friend.name];

          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomScreen(
                  friendName: friend.name,
                  friendId: friendId?.toString(),
                  onBack: () => Navigator.pop(context),
                ),
              ),
            );
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Аватарка з логікою перемикання на ініціал
              SizedBox(
                width: 24,
                height: 24,
                child: ClipOval(
                  child: buildAvatar(friend.avatarUrl, friend.initial, 24),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                  friend.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13)
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAvatar(String? avatarUrl, String initial, double size) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildLetterAvatar(initial);
    }

    final String fullAvatarUrl = avatarUrl.startsWith('http')
        ? avatarUrl
        : '${ApiConfig.baseUrl}${avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl'}';

    return Image.network(
      fullAvatarUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial),
    );
  }

// А це твій метод для ініціалів, який ти вже використовував
  Widget _buildLetterAvatar(String initial) {
    return Container(
      width: 24, // Ставимо фіксований розмір для списку
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F13), // Темний фон, як у тебе в дизайні
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: 'Love Light',
            fontSize: 14,
            color: Color(0xFF00F5A0),
          ),
        ),
      ),
    );
  }

}