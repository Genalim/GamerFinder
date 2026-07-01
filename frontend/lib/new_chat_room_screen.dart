import 'package:flutter/material.dart';
import 'dart:math';
import 'custom_widgets.dart';
import 'chat_add_friend_group_screen.dart';
import 'gamer_profile_screen.dart';
import 'services/chat_manager.dart';
import 'api_config.dart';
import 'package:http/http.dart' as http;
import 'user_session.dart';
import 'dart:convert';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

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
  List<Map<String, dynamic>> _messages = [];

  // Додаємо змінну для реального ID чату
  String? _activeChatId;

  @override
  void initState() {
    super.initState();
    _currentBg = _backgrounds[Random().nextInt(_backgrounds.length)];

    // 1. СПОЧАТКУ ініціалізуємо сокет
    final myId = UserSession().currentUser?.id.toString() ?? "";
    ChatManager().init(myId);

    // 2. ТЕПЕР можна підписуватися на події, бо ChatManager().socket вже готовий
    ChatManager().socket.onAny((event, data) {
      print("DEBUG: ПРИЛЕТІЛА ПОДІЯ: $event, ДАНІ: $data");
    });

    ChatManager().socket.on('new_message', (data) {
      print("DEBUG: Отримано сигнал від сокета: $data");
      if (!mounted) return;
      setState(() {
        _messages.insert(0, {
          'content': data['content'],
          'sender_id': data['sender_id'],
          'isMe': data['sender_id'].toString() == myId,
          'time': _parseDateTime(data['created_at']),
        });
      });
    });

    // 3. Тільки після налаштування сокета ініціалізуємо чат (який робить join)
    _initializeChat();

    _textController.addListener(() {
      final isEmpty = _textController.text.trim().isEmpty;
      if (_isInputEmpty != isEmpty) setState(() => _isInputEmpty = isEmpty);
    });
  }

  // Окремий метод для завантаження історії
  Future<void> _loadHistory(String chatId) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/messages/$chatId'));
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);

        // Тут ми вручну парсимо список у формат, який розуміє твій UI
        final String myId = UserSession().currentUser?.id.toString() ?? "";

        setState(() {
          _messages = list.map((item) => {
            'content': item['content'],
            'sender_id': item['sender_id'].toString(),
            'isMe': item['sender_id'].toString() == myId,
            'time': _parseDateTime(item['created_at']),
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження історії: $e");
    }
  }

  String? _friendAvatarUrl;

// 2. Онови метод _initializeChat, щоб він тягнув інфу про друга
  Future<void> _initializeChat() async {
    if (widget.friendId == null) return;

    try {
      // А) Отримуємо ID чату
      final chatResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chats/get-or-create?recipient_id=${widget.friendId}'),
        headers: await ApiService.getHeaders(),
      );

      print("DEBUG: Статус чату: ${chatResponse.statusCode}");
      print("DEBUG: Тіло чату: ${chatResponse.body}");

      // Б) Отримуємо профіль друга
      final userResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/${widget.friendId}'),
        headers: await ApiService.getHeaders(),
      );

      // ДОДАЄМО ПЕРЕВІРКУ НА NULL
      if (chatResponse.statusCode == 200 && chatResponse.body.isNotEmpty) {
        final chatData = json.decode(chatResponse.body);

        // Перевіряємо, чи chat_id взагалі існує в відповіді
        if (chatData != null && chatData['chat_id'] != null) {
          setState(() {
            _activeChatId = chatData['chat_id'].toString();
          });

          // Тільки якщо ми отримали chat_id, ініціалізуємо сокет та історію
          ChatManager().joinChat(_activeChatId!);
          _loadHistory(_activeChatId!);
        }
      }

      if (userResponse.statusCode == 200 && userResponse.body.isNotEmpty) {
        final userData = json.decode(userResponse.body);
        setState(() {
          _friendAvatarUrl = userData['avatar'];
        });
      }

    } catch (e) {
      debugPrint("Помилка ініціалізації: $e");
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showActionsOverlay(BuildContext context, Map<String, dynamic> message, Offset tapPosition) async {
    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        MediaQuery.of(context).size.width - tapPosition.dx,
        MediaQuery.of(context).size.height - tapPosition.dy,
      ),
      color: const Color(0xFF181826),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: ['Reply', 'Edit', 'Copy', 'Forward', 'Delete'].map((action) => PopupMenuItem(
        value: action,
        child: Text(action, style: TextStyle(color: action == 'Delete' ? Colors.red : Colors.white)),
      )).toList(),
    );
  }

  DateTime _parseDateTime(dynamic timeData) {
    if (timeData is DateTime) return timeData;
    String timeString = timeData.toString();
    // Твій підхід з "Z" для UTC
    if (!timeString.contains('Z') && !timeString.contains('+')) {
      timeString += 'Z';
    }
    return DateTime.parse(timeString).toLocal();
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
                Expanded(
                  child: ListView.builder(
                    reverse: true, // Щоб останні повідомлення були знизу
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final bool isNewDay = index == _messages.length - 1 ||
                          !isSameDay(msg['time'], _messages[index + 1]['time']);

                      // ЯВНЕ ПЕРЕТВОРЕННЯ ТИПІВ:
                      final String content = msg['content']?.toString() ?? "";
                      final String senderId = msg['sender_id']?.toString() ?? "0";
                      final bool isMe = msg['isMe'] ?? false;

                      // ВАЖЛИВО: Беремо час з об'єкта повідомлення, якщо він є, інакше DateTime.now()
                      final DateTime time = msg['time'] is DateTime ? msg['time'] : DateTime.now();

                      return ChatMessageWidget(
                        showDateDivider: isNewDay,
                        message: ChatMessage(
                          id: index.toString(),
                          content: content,
                          senderId: senderId,
                          senderName: "User",
                          timestamp: time,
                          isMe: isMe,
                        ),
                        onActionSelected: (String action) {
                          // Ось тут ти просто "заглушив" логіку, поки вона тобі не потрібна
                          switch (action) {
                            case 'Delete':
                              print("Потрібно видалити: $content");
                              // Тут пізніше буде: ChatManager().deleteMessage(msg['id']);
                              break;
                            case 'Copy':
                              print("Копіюємо в буфер...");
                              break;
                            default:
                              print("Вибрана дія: $action");
                          }
                        },
                      );
                    },
                  ),
                ),
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
          GestureDetector(
            onTap: widget.onBack,
            child: const SizedBox(width: 40, height: 40, child: ChatBackIcon(size: 24)),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  print("DEBUG: Клік на аватарку, friendId = ${widget.friendId}");
                  if (widget.friendId != null) {
                    GamerProfileScreen.openFromId(context, widget.friendId!);
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF181826),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval( // ClipOval краще підходить для круглої аватарки
                    child: buildAvatar(_friendAvatarUrl, initial, 32),
                  ),
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

// Допоміжний метод для літери, щоб стилі збігалися з твоїм шаблоном
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

    // Якщо це мережевий URL (з бекенда)
    if (avatarUrl.startsWith('http')) {
      return Image.network(
        avatarUrl,
        width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial),
      );
    }

    // Якщо це локальний шлях (assets)
    return Image.asset(
      avatarUrl,
      width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial),
    );
  }

  Widget _buildInput() {
    return Container(
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF181826),
          border: Border.all(color: const Color(0xFF2B2B3B)),
          borderRadius: BorderRadius.circular(12)
      ),
      child: Row(
        children: [
          const FigmaAttachIcon(),
          Expanded(
              child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Write..."
                  )
              )
          ),
          _isInputEmpty
              ? const FigmaSendInactiveIcon()
              : GestureDetector(
            onTap: () {
              final String myId = UserSession().currentUser?.id.toString() ?? "";
              print("DEBUG: Натиснуто кнопку відправки, ID чату: $_activeChatId, Текст: ${_textController.text}");

              // ВАЖЛИВО: Перевіряємо, чи ми вже отримали _activeChatId від сервера
              if (_activeChatId != null && _textController.text.trim().isNotEmpty) {

                // Відправляємо повідомлення з динамічними даними
                ChatManager().sendMessage(
                    _activeChatId!,        // РЕАЛЬНИЙ ID чату (UUID)
                    myId,                 // РЕАЛЬНИЙ ID твого користувача
                    _textController.text.trim()
                );

                _textController.clear();
              } else if (_activeChatId == null) {
                debugPrint("Помилка: Чат ще не ініціалізовано!");
              }
            },
            child: const FigmaSendActiveIcon(),
          ),
        ],
      ),
    );
  }
  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}

class ChatMessage {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.timestamp,
    required this.isMe,
  });
}

class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onActionSelected;
  final bool showDateDivider;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.onActionSelected,
    this.showDateDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    String formattedTime = DateFormat('HH:mm').format(message.timestamp.toLocal());

    // Використовуємо GestureDetector для запуску блюру при довгому натисканні
    return GestureDetector(
      onLongPress: () => _showBlurActions(context),
      child: Column(
        children: [
          if (showDateDivider)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(DateFormat('d MMMM yyyy').format(message.timestamp.toLocal()),
                  style: const TextStyle(color: Color(0xFF6E6E80), fontSize: 10)),
            ),
          Align(
            alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isMe ? const Color(0xFF00F5A0) : const Color(0xFF181826),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(message.content, style: const TextStyle(
                      color: Color(0xFF0F0F1A), // Чорний текст для обох типів (поправ під себе)
                      fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formattedTime, style: const TextStyle(color: Color(0xFF6E6E80), fontSize: 8)),
                      const SizedBox(width: 4),
                      const Icon(Icons.done_all, size: 10, color: Color(0xFF6E6E80)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlurActions(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      barrierLabel: "Menu",
      pageBuilder: (context, anim1, anim2) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: const Color(0xFF181826),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Reply', 'Edit', 'Copy', 'Forward', 'Delete'].map((action) => ListTile(
              title: Text(action, style: const TextStyle(color: Colors.white)),
              onTap: () {
                onActionSelected(action); // Викликаємо твою логіку
                Navigator.pop(context);   // Закриваємо діалог
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
}