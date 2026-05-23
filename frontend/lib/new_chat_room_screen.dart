import 'package:flutter/material.dart';
import 'dart:math';

class ChatRoomScreen extends StatefulWidget {
  final String friendName;
  final VoidCallback onBack;
  const ChatRoomScreen({super.key, required this.friendName, required this.onBack});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final List<String> _backgrounds = ['1.webp', '2.webp', '3.webp'];
  late String _currentBg;

  @override
  void initState() {
    super.initState();
    _currentBg = _backgrounds[Random().nextInt(_backgrounds.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      // ВАЖЛИВО: вимикаємо автоматичне зміщення, щоб уникнути багів з відступами
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Фон
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/ChatBackground/$_currentBg'),
                fit: BoxFit.cover,
                opacity: 0.3,
              ),
            ),
          ),

          // Використовуємо AnimatedPadding, щоб плавно підняти ВСЕ на висоту клавіатури
          AnimatedPadding(
            duration: const Duration(milliseconds: 100),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Container(
                    child: const Center(
                      child: Text("No messages yet", style: TextStyle(color: Color(0xFF8E8EA9))),
                    ),
                  ),
                ),
                _buildInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 57, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Іконки по краях
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: const Icon(
                Icons.arrow_back, color: Color(0xFF00F5A0), size: 24),
          ),
          // Центральна частина (Аватар + Ім'я)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // Центруємо контент
              children: [
                Container(
                  width: 33,
                  height: 33,
                  decoration: const BoxDecoration(
                    color: Color(0xFF181826),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0xFF00F5A0),
                          blurRadius: 2,
                          spreadRadius: 1)
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.friendName[0].toUpperCase(),
                      style: const TextStyle(fontFamily: 'Love Light',
                          fontSize: 20,
                          color: Color(0xFF00F5A0)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.friendName, style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500)),
                    const Text("online", style: TextStyle(
                        color: Color(0xFF00F5A0), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.group_add, color: Color(0xFF00F5A0), size: 30),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      // Використовуємо margin для відступів від країв екрана
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF2B2B3B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: Color(0xFF00F5A0), size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: TextField(
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                isCollapsed: true, // ВАЖЛИВО: прибирає зайві відступи
                hintText: "Write your message",
                hintStyle: TextStyle(color: Color(0xFF8E8EA9), fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.send, color: Color(0xFF00F5A0), size: 24),
        ],
      ),
    );
  }
}