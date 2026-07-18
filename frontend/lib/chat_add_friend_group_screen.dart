import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'models.dart';
import 'group_chat_room_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'api_service.dart';

class ChatAddFriendsGroupScreen extends StatefulWidget {
  final VoidCallback onClose;
  final String currentFriendName;
  final List<FriendItem> friendsList;
  final String? chatId; // <-- Додаємо (null, якщо створюємо нову)
  final List<int>? existingMemberIds;

  const ChatAddFriendsGroupScreen({
    super.key,
    required this.onClose,
    required this.currentFriendName,
    required this.friendsList,
    this.chatId,
    this.existingMemberIds,
  });

  @override
  State<ChatAddFriendsGroupScreen> createState() => _ChatAddFriendsGroupScreenState();
}

class _ChatAddFriendsGroupScreenState extends State<ChatAddFriendsGroupScreen> {
  final Set<String> _selectedFriends = {};
  String _searchQuery = "";

  // Фільтруємо список на основі пошуку
  List<FriendItem> get _filteredFriends {
    return widget.friendsList.where((friend) {
      // 1. Стара логіка (не показувати "МЕ" і поточного партнера)
      bool isMe = friend.name == 'ME';
      bool isCurrentPartner = friend.name == widget.currentFriendName;

      // 2. НОВА логіка: виключаємо тих, хто вже є в чаті
      // Перевіряємо, чи є ID цього друга у списку існуючих учасників
      bool alreadyInGroup = widget.existingMemberIds?.contains(friend.id) ?? false;

      // 3. Пошук
      bool matchesSearch = friend.name.toLowerCase().contains(_searchQuery.toLowerCase());

      // Повертаємо true, тільки якщо це не ми, не партнер, не учасник групи І матчить пошук
      return !isMe && !isCurrentPartner && !alreadyInGroup && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredFriends;
    bool isButtonActive = _selectedFriends.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      resizeToAvoidBottomInset: false, // ВИПРАВЛЕННЯ СКАКАННЯ: вимикаємо нативний Resize
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FigmaGreenCloseButton(onTap: widget.onClose),
                  const Text("Add Friends", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // SEARCH BAR (1 в 1 як у NewMessageScreen)
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
                    prefixIcon: SizedBox(width: 40, child: Center(child: FigmaSearchIcon())),
                    hintText: 'Search friends...',
                    hintStyle: TextStyle(color: Color(0xFFA3A3B5), fontSize: 14),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: displayList.length,
                itemBuilder: (context, index) => _buildFriendTile(displayList[index]),
              ),
            ),

            // Кнопка створення або додавання
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: isButtonActive ? () async {
                  final List<int> selectedIds = widget.friendsList
                      .where((f) => _selectedFriends.contains(f.name))
                      .map((f) => f.id)
                      .toList();

                  if (widget.chatId != null) {
                    // ВАРІАНТ: Додавання в існуючий чат
                    final response = await http.post(
                        Uri.parse('${ApiConfig.baseUrl}/group_chats/${widget.chatId}/add-members'),
                        headers: await ApiService.getHeaders(),
                        body: json.encode({"user_ids": selectedIds})
                    );

                    if (response.statusCode == 200) {
                      // Повертаємо true, щоб оновити дані в батьківському екрані (ChatInfo)
                      Navigator.pop(context, true);
                    } else {
                      debugPrint("Помилка додавання: ${response.statusCode}");
                    }
                  } else {
                    // ВАРІАНТ: Створення нової групи
                    final response = await http.post(
                        Uri.parse('${ApiConfig.baseUrl}/chats/create-group'),
                        headers: await ApiService.getHeaders(),
                        body: json.encode({
                          "name": "New Group",
                          "user_ids": selectedIds,
                        })
                    );

                    if (response.statusCode == 200) {
                      final data = json.decode(response.body);
                      final String newChatId = data['chat_id'];

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupChatRoomScreen(
                            chatId: newChatId,
                            participantNames: [widget.currentFriendName, ..._selectedFriends],
                            onBack: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    } else {
                      debugPrint("Помилка створення групи: ${response.statusCode}");
                    }
                  }
                } : null,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: isButtonActive ? const Color(0xFF00F5A0) : const Color(0xFF181826),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                        widget.chatId != null ? "Add Members" : "Create Group",
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isButtonActive ? const Color(0xFF0F0F1A) : const Color(0xFF6B6B80)
                        )
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(FriendItem friend) {
    final bool isSelected = _selectedFriends.contains(friend.name);
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
          setState(() {
            isSelected ? _selectedFriends.remove(friend.name) : _selectedFriends.add(friend.name);
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0xFF0F0F13), shape: BoxShape.circle), child: Center(child: Text(friend.initial, style: const TextStyle(fontFamily: 'Love Light', fontSize: 14, color: Color(0xFF00F5A0))))),
              const SizedBox(width: 10),
              Text(friend.name, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}