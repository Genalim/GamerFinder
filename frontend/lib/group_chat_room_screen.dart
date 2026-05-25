import 'package:flutter/material.dart';
import 'dart:math';
import 'custom_widgets.dart';

class GroupChatRoomScreen extends StatefulWidget {
  final List<String> participantNames;
  final VoidCallback onBack;

  const GroupChatRoomScreen({
    super.key,
    required this.participantNames,
    required this.onBack,
  });

  @override
  State<GroupChatRoomScreen> createState() => _GroupChatRoomScreenState();
}

class _GroupChatRoomScreenState extends State<GroupChatRoomScreen> {
  final List<String> _backgrounds = ['1.webp', '2.webp', '3.webp'];
  late String _currentBg;
  final TextEditingController _textController = TextEditingController();
  bool _isInputEmpty = true;

  @override
  void initState() {
    super.initState();
    _currentBg = _backgrounds[Random().nextInt(_backgrounds.length)];
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
    // Назва: Ім'я (перший юзер) + кількість інших
    final String displayName = "${widget.participantNames.first} +${widget.participantNames.length - 1}";

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
                _buildHeader(displayName),
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

  Widget _buildHeader(String displayName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 57, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Кнопка назад
          GestureDetector(onTap: widget.onBack, child: const SizedBox(width: 40, height: 40, child: ChatBackIcon(size: 24))),

          // Аватар та назва по центру
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGroupAvatar(),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const Text("online", style: TextStyle(color: Color(0xFF00F5A0), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          // Іконка інформації справа
          GestureDetector(
            onTap: () {
              print("Відкриття інфо групи");
            },
            // Ми прибираємо SizedBox з Icon і вставляємо ваш новий віджет
            child: const FigmaGroupInfoIcon(size: 45),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupAvatar() {
    final initials = widget.participantNames.map((n) => n[0].toUpperCase()).take(4).toList();
    return Container(
      width: 36, height: 36,
      decoration: const BoxDecoration(color: Color(0xFF181826), shape: BoxShape.circle),
      child: Center(
        child: Wrap(
          spacing: 2, runSpacing: 2,
          children: initials.map((i) => Text(i, style: const TextStyle(fontFamily: 'Love Light', fontSize: 12, color: Color(0xFF00F5A0)))).toList(),
        ),
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