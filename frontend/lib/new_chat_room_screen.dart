import 'package:flutter/material.dart';
import 'dart:math';
import 'custom_widgets.dart';
import 'chat_add_friend_group_screen.dart';
import 'gamer_profile_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String friendName;
  final String? friendId;
  final VoidCallback onBack;
  final String? initialMessage;

  const ChatRoomScreen({
    super.key,
    required this.friendName,
    required this.onBack,
    this.friendId,
    this.initialMessage,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final List<String> _backgrounds = ['1.webp', '2.webp', '3.webp'];
  late String _currentBg;
  final TextEditingController _textController = TextEditingController();
  bool _isInputEmpty = true;

  @override
  void initState() {
    super.initState();
    _currentBg = _backgrounds[Random().nextInt(_backgrounds.length)];
    if (widget.initialMessage != null) _textController.text = widget.initialMessage!;
    _textController.addListener(() {
      final isEmpty = _textController.text.trim().isEmpty;
      if (_isInputEmpty != isEmpty) setState(() => _isInputEmpty = isEmpty);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Універсальна ініціалізація ініціалів
    final String initial = widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?';

    return Material(
      color: const Color(0xFF0F0F13),
      child: Stack(
        children: [
          Container(decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/ChatBackground/$_currentBg'), fit: BoxFit.cover, opacity: 0.3))),
          Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                _buildHeader(initial),
                const Expanded(child: Center(child: Text("No messages yet", style: TextStyle(color: Color(0xFF8E8EA9))))),
                Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 16, right: 16),
                  child: _buildInput(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String initial) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 57, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(onTap: widget.onBack, child: const SizedBox(width: 40, height: 40, child: ChatBackIcon(size: 24))),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (widget.friendId != null) {
                    // ВИКОРИСТОВУЄМО НАШ НОВИЙ СТАТИЧНИЙ МЕТОД
                    GamerProfileScreen.openFromId(context, widget.friendId!);
                  }
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: Color(0xFF181826), shape: BoxShape.circle),
                  child: Center(child: Text(initial, style: const TextStyle(fontFamily: 'Love Light', fontSize: 18, color: Color(0xFF00F5A0)))),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.friendName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const Text("online", style: TextStyle(color: Color(0xFF00F5A0), fontSize: 10)),
                ],
              ),
            ],
          ),
          const ChatAddGroupIcon(size: 42),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF2B2B3B)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const FigmaAttachIcon(),
          Expanded(child: TextField(controller: _textController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(border: InputBorder.none, hintText: "Write..."))),
          _isInputEmpty ? const FigmaSendInactiveIcon() : const FigmaSendActiveIcon(),
        ],
      ),
    );
  }
}