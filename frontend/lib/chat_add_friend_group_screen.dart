import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'models.dart';
import 'group_chat_room_screen.dart';

class ChatAddFriendsGroupScreen extends StatefulWidget {
  final VoidCallback onClose;
  final String currentFriendName;
  final List<FriendItem> friendsList;

  const ChatAddFriendsGroupScreen({
    super.key,
    required this.onClose,
    required this.currentFriendName,
    required this.friendsList,
  });

  @override
  State<ChatAddFriendsGroupScreen> createState() => _ChatAddFriendsGroupScreenState();
}

class _ChatAddFriendsGroupScreenState extends State<ChatAddFriendsGroupScreen> {
  final Set<String> _selectedFriends = {};

  List<FriendItem> get _filteredFriends {
    return widget.friendsList.where((friend) {
      bool isMe = friend.name == 'ME';
      bool isCurrentPartner = friend.name == widget.currentFriendName;
      return !isMe && !isCurrentPartner;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredFriends;
    bool isButtonActive = _selectedFriends.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Використовуємо ваш кастомний віджет тут:
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: FigmaGreenCloseButton(onTap: widget.onClose),
                  ),
                  const Text(
                      "Add Friends",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  // Баланс для центрування заголовка
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: displayList.length,
                itemBuilder: (context, index) => _buildFriendTile(displayList[index]),
              ),
            ),
            // Кнопка створення групи
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: isButtonActive ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupChatRoomScreen(
                        participantNames: [widget.currentFriendName, ..._selectedFriends],
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                  );
                } : null,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: isButtonActive ? const Color(0xFF00F5A0) : const Color(0xFF181826),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text("Create Group", style: TextStyle(fontWeight: FontWeight.w700, color: isButtonActive ? const Color(0xFF0F0F1A) : const Color(0xFF6B6B80))),
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