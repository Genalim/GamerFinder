import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'new_chat_room_screen.dart';
import 'models.dart';

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
  final List<FriendItem> _friends = [
    FriendItem(name: 'ALEX', status: 'online', initial: 'A', isOnline: true),
    FriendItem(name: 'NOVA', status: 'was online 1 hour ago', initial: 'N', isOnline: false),
    FriendItem(name: 'Peter', status: 'was online a year ago', initial: 'P', isOnline: false),
    FriendItem(name: 'MMA_boxer', status: 'was online yesterday at 10:05 PM', initial: 'M', isOnline: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
              child: Row(
                children: [
                  FigmaGreenCloseButton(onTap: widget.onClose),
                  const Expanded(
                      child: Text(
                          'Write a new message',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700)
                      )
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _friends.length,
                itemBuilder: (context, index) => _buildFriendTile(_friends[index]),
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
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomScreen(
                  friendName: friend.name,
                  // Тут можна передати ID, якщо він є у FriendItem, або null
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
              Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0xFF0F0F13), shape: BoxShape.circle), child: Center(child: Text(friend.initial, style: const TextStyle(fontFamily: 'Love Light', fontSize: 14, color: Color(0xFF00F5A0))))),
              const SizedBox(width: 8),
              Text(friend.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}