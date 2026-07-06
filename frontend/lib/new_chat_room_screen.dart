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

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final List<String> _backgrounds = ['1.webp', '2.webp', '3.webp'];
  late String _currentBg;
  final TextEditingController _textController = TextEditingController();
  bool _isInputEmpty = true;
  List<Map<String, dynamic>> _messages = [];
  bool _showScrollDownButton = false;
  final Map<int, GlobalKey> _messageKeys = {};
  int _firstUnreadIndex = -1;
  final FocusNode _focusNode = FocusNode();

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

    _scrollController.addListener(() {
      if (!mounted) return;
      // Показуємо кнопку, якщо ми не в самому низу
      final bool isNearBottom = _scrollController.offset >= (_scrollController.position.maxScrollExtent - 200);
      if (_showScrollDownButton == isNearBottom) {
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

        setState(() {
          _messages = list.map((item) => {
            'content': item['content'],
            'sender_id': item['sender_id'].toString(),
            'isMe': item['sender_id'].toString() == myId,
            'time': _parseDateTime(item['created_at']),
            'status': item['status'] ?? 'sent', // <--- ВАЖЛИВО: беремо статус
          }).toList();
          for (int i = 0; i < _messages.length; i++) {
            _messageKeys[i] = GlobalKey();
          }
          _messages.sort((a, b) => a['time'].compareTo(b['time']));
        });
        _handleInitialScroll();
      }
    } catch (e) {
      debugPrint("Помилка завантаження історії: $e");
    }
  }

  String? _friendAvatarUrl;

  Future<void> _markAsRead(String chatId) async {
    try {
      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/messages/read/$chatId'),
        headers: await ApiService.getHeaders(),
      );
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
        'content': content,
        'sender_id': senderId,
        'isMe': senderId == UserSession().currentUser?.id.toString(),
        'time': time,
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

  @override
  Widget build(BuildContext context) {
    final String initial = widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?';

    // Беремо висоту екрана і віднімаємо клавіатуру прямо тут
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double usableHeight = screenHeight - keyboardHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      resizeToAvoidBottomInset: false, // МИ САМІ КЕРУЄМО ВИСОТОЮ
      body: SizedBox(
        height: usableHeight, // Фіксуємо висоту контейнера
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/ChatBackground/$_currentBg',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.3),
              ),
            ),
            Column(
              children: [
                _buildHeader(initial),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return ChatMessageWidget(
                        key: _messageKeys[index] ?? ValueKey(index),
                        showDateDivider: index == 0 || !isSameDay(msg['time'], _messages[index - 1]['time']),
                        message: ChatMessage(
                          id: index.toString(),
                          content: msg['content'],
                          senderId: msg['sender_id'],
                          senderName: "User",
                          timestamp: msg['time'],
                          isMe: msg['isMe'] ?? false,
                          status: MessageStatus.values.firstWhere((e) => e.name == (msg['status'] ?? 'sent'), orElse: () => MessageStatus.sent),
                        ),
                        onActionSelected: (a) {},
                      );
                    },
                  ),
                ),
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
    return Container(
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
                    style: const TextStyle(color: Colors.white),
                    maxLines: null,
                    onTap: () {
                      // Скрол до низу з маленькою затримкою, щоб клавіатура вже почала підніматися
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
                        contentPadding: EdgeInsets.symmetric(vertical: 8)
                    )
                ),
              )
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _isInputEmpty
                ? const FigmaSendInactiveIcon()
                : GestureDetector(
              onTap: () {
                final String myId = UserSession().currentUser?.id.toString() ?? "";
                final String content = _textController.text.trim();

                if (_activeChatId != null && content.isNotEmpty) {
                  _addNewMessageToUi({
                    'content': content,
                    'sender_id': myId,
                    'created_at': DateTime.now().toUtc().toIso8601String(),
                  });

                  ChatManager().sendMessage(_activeChatId!, myId, content);
                  _textController.clear();
                }
              },
              child: const FigmaSendActiveIcon(),
            ),
          ),
        ],
      ),
    );
  }
  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
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

  ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.timestamp,
    required this.isMe,
    this.status = MessageStatus.sent,
  });
}

class ChatMessageWidget extends StatefulWidget {
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
              style: const TextStyle(color: Color(0xFF6E6E80), fontSize: 10),
            ),
          ),
        Align(
          alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 1.0,
            child: Align(
              alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
              // ЗАЛИШАЄМО ЛИШЕ ЦЕЙ КОНТЕЙНЕР З MARGIN ТА KEY
              child: Container(
                key: _messageKey,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: GestureDetector(
                    onLongPress: () => _showBlurActions(context),
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
          _buildStatusIcon(widget.message.status), // <--- ВИКОРИСТОВУЄМО НАШУ ЛОГІКУ
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
      // Використовуємо Wrap, який є безпечним і стабільним у списках
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 4,
        children: [
          Text(
            widget.message.content,
            style: TextStyle(
              color: widget.message.isMe ? const Color(0xFF0F0F1A) : Colors.white,
              fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter',
            ),
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

  void _showBlurActions(BuildContext context) {
    final RenderBox? renderBox = _messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;

    const double menuHeight = 220.0;
    // Рахуємо, чи влізе меню знизу, з урахуванням відступу від краю
    final bool showAbove = (position.dy + size.height + menuHeight) > (screenHeight - 50);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Menu",
      pageBuilder: (ctx, _, __) => Stack(
        children: [
          // 1. Блюр
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),

          // 2. Чітке повідомлення
          Positioned(
            top: position.dy + 4,
            // Якщо моє -> прив'язуємо правий край до 16, лівий автоматичний (null)
            // Якщо чуже -> прив'язуємо лівий край до 16, правий автоматичний (null)
            right: widget.message.isMe ? 16 : null,
            left: !widget.message.isMe ? 16 : null,
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  // Вказуємо ширину оригінального віджета, щоб воно не деформувалось
                  width: size.width,
                  child: Align(
                    // Align змушує вміст притискатися до потрібної сторони всередині виділеного місця
                    alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: _buildMessageContainer(),
                  ),
                ),
              ),
            ),
          ),

          // 3. Меню
          Positioned(
            top: showAbove ? position.dy - menuHeight -3 : position.dy + size.height + 1,
            right: widget.message.isMe ? 16 : null,
            left: !widget.message.isMe ? 16 : null,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF181826),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ['Reply', 'Edit', 'Copy', 'Delete'].map((a) => ListTile(
                    title: Text(a, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    onTap: () {
                      widget.onActionSelected(a);
                      Navigator.pop(ctx);
                    },
                  )).toList(),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

