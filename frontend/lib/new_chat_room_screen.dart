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
import 'dart:ui' as ui;

class ChatRoomScreen extends StatefulWidget {
  final String friendName;
  final String? friendId;
  final String? chatId;
  final VoidCallback onBack;
  final String? initialMessage;

  const ChatRoomScreen({
    super.key,
    required this.friendName,
    required this.onBack,
    this.friendId,
    this.chatId,
    this.initialMessage,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  final List<String> _backgrounds = ['1.webp', '2.webp', '3.webp'];
  late String _currentBg;
  final TextEditingController _textController = TextEditingController();
  bool _isInputEmpty = true;
  List<Map<String, dynamic>> _messages = [];
  bool _showScrollDownButton = false;
  final Map<int, GlobalKey> _messageKeys = {};
  int _firstUnreadIndex = -1;
  final FocusNode _focusNode = FocusNode();
  double _currentBottomPadding = 20.0;
  Map<String, dynamic>? _messageToEdit;
  Map<String, dynamic>? _messageToReply;

  // Додаємо змінну для реального ID чату
  String? _activeChatId;

  void _markMessagesAsReadUi(String chatId) {
    if (!mounted) return;

    final String myId = UserSession().currentUser?.id.toString() ?? "";

    setState(() {
      for (var msg in _messages) {
        // МАРКУЄМО ПРОЧИТАНИМИ ТІЛЬКИ ЯКЩО:
        // 1. Це повідомлення НЕ НАШЕ (sender_id != myId)
        // 2. Воно ще не прочитане
        if (msg['sender_id'] != myId && msg['status'] != 'read') {
          msg['status'] = 'read';
        }
      }
    });
  }
  bool _isConnected = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print("DEBUG: ChatRoomScreen відкрився. chatId: ${widget.chatId}, friendId: ${widget.friendId}");
    _currentBg = _backgrounds[Random().nextInt(_backgrounds.length)];

    // Встановлюємо початковий статус
    _isConnected = ChatManager().isConnected;

    // Підписка на зміну статусу
    ChatManager().onStatusChanged = (connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
      });
    };

    final myId = UserSession().currentUser?.id.toString() ?? "";
    ChatManager().init(myId);

    // Очищення та підписка на нові повідомлення
    ChatManager().socket.off('new_message');
    ChatManager().socket.on('new_message', (data) {
      _addNewMessageToUi(data);
    });

    // --- НОВЕ: ПІДПИСКА НА ПРОЧИТАННЯ ---
    ChatManager().socket.off('messages_read');
    ChatManager().socket.on('messages_read', (data) {
      _markMessagesAsReadUi(data['chat_id']);
    });
    // --- Подія від серверу (конектид чи ні) ---//
    ChatManager().socket.on('user_typing', (data) {
      if (data['chat_id'] == _activeChatId) {
        setState(() => _isTyping = true);
        // Через 3 секунди прибираємо "typing..."
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }
    });

    ChatManager().socket.off('message_edited');
    ChatManager().socket.on('message_edited', (data) {
      if (!mounted) return;

      final String messageId = data['message_id'].toString();
      final String newContent = data['new_content'];

      setState(() {
        // Шукаємо повідомлення в списку і оновлюємо його
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          _messages[index]['content'] = newContent;
        }
      });
    });

    _scrollController.addListener(() {
      if (!mounted) return;

      // Визначаємо, чи ми біля самого низу (похибка 50 пікселів)
      final bool isNearBottom = _scrollController.offset >= (_scrollController.position.maxScrollExtent - 50);

      // Якщо ми біля низу, позначаємо все як прочитане
      if (isNearBottom && _activeChatId != null) {
        // Перевіряємо, чи є взагалі що читати
        bool hasUnread = _messages.any((m) => m['sender_id'] != UserSession().currentUser?.id.toString() && m['status'] != 'read');
        if (hasUnread) {
          _markAsReadOnServer(_activeChatId!);
        }
      }

      if (_showScrollDownButton != !isNearBottom) {
        setState(() => _showScrollDownButton = !isNearBottom);
      }
    });

    _initializeChat();

    _textController.addListener(() {
      // Коли щось друкуємо, посилаємо сигнал
      if (_activeChatId != null && _textController.text.isNotEmpty) {
        ChatManager().socket.emit('typing', {'chat_id': _activeChatId});
      }
      // Логіка оновлення іконки Send
      final isEmpty = _textController.text.trim().isEmpty;
      if (_isInputEmpty != isEmpty) setState(() => _isInputEmpty = isEmpty);
    });

    _messages.sort((a, b) => a['time'].compareTo(b['time']));
  }

  // Окремий метод для завантаження історії
  Future<void> _loadHistory(String chatId) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/messages/$chatId'));
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        final String myId = UserSession().currentUser?.id.toString() ?? "";
        final String myNickname = UserSession().currentUser?.nickname ?? "You";

        setState(() {
          _messages = list.map((item) => {
            'id': item['id'].toString(),
            'content': item['content'],
            'sender_id': item['sender_id'].toString(),
            // ТУТ ПРАВИЛЬНА ЛОГІКА ДЛЯ ІСТОРІЇ:
            'sender_nickname': item['sender_nickname'] ??
                (item['sender_id'].toString() == myId ? myNickname : widget.friendName),
            'isMe': item['sender_id'].toString() == myId,
            'time': _parseDateTime(item['created_at']),
            'status': item['status'] ?? 'sent',
            'reply_to_id': item['reply_to_id'],
          }).toList();

          _messages.sort((a, b) => a['time'].compareTo(b['time']));
        });
        _handleInitialScroll();
      }
    } catch (e) {
      debugPrint("Помилка завантаження історії: $e");
    }
  }

  String? _friendAvatarUrl;

  Future<void> _markAsReadOnServer(String chatId) async {
    try {
      // ВАЖЛИВО: переконайся, що endpoint /messages/read/$chatId на бекенді
      // реально оновлює статус усіх повідомлень у цьому чаті на 'read'
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/messages/read/$chatId'),
        headers: await ApiService.getHeaders(),
      );
      if (response.statusCode == 200) {
        // Якщо сервер відповів ОК, оновлюємо UI
        _markMessagesAsReadUi(chatId);
      }
    } catch (e) {
      debugPrint("Помилка при спробі позначити як прочитане: $e");
    }
  }

// 2. Онови метод _initializeChat, щоб він тягнув інфу про друга
  Future<void> _initializeChat() async {
    print("DEBUG: Вхід у _initializeChat. chatId: '${widget.chatId}', friendId: '${widget.friendId}'");
    // 1. Якщо у нас вже є chatId (зі списку чатів), використовуємо його
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      setState(() => _activeChatId = widget.chatId);
    }
    // 2. Якщо немає, намагаємось отримати через friendId
    else if (widget.friendId != null) {
      try {
        final chatResponse = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/chats/get-or-create?recipient_id=${widget.friendId}'),
          headers: await ApiService.getHeaders(),
        );
        if (chatResponse.statusCode == 200) {
          final chatData = json.decode(chatResponse.body);
          if (chatData['chat_id'] != null) {
            setState(() => _activeChatId = chatData['chat_id'].toString());
          }
        }
      } catch (e) {
        debugPrint("Помилка ініціалізації чату: $e");
      }
    }

    // 3. ТІЛЬКИ ЯКЩО ми отримали _activeChatId, вантажимо все інше
    if (_activeChatId != null) {
      ChatManager().joinChat(_activeChatId!);
      _loadHistory(_activeChatId!); // Тепер chatId точно буде не порожнім!
      //_markAsRead(_activeChatId!);

      // Завантажуємо аватар, якщо є friendId
      if (widget.friendId != null) {
        _loadFriendAvatar(widget.friendId!);
      }
    } else {
      debugPrint("КРИТИЧНА ПОМИЛКА: Не вдалося отримати _activeChatId");
    }
  }

// Винесли окремо для чистоти
  Future<void> _loadFriendAvatar(String friendId) async {
    try {
      final userResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$friendId'),
        headers: await ApiService.getHeaders(),
      );
      if (userResponse.statusCode == 200 && userResponse.body.isNotEmpty) {
        final userData = json.decode(userResponse.body);
        setState(() => _friendAvatarUrl = userData['avatar']);
      }
    } catch (e) {
      debugPrint("Помилка завантаження аватара: $e");
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Даємо маленький час системі на зміну розміру вікна
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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

  void _addNewMessageToUi(Map<String, dynamic> messageData) {
    if (!mounted) return;

    final String senderId = messageData['sender_id'].toString();
    final String content = messageData['content'];
    final DateTime time = _parseDateTime(messageData['created_at'] ?? DateTime.now());

    // ПЕРЕВІРКА НА ДУБЛЬ:
    // Ми ігноруємо, якщо в списку вже є повідомлення з:
    // 1. Тим же контентом
    // 2. Тим же відправником
    // 3. І різниця в часі менше 10 секунд (це перекриває будь-який розсинхрон сервер/клієнт)
    final bool isDuplicate = _messages.any((m) =>
    m['content'] == content &&
        m['sender_id'] == senderId &&
        m['time'].difference(time).abs().inSeconds < 10
    );

    if (isDuplicate) {
      return; // Просто виходимо, нічого не додаємо
    }

    setState(() {
      _messages.add({
        'id': messageData['id'].toString(),
        'content': content,
        'sender_id': senderId,
        'sender_nickname': messageData.containsKey('sender_nickname')
            ? messageData['sender_nickname']
            : (senderId == UserSession().currentUser?.id.toString()
            ? UserSession().currentUser?.nickname ?? "You"
            : widget.friendName),
        'isMe': senderId == UserSession().currentUser?.id.toString(),
        'time': time,
        'reply_to_id': messageData.containsKey('reply_to_id') ? messageData['reply_to_id'] : null,
      });
      _messages.sort((a, b) => a['time'].compareTo(b['time']));
    });

    _handleInitialScroll();
  }

  final ScrollController _scrollController = ScrollController();

// Метод для прокрутки вниз
  Future<void> _handleInitialScroll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final myId = UserSession().currentUser?.id.toString();

    setState(() {
      _firstUnreadIndex = _messages.indexWhere((m) => m['sender_id'] != myId && m['status'] != 'read');
    });

    if (_firstUnreadIndex != -1) {
      final context = _messageKeys[_firstUnreadIndex]?.currentContext;
      if (context != null) {
        await Scrollable.ensureVisible(context, alignment: 0.2, duration: const Duration(milliseconds: 500));
      }
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _handleMessageAction(String action, Map<String, dynamic> message) {
    if (action == 'Edit') {
      setState(() {
        _messageToEdit = message;
        _textController.text = message['content'];
        _isInputEmpty = false;
      });
      _focusNode.requestFocus(); // Фокусуємо клавіатуру
    } else if (action == 'Reply') {
      setState(() {
        _messageToReply = message; // Зберігаємо повідомлення для відповіді
        _messageToEdit = null;
        _textController.clear(); // Очищаємо інпут для нової відповіді
      });
      _focusNode.requestFocus();
    } else if (action == 'Delete') {
      // Тут логіка видалення через API
    } else if (action == 'Copy') {
      // Копіювання в буфер обміну
    }
  }

  @override
  Widget build(BuildContext context) {
    final String initial = widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?';

    // Використовуємо MediaQuery прямо тут, Scaffold автоматично реагує на це через padding
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      resizeToAvoidBottomInset: true, // Вмикаємо нативний механізм
      body: Container(
        padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 0 : 0), // Scaffold сам підніме Padding
        child: Stack(
          children: [
            // Фон
            Positioned.fill(
              child: Image.asset(
                'assets/ChatBackground/$_currentBg',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.3),
              ),
            ),

            // Основний контент
            Column(
              children: [
                _buildHeader(initial),
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final bool isNewDay = index == 0 || !isSameDay(msg['time'], _messages[index - 1]['time']);
                          final status = MessageStatus.values.firstWhere(
                                (e) => e.name == (msg['status'] ?? 'sent'),
                            orElse: () => MessageStatus.sent,
                          );

                          return ChatMessageWidget(
                            key: _messageKeys[index] ?? ValueKey(index),
                            showDateDivider: isNewDay,
                            message: ChatMessage(
                              id: index.toString(),
                              content: msg['content']?.toString() ?? "",
                              senderId: msg['sender_id']?.toString() ?? "0",
                              senderName: msg['sender_nickname'] ?? "User",
                              timestamp: msg['time'] is DateTime ? msg['time'] : DateTime.now(),
                              isMe: msg['isMe'] ?? false,
                              status: status,
                              replyToId: msg['reply_to_id']?.toString(),
                            ),
                            allMessages: _messages,
                            onActionSelected: (action) => _handleMessageAction(action, msg),
                          );
                        },
                      ),
                      if (_showScrollDownButton)
                        Positioned(
                          right: 20,
                          bottom: 20,
                          child: GestureDetector(
                            onTap: () {
                              if (_activeChatId != null) {
                                _markAsReadOnServer(_activeChatId!); // Ось тут виклик API
                              }
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                            child: const FigmaScrollDownIcon(),
                          ),
                        ),
                    ],
                  ),
                ),
                // Поле вводу
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: _buildInput(),
                ),
              ],
            ),
          ],
        ),
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
                  Text(
                    _isTyping
                        ? "typing..."
                        : (_isConnected ? "online" : "connecting..."),
                    style: TextStyle(
                        color: _isTyping ? Colors.white : (_isConnected ? const Color(0xFF00F5A0) : Colors.orange),
                        fontSize: 10
                    ),
                  ),
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
    return Column(
      mainAxisSize: MainAxisSize.min, // Щоб займало мінімум місця
      children: [
        // 1. Прев'ю-блок для Reply (з'являється тільки якщо _messageToReply != null)
        if (_messageToReply != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF181826),
              border: Border.all(color: const Color(0xFF2B2B3B)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(width: 2, height: 30, color: const Color(0xFF00F5A0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Replying to ${widget.friendName}",
                          style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(_messageToReply!['content'],
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 10)),
                    ],
                  ),
                ),
                // Хрестик у реплаї: робимо неоново-зеленим, але залишаємо стандартний розмір
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(Color(0xFF00F5A0), BlendMode.srcIn),
                  child: FigmaCloseButton(
                    onTap: () {
                      setState(() {
                        _messageToEdit = null;
                        _messageToReply = null;
                        _textController.clear();
                      });
                      _focusNode.unfocus();
                    },
                  ),
                ),
              ],
            ),
          ),

        // 2. Основний інпут
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFF181826),
              border: Border.all(color: const Color(0xFF2B2B3B)),
              borderRadius: BorderRadius.circular(12)
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(padding: EdgeInsets.only(bottom: 8), child: FigmaAttachIcon()),
              const SizedBox(width: 8),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white),
                    maxLines: null,
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Write...",
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Кнопка скасування редагування: неоново-зелена і збільшена
                    if (_messageToEdit != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Transform.scale(
                          scale: 1.2,
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(Color(0xFF00F5A0), BlendMode.srcIn),
                            child: FigmaCloseButton(
                              onTap: () {
                                setState(() {
                                  _messageToEdit = null;
                                  _textController.clear();
                                });
                                _focusNode.unfocus();
                              },
                            ),
                          ),
                        ),
                      ),

                    // Кнопка відправки
                    _isInputEmpty
                        ? const FigmaSendInactiveIcon()
                        : GestureDetector(
                      onTap: () async {
                        final String myId = UserSession().currentUser?.id.toString() ?? "";
                        final String content = _textController.text.trim();

                        if (_activeChatId != null && content.isNotEmpty) {
                          if (_messageToEdit != null) {
                            // РЕЖИМ РЕДАГУВАННЯ
                            await _editMessageOnServer(_messageToEdit!['id'].toString(), content);
                            setState(() => _messageToEdit = null);
                          } else {
                            // РЕЖИМ ВІДПРАВКИ
                            final replyId = _messageToReply != null ? _messageToReply!['id'] : null;
                            _addNewMessageToUi({
                              'content': content,
                              'sender_id': myId,
                              'created_at': DateTime.now().toUtc().toIso8601String(),
                              'reply_to_id': replyId,
                            });
                            ChatManager().sendMessage(_activeChatId!, myId, content, replyTo: replyId);
                            setState(() => _messageToReply = null);
                          }
                          _textController.clear();
                        }
                      },
                      child: const FigmaSendActiveIcon(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Future<void> _editMessageOnServer(String messageId, String newContent) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/messages/$messageId'),
        headers: await ApiService.getHeaders(),
        body: json.encode({'content': newContent}),
      );

      if (response.statusCode == 200) {
        // Оновлюємо локальний список
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            _messages[index]['content'] = newContent;
          }
        });
      }
    } catch (e) {
      debugPrint("Помилка редагування: $e");
    }
  }

  Widget _buildReplyPreview() {
    if (_messageToReply == null) return const SizedBox.shrink();

    final String myId = UserSession().currentUser?.id.toString() ?? "";
    final String myNickname = UserSession().currentUser?.nickname ?? "You";

    // Якщо автор цитованого повідомлення — це ми, пишемо свій нік, інакше нік друга
    final String replyAuthor = (_messageToReply!['sender_id'].toString() == myId)
        ? myNickname
        : widget.friendName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF2B2B3B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(width: 2, height: 30, color: const Color(0xFF00F5A0)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(replyAuthor, style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 12, fontWeight: FontWeight.bold)),
                Text(_messageToReply!['content'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 10)),
              ],
            ),
          ),
          FigmaCloseButton(
            onTap: () => setState(() => _messageToReply = null),
          ),
        ],
      ),
    );
  }

}



enum MessageStatus { sent, delivered, read }
class ChatMessage {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final DateTime timestamp;
  final bool isMe;
  final MessageStatus status;
  final String? replyToId;

  ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.timestamp,
    required this.isMe,
    this.status = MessageStatus.sent,
    this.replyToId,
  });
}

class ChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final Function(String) onActionSelected;
  final bool showDateDivider;
  final List<Map<String, dynamic>> allMessages;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.onActionSelected,
    required this.allMessages,
    this.showDateDivider = false,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  bool _isLiked = false;
  final GlobalKey _messageKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showDateDivider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              DateFormat('d MMMM yyyy').format(widget.message.timestamp.toLocal()),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        Align(
          alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 1.0,
            child: Align(
              alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                key: _messageKey,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: GestureDetector(
                    // ВИПРАВЛЕНО ВИКЛИК: додано параметр widget.message.isMe
                    onLongPress: () => _showBlurActions(context, widget.message.isMe),
                    child: _buildMessageContainer(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    // Фіолетовий колір для "прочитано", інакше звичайний колір
    final Color iconColor = (status == MessageStatus.read)
        ? const Color(0xFF8C52FF)
        : (widget.message.isMe ? const Color(0xFF0F0F1A).withOpacity(0.6) : const Color(0xFF6E6E80));

    if (status == MessageStatus.sent) {
      return FigmaSingleCheckIcon(color: iconColor);
    } else {
      // delivered або read — обоє використовують подвійну пташку
      return FigmaDoubleCheckIcon(color: iconColor);
    }
  }

  Widget _buildMessageContainer() {
    String formattedTime = DateFormat('HH:mm').format(widget.message.timestamp.toLocal());
    final double maxWidth = MediaQuery.of(context).size.width * 0.75;

    // Логіка для пошуку повідомлення, на яке ми відповідаємо
    // Оскільки _messages в батьківському класі, ми шукаємо в ньому
    final replyMsg = (widget.message.replyToId != null)
        ? widget.allMessages.firstWhere((m) => m['id'] == widget.message.replyToId, orElse: () => {})
        : {};

    Widget replyBlock = const SizedBox.shrink();
    if (replyMsg.isNotEmpty) {
      final String myId = UserSession().currentUser?.id.toString() ?? "";
      final String myNickname = UserSession().currentUser?.nickname ?? "You";

      // Логіка визначення імені автора цитати
      final String authorName = (replyMsg['sender_id'].toString() == myId)
          ? myNickname
          : (replyMsg['sender_nickname'] ?? "Friend");

      replyBlock = Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.message.isMe ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          border: Border(left: BorderSide(color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0), width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(authorName, style: TextStyle(color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0), fontSize: 10, fontWeight: FontWeight.bold)),
            Text(replyMsg['content'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.message.isMe ? const Color(0xFF0F0F1A).withOpacity(0.7) : Colors.white70, fontSize: 12)),
          ],
        ),
      );
    }

    Widget timeAndStatus = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formattedTime,
            style: TextStyle(
                color: widget.message.isMe ? const Color(0xFF0F0F1A).withOpacity(0.6) : const Color(0xFF6E6E80),
                fontSize: 10
            )
        ),
        if (widget.message.isMe) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(widget.message.status),
        ],
      ],
    );

    Widget messageBox = Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: widget.message.isMe ? const Color(0xFF00F5A0) : const Color(0xFF181826),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 4,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              replyBlock, // Доданий блок відповіді
              Text(
                widget.message.content,
                style: TextStyle(
                  color: widget.message.isMe ? const Color(0xFF0F0F1A) : Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          timeAndStatus,
        ],
      ),
    );

    Widget reactionIcon = GestureDetector(
      onTap: () => setState(() => _isLiked = !_isLiked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          _isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
          size: 14,
          color: _isLiked ? const Color(0xFF00F5A0) : const Color(0xFF6E6E80),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: widget.message.isMe
          ? [reactionIcon, messageBox]
          : [messageBox, reactionIcon],
    );
  }

  void _showBlurActions(BuildContext context, bool isMe) {
    final RenderBox? renderBox = _messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;

    // Формуємо список елементів меню
    List<Map<String, dynamic>> menuItems = [
      {"title": "Reply", "icon": const FigmaReplyIcon(), "color": const Color(0xFF00F5A0)},
      {"title": "Copy", "icon": const FigmaCopyIcon(), "color": const Color(0xFF00F5A0)},
      {"title": "Forward", "icon": const FigmaForwardIcon(), "color": const Color(0xFF00F5A0), "isForward": true},
    ];

    if (isMe) {
      menuItems.insert(1, {"title": "Edit", "icon": const FigmaEditIcon(), "color": const Color(0xFF00F5A0)});
      menuItems.add({"title": "Delete", "icon": const FigmaDeleteIcon(), "color": const Color(0xFFFF6B6B)});
    }

    // Висота меню залежить від кількості елементів (приблизно 35px на елемент)
    final double menuHeight = menuItems.length * 35.0 + 20;
    final bool showAbove = (position.dy + size.height + menuHeight) > (screenHeight - 50);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Menu",
      pageBuilder: (ctx, _, __) => Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          Positioned(
            top: position.dy + 4,
            right: widget.message.isMe ? 16 : null,
            left: !widget.message.isMe ? 16 : null,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: size.width,
                child: Align(
                  alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: _buildMessageContainer(),
                ),
              ),
            ),
          ),
          Positioned(
            top: showAbove ? position.dy - menuHeight - 3 : position.dy + size.height + 1,
            right: widget.message.isMe ? 16 : null,
            left: !widget.message.isMe ? 16 : null,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 112,
                height: menuHeight,
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2B3B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: menuItems.map((item) => _buildMenuItem(
                      item["title"],
                      item["icon"],
                      item["color"],
                      ctx,
                      isForward: item["isForward"] ?? false
                  )).toList(),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, Widget iconWidget, Color color, BuildContext ctx, {bool isForward = false}) {
    return GestureDetector(
      onTap: () {
        widget.onActionSelected(title);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Transform(
            alignment: Alignment.center,
            transform: isForward ? Matrix4.rotationY(pi) : Matrix4.identity(),
            child: iconWidget,
          ),
          const SizedBox(width: 15),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


}

