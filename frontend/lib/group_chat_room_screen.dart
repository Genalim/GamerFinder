import 'package:flutter/material.dart';
import 'dart:math';
import 'custom_widgets.dart';
import 'chat_group_info_screen.dart';
import 'services/chat_manager.dart';
import 'api_config.dart';
import 'package:http/http.dart' as http;
import 'user_session.dart';
import 'dart:convert';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
// Зверни увагу: нам потрібен ChatMessageWidget, ChatMessage, MessageStatus і getCleanContent
// Якщо вони лежать в chat_room_screen.dart, краще винести їх в окремий файл (наприклад, chat_components.dart)
// Або тимчасово імпортувати з chat_room_screen.dart, якщо Dart дозволить без конфліктів.
// Для надійності, я додав їх копії в кінець цього файлу (як ти робив раніше), щоб все працювало "з коробки".

class GroupChatRoomScreen extends StatefulWidget {
  final List<String> participantNames;
  final String chatId;
  final VoidCallback onBack;

  const GroupChatRoomScreen({
    super.key,
    required this.participantNames,
    required this.chatId,
    required this.onBack,
  });

  @override
  State<GroupChatRoomScreen> createState() => _GroupChatRoomScreenState();
}

class _GroupChatRoomScreenState extends State<GroupChatRoomScreen> with WidgetsBindingObserver {
  final List<String> _backgrounds = ['1.webp', '2.webp', '3.webp'];
  late String _currentBg;
  final TextEditingController _textController = TextEditingController();
  bool _isInputEmpty = true;

  // --- Змінні для повідомлень ---
  List<Map<String, dynamic>> _messages = [];
  bool _showScrollDownButton = false;
  final Map<int, GlobalKey> _messageKeys = {};
  int _firstUnreadIndex = -1;
  final FocusNode _focusNode = FocusNode();
  Map<String, dynamic>? _messageToEdit;
  Map<String, dynamic>? _messageToReply;
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();
  String? _groupName;

  int _currentOffset = 0;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, int>> _foundMatches = [];
  List<int> _foundIndices = [];
  int _currentFoundIndex = -1;

  Map<String, dynamic>? _groupData;

  @override
  void initState() {
    super.initState();
    _fetchGroupInfo();
    _groupName = "New Group";
    WidgetsBinding.instance.addObserver(this);
    _currentBg = _backgrounds[Random().nextInt(_backgrounds.length)];

    // --- Ініціалізація чату ---
    final myId = UserSession().currentUser?.id.toString() ?? "";
    ChatManager().init(myId);
    ChatManager().joinChat(widget.chatId);
    _loadHistory(widget.chatId);

    // --- Підписки на сокети ---
    ChatManager().socket?.off('new_message');
    ChatManager().socket?.on('new_message', _addNewMessageToUi);

    ChatManager().socket?.off('messages_read');
    ChatManager().socket?.on('messages_read', (data) {
      if (data['chat_id'] == widget.chatId) _markMessagesAsReadUi();
    });

    ChatManager().socket?.on('user_typing', (data) {
      if (data['chat_id'] == widget.chatId) {
        setState(() => _isTyping = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }
    });

    ChatManager().socket?.off('message_edited');
    ChatManager().socket?.on('message_edited', (data) {
      if (!mounted) return;
      if (data['chat_id'] == widget.chatId) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == data['message_id'].toString());
          if (index != -1) _messages[index]['content'] = data['new_content'];
        });
      }
    });

    ChatManager().socket?.on('reaction_updated', (data) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == data['message_id']);
        if (index != -1) {
          _messages[index]['likes_count'] = data['count'];
          _messages[index]['is_liked_by_me'] = data['is_liked_by_me'];
        }
      });
    });

    ChatManager().socket?.off('message_deleted');
    ChatManager().socket?.on('message_deleted', (data) {
      if (!mounted) return;
      if (data['chat_id'] == widget.chatId) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == data['message_id'].toString());
        });
      }
    });

    // --- Логіка ScrollController ---
    _scrollController.addListener(() {
      if (!mounted) return;
      final bool isNearBottom = _scrollController.offset >= (_scrollController.position.maxScrollExtent - 50);

      if (isNearBottom) {
        bool hasUnread = _messages.any((m) => m['sender_id'] != myId && m['status'] != 'read');
        if (hasUnread) _markAsReadOnServer(widget.chatId);
      }

      if (_showScrollDownButton != !isNearBottom) {
        setState(() => _showScrollDownButton = !isNearBottom);
      }
    });

    // --- Логіка вводу тексту ---
    _textController.addListener(() {
      if (_textController.text.isNotEmpty) {
        ChatManager().socket?.emit('typing', {'chat_id': widget.chatId});
      }
      final isEmpty = _textController.text.trim().isEmpty;
      if (_isInputEmpty != isEmpty) setState(() => _isInputEmpty = isEmpty);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _restoreFocus() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _fetchGroupInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/${widget.chatId}/info'),
        headers: await ApiService.getHeaders(),
      );
      if (response.statusCode == 200) {
        setState(() {
          _groupData = json.decode(response.body);
          _groupName = _groupData?['name']; // Оновлюємо назву з бази
        });
      }
    } catch (e) { debugPrint("Помилка завантаження інфо: $e"); }
  }

  // --- МЕТОДИ ДЛЯ РОБОТИ З ПОВІДОМЛЕННЯМИ ---

  Future<void> _loadHistory(String chatId, {bool isLoadMore = false}) async {
    if (_isLoadingMore || (!_hasMoreMessages && isLoadMore)) return;

    setState(() => _isLoadingMore = true);

    try {
      // Додаємо ліміт та офсет
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/messages/$chatId?limit=30&offset=$_currentOffset'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);

        if (list.isEmpty) {
          setState(() => _hasMoreMessages = false);
        } else {
          final String myId = UserSession().currentUser?.id.toString() ?? "";
          final String myNickname = UserSession().currentUser?.nickname ?? "You";

          final newMessages = list.map((item) => {
            'id': item['id'].toString(),
            'content': item['content'],
            'sender_id': item['sender_id'].toString(),
            'sender_nickname': item['sender_nickname'] ?? (item['sender_id'].toString() == myId ? myNickname : "Member"),
            'isMe': item['sender_id'].toString() == myId,
            'time': _parseDateTime(item['created_at']),
            'status': item['status'] ?? 'sent',
            'reply_to_id': item['reply_to_id'],
            'likes_count': item['likes_count'] ?? 0,
            'is_liked_by_me': item['is_liked_by_me'] ?? false,
          }).toList();

          setState(() {
            if (isLoadMore) {
              // Додаємо старі повідомлення в початок списку
              _messages = [...newMessages, ..._messages];
            } else {
              _messages = newMessages;
            }

            _messages.sort((a, b) => a['time'].compareTo(b['time']));
            _currentOffset += list.length; // Зсуваємо офсет
          });
        }
      }
    } catch (e) {
      debugPrint("Помилка завантаження історії: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  DateTime _parseDateTime(dynamic timeData) {
    if (timeData is DateTime) return timeData;
    String timeString = timeData.toString();
    if (!timeString.contains('Z') && !timeString.contains('+')) {
      timeString += 'Z';
    }
    return DateTime.parse(timeString).toLocal();
  }

  void _addNewMessageToUi(dynamic messageData) {
    if (!mounted || messageData['chat_id'] != widget.chatId) return;

    final String senderId = messageData['sender_id'].toString();
    final String content = messageData['content'];
    final DateTime time = _parseDateTime(messageData['created_at'] ?? DateTime.now());

    final bool isDuplicate = _messages.any((m) =>
    m['content'] == content &&
        m['sender_id'] == senderId &&
        m['time'].difference(time).abs().inSeconds < 10
    );

    if (isDuplicate) return;

    setState(() {
      _messages.add({
        'id': messageData['id'].toString(),
        'content': content,
        'sender_id': senderId,
        'sender_nickname': messageData.containsKey('sender_nickname')
            ? messageData['sender_nickname']
            : (senderId == UserSession().currentUser?.id.toString() ? "You" : "Member"),
        'isMe': senderId == UserSession().currentUser?.id.toString(),
        'time': time,
        'reply_to_id': messageData.containsKey('reply_to_id') ? messageData['reply_to_id'] : null,
      });
      _messages.sort((a, b) => a['time'].compareTo(b['time']));
    });
    _handleInitialScroll();
  }

  Future<void> _handleInitialScroll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _markMessagesAsReadUi() {
    if (!mounted) return;
    final String myId = UserSession().currentUser?.id.toString() ?? "";
    setState(() {
      for (var msg in _messages) {
        if (msg['sender_id'] != myId && msg['status'] != 'read') {
          msg['status'] = 'read';
        }
      }
    });
  }

  Future<void> _markAsReadOnServer(String chatId) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/messages/read/$chatId'),
        headers: await ApiService.getHeaders(),
      );
      if (response.statusCode == 200) _markMessagesAsReadUi();
    } catch (e) {
      debugPrint("Помилка read: $e");
    }
  }

  void _handleMessageAction(String action, Map<String, dynamic> message) {
    final String cleanContent = getCleanContentGroup(message['content'].toString());

    if (action == 'Edit') {
      setState(() {
        _messageToEdit = message;
        _textController.text = cleanContent;
        _isInputEmpty = false;
      });
      _focusNode.requestFocus();
    } else if (action == 'Reply') {
      setState(() {
        _messageToReply = message;
        _messageToEdit = null;
        _textController.clear();
      });
      _focusNode.requestFocus();
    } else if (action == 'Delete') {
      _deleteMessage(message['id'].toString());
    } else if (action == 'Copy') {
      Clipboard.setData(ClipboardData(text: cleanContent)).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied"), backgroundColor: Color(0xFF181826), duration: Duration(seconds: 1)));
      });
    } else if (action == 'Like') {
      _toggleReaction(message['id'].toString());
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/messages/$messageId'), headers: await ApiService.getHeaders());
      if (response.statusCode == 200) {
        setState(() => _messages.removeWhere((m) => m['id'] == messageId));
      }
    } catch (e) { debugPrint("Помилка видалення: $e"); }
  }

  Future<void> _editMessageOnServer(String messageId, String newContent) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/messages/$messageId'),
        headers: await ApiService.getHeaders(),
        body: json.encode({'content': newContent}),
      );
      if (response.statusCode == 200) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) _messages[index]['content'] = newContent;
        });
      }
    } catch (e) { debugPrint("Помилка редагування: $e"); }
  }

  Future<void> _toggleReaction(String messageId) async {
    final index = _messages.indexWhere((m) => m['id'] == messageId);
    if (index == -1) return;

    setState(() {
      final bool oldState = _messages[index]['is_liked_by_me'] ?? false;
      _messages[index]['is_liked_by_me'] = !oldState;
      final int currentCount = _messages[index]['likes_count'] ?? 0;
      _messages[index]['likes_count'] = !oldState ? currentCount + 1 : currentCount - 1;
    });

    try {
      await http.post(Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/react'), headers: await ApiService.getHeaders());
    } catch (e) {
      setState(() => _messages[index]['is_liked_by_me'] = !(_messages[index]['is_liked_by_me']));
    }
  }

  void _scrollToFoundMessage() {
    if (_foundMatches.isEmpty || _currentFoundIndex == -1) return;
    // Беремо індекс повідомлення з об'єкта
    int msgIndex = _foundMatches[_currentFoundIndex]['messageIndex']!;

    final key = _messageKeys[msgIndex];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(key.currentContext!, duration: const Duration(milliseconds: 300), alignment: 0.5);
    }
  }

  // --- ВІДМАЛЬОВКА ЕКРАНУ ---

  @override
  Widget build(BuildContext context) {
    final String displayName = _groupName ?? "New Group";
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      resizeToAvoidBottomInset: true,
      body: Container(
        padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 0 : 0),
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
                _buildHeader(displayName),
                Expanded(
                  child: Stack(
                    children: [
                      _messages.isEmpty
                          ? const Center(
                        child: Text("No messages yet", style: TextStyle(color: Color(0xFF8E8EA9))),
                      )
                          : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          // Якщо користувач скролить вгору до упору
                          if (scrollInfo.metrics.pixels == scrollInfo.metrics.minScrollExtent &&
                              !_isLoadingMore &&
                              _hasMoreMessages) {
                            _loadHistory(widget.chatId, isLoadMore: true);
                            return true;
                          }
                          return false;
                        },
                        child: ListView.builder(

                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _messages.length, // Завжди повний список
                          itemBuilder: (context, index) {
                            final msg = _messages[index];

                            // Перевіряємо, чи це повідомлення зараз "активне" в пошуку
                            final bool isHighlighted = _isSearching &&
                                _foundMatches.any((m) => m['messageIndex'] == index);;

                            final bool isNewDay = index == 0 || !isSameDayGroup(msg['time'], _messages[index - 1]['time']);

                            final status = GroupMessageStatus.values.firstWhere(
                                  (e) => e.name == (msg['status'] ?? 'sent'),
                              orElse: () => GroupMessageStatus.sent,
                            );

                            return GroupChatMessageWidget(
                              key: _messageKeys[index] = GlobalKey(), // Зберігаємо ключ для скролу
                              searchQuery: _searchController.text,
                              currentMatchIndex: _currentFoundIndex, // Передаємо індекс
                              messageIndex: index,                  // Передаємо індекс повідомлення
                              foundMatches: _foundMatches,
                              showDateDivider: isNewDay,
                              isHighlighted: isHighlighted,
                              likesCount: msg['likes_count'] ?? 0,
                              isLikedByMe: msg['is_liked_by_me'] ?? false,
                              message: GroupChatMessage(
                                id: msg['id'].toString(),
                                content: msg['content']?.toString() ?? "",
                                senderId: msg['sender_id']?.toString() ?? "0",
                                senderName: msg['sender_nickname'] ?? "Member",
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
                      ),
                      if (_showScrollDownButton)
                        Positioned(
                          right: 20,
                          bottom: 20,
                          child: GestureDetector(
                            onTap: () {
                              _markAsReadOnServer(widget.chatId);
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

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _foundMatches = [];
        _currentFoundIndex = -1;
      });
      return;
    }

    setState(() {
      _foundMatches = []; // Тут ми будемо тримати ВСІ збіги (кожна літера = елемент)
      String q = query.toLowerCase();

      for (int i = 0; i < _messages.length; i++) {
        String content = _messages[i]['content'].toString().toLowerCase();
        int index = content.indexOf(q);
        while (index != -1) {
          // Додаємо кожне входження окремо
          _foundMatches.add({'messageIndex': i, 'matchIndex': index});
          index = content.indexOf(q, index + 1);
        }
      }
      // Тепер _foundMatches.length - це реальна кількість літер 'g'
      _currentFoundIndex = _foundMatches.isNotEmpty ? _foundMatches.length - 1 : -1;
      _scrollToFoundMessage();
    });
  }

  Widget _buildHeader(String displayName) {
    // --- РЕЖИМ ПОШУКУ (ТВІЙ КОД - БЕЗ ЗМІН) ---
    if (_isSearching) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 57, 12, 0),
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF181826),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B2B3B)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 20, height: 20, child: FittedBox(child: FigmaSearchIcon())),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Search...",
                    hintStyle: TextStyle(color: Color(0xFF8E8EA9)),
                    border: InputBorder.none,
                  ),
                  onChanged: _performSearch,
                ),
              ),
              if (_foundMatches.isNotEmpty) ...[
                Text("${_currentFoundIndex + 1}/${_foundMatches.length}",
                    style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 12)),
                GestureDetector(
                  onTap: () {
                    setState(() => _currentFoundIndex = (_currentFoundIndex + 1) % _foundMatches.length);
                    _scrollToFoundMessage();
                  },
                  child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _currentFoundIndex = (_currentFoundIndex - 1 + _foundMatches.length) % _foundMatches.length);
                    _scrollToFoundMessage();
                  },
                  child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                ),
              ],
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _foundIndices.clear();
                  _currentFoundIndex = -1;
                }),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Color(0xFF00F5A0), BlendMode.srcIn),
                  child: FigmaCloseButton(
                    onTap: () => setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      _foundIndices.clear();
                      _currentFoundIndex = -1;
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- ЗВИЧАЙНИЙ РЕЖИМ ---
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 57, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: const SizedBox(width: 40, height: 40, child: ChatBackIcon(size: 24)),
          ),

          // --- КОНТЕНТ ХЕДЕРА ---
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatGroupInfoScreen(chatId: widget.chatId)),
              );
              if (result == 'open_search') {
                setState(() => _isSearching = true);
              } else {
                _fetchGroupInfo(); // Оновлюємо дані при поверненні
              }
            },
            child: Row(
              children: [
                _buildGroupAvatar(),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Назва групи
                    Text(_groupName ?? displayName, style: const TextStyle(color: Colors.white, fontSize: 18)),
                    // Статус: тайпінг або кількість учасників
                    Text(
                      _isTyping
                          ? "typing..."
                          : (_groupData != null ? "${(_groupData!['members'] as List).length} members | 1 online" : "group"),
                      style: TextStyle(
                        color: _isTyping ? Colors.white : const Color(0xFFA0A0B0),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ІКОНКА ІНФО
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatGroupInfoScreen(chatId: widget.chatId)),
              );
              if (result == 'open_search') {
                setState(() => _isSearching = true);
              } else {
                _fetchGroupInfo();
              }
            },
            child: const FigmaGroupInfoIcon(size: 45),
          ),
        ],
      ),
    );
  }



  Widget _buildGroupAvatar() {
    if (_groupData == null) return const SizedBox(width: 45, height: 45);

    final String? avatarUrl = _groupData!['avatar_url'];
    final List<dynamic> members = _groupData!['members'] ?? [];

    return SizedBox(
      width: 45,
      height: 45,
      child: ClipOval(
        child: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? Image.network(avatarUrl, fit: BoxFit.cover)
            : _buildAvatarGridSmall(members.take(4).toList()),
      ),
    );
  }

  Widget _buildAvatarGridSmall(List<dynamic> members) {
    final displayMembers = members.take(4).toList();

    return Center(
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        alignment: WrapAlignment.center,
        children: displayMembers.map((m) {
          final String initial = (m['nickname']?.isNotEmpty ?? false) ? m['nickname'][0].toUpperCase() : '?';
          final String? avatar = m['avatar'];

          // Логіка адаптації:
          // Якщо учасник один — він займає майже все місце (34),
          // якщо їх більше (2-4) — вони маленькі (16).
          final double avatarSize = displayMembers.length == 1 ? 34 : 17;
          final double containerSize = displayMembers.length == 1 ? 36 : 17;

          return Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00F5A0), width: 0.8),
            ),
            alignment: Alignment.center,
            child: ClipOval(
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: buildAvatar(avatar, initial, avatarSize),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildAvatar(String? avatarUrl, String initial, double size) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildLetterAvatar(initial, size); // Передаємо size
    }
    if (avatarUrl.startsWith('http')) {
      return Image.network(
        avatarUrl, width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial, size),
      );
    }
    return Image.asset(
      avatarUrl, width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial, size),
    );
  }

  Widget _buildLetterAvatar(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Color(0xFF0F0F13), shape: BoxShape.circle),
      child: Center(
        // Розмір шрифту теж зробимо динамічним залежно від size
        child: Text(
            initial,
            style: TextStyle(
                fontFamily: 'Love Light',
                fontSize: size * 0.6, // Шрифт буде ~60% від розміру аватарки
                color: const Color(0xFF00F5A0)
            )
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_messageToReply != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF2B2B3B)), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Container(width: 2, height: 30, color: const Color(0xFF00F5A0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Replying", style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(_messageToReply!['content'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 10)),
                    ],
                  ),
                ),
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(Color(0xFF00F5A0), BlendMode.srcIn),
                  child: FigmaCloseButton(onTap: () {
                    setState(() { _messageToReply = null; _messageToEdit = null; _textController.clear(); });
                    _focusNode.unfocus();
                  }),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF2B2B3B)), borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(padding: EdgeInsets.only(bottom: 8), child: FigmaAttachIcon()),
              const SizedBox(width: 8),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: TextField(
                    controller: _textController, focusNode: _focusNode, style: const TextStyle(color: Colors.white), maxLines: null,
                    onChanged: (text) {
                      // Примусово оновлюємо стан кнопки при кожному натисканні клавіші
                      setState(() {
                        _isInputEmpty = text.trim().isEmpty;
                      });
                    },
                    decoration: const InputDecoration(border: InputBorder.none, hintText: "Write...", isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (_messageToEdit != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Transform.scale(
                          scale: 1.2,
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(Color(0xFF00F5A0), BlendMode.srcIn),
                            child: FigmaCloseButton(onTap: () {
                              setState(() { _messageToEdit = null; _textController.clear(); });
                              _focusNode.unfocus();
                            }),
                          ),
                        ),
                      ),
                    _isInputEmpty
                        ? const FigmaSendInactiveIcon()
                        : GestureDetector(
                      onTap: () async {
                        final String myId = UserSession().currentUser?.id.toString() ?? "";
                        final String content = _textController.text.trim();
                        if (content.isNotEmpty) {
                          if (_messageToEdit != null) {
                            await _editMessageOnServer(_messageToEdit!['id'].toString(), content);
                            setState(() => _messageToEdit = null);
                          } else {
                            final replyId = _messageToReply != null ? _messageToReply!['id'] : null;
                            _addNewMessageToUi({
                              'content': content, 'sender_id': myId, 'created_at': DateTime.now().toUtc().toIso8601String(), 'reply_to_id': replyId,
                            });
                            ChatManager().sendMessage(widget.chatId, myId, content, replyTo: replyId);
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
}

// --- ДОПОМІЖНІ КЛАСИ ТА ВІДЖЕТИ ДЛЯ ГРУПИ (Щоб не конфліктувати з ChatRoomScreen) ---

bool isSameDayGroup(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

String getCleanContentGroup(String content) {
  if (content.startsWith('[FWD:')) {
    final endIdx = content.indexOf(']');
    if (endIdx != -1) return content.substring(endIdx + 1);
  }
  return content;
}

enum GroupMessageStatus { sent, delivered, read }

class GroupChatMessage {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final bool isMe;
  final GroupMessageStatus status;
  final String? replyToId;

  GroupChatMessage({
    required this.id, required this.content, required this.senderId, required this.senderName,
    required this.timestamp, required this.isMe, this.status = GroupMessageStatus.sent, this.replyToId,
  });
}

class GroupChatMessageWidget extends StatefulWidget {
  final GroupChatMessage message;
  final int likesCount;
  final bool isLikedByMe;
  final Function(String) onActionSelected;
  final bool showDateDivider;
  final List<Map<String, dynamic>> allMessages;
  final bool isHighlighted;
  final String searchQuery;
  final int currentMatchIndex;
  final int messageIndex;
  final List<Map<String, int>> foundMatches;

  const GroupChatMessageWidget({
    super.key, required this.message, required this.likesCount, required this.isLikedByMe,
    required this.onActionSelected, required this.allMessages, this.showDateDivider = false,
    this.isHighlighted = false,
    required this.searchQuery,
    required this.currentMatchIndex,
    required this.messageIndex,
    required this.foundMatches,
  });

  @override
  State<GroupChatMessageWidget> createState() => _GroupChatMessageWidgetState();
}

class _GroupChatMessageWidgetState extends State<GroupChatMessageWidget> {
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
                // Підсвітка: додаємо прозорий фон поверх всього контейнера, якщо знайдено
                decoration: widget.isHighlighted
                    ? BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                )
                    : null,
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: GestureDetector(
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

  Widget _buildStatusIcon(GroupMessageStatus status) {
    final Color iconColor = (status == GroupMessageStatus.read) ? const Color(0xFF8C52FF) : (widget.message.isMe ? const Color(0xFF0F0F1A).withOpacity(0.6) : const Color(0xFF6E6E80));
    return status == GroupMessageStatus.sent ? FigmaSingleCheckIcon(color: iconColor) : FigmaDoubleCheckIcon(color: iconColor);
  }

  Widget _buildMessageContainer() {
    String rawContent = widget.message.content;
    String? fwdName;
    String formattedTime = DateFormat('HH:mm').format(widget.message.timestamp.toLocal());
    final double maxWidth = MediaQuery.of(context).size.width * 0.75;

    final replyMsg = (widget.message.replyToId != null) ? widget.allMessages.firstWhere((m) => m['id'] == widget.message.replyToId, orElse: () => {}) : {};

    if (rawContent.startsWith('[FWD:')) {
      final match = RegExp(r'^\[FWD:([^\]]+)\](.*)').firstMatch(rawContent);
      if (match != null) fwdName = match.group(1);
    }

    Widget replyBlock = replyMsg.isNotEmpty ? Container(
      margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.message.isMe ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        border: Border(left: BorderSide(color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(replyMsg['sender_nickname'] ?? "Member", style: TextStyle(color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0), fontSize: 10, fontWeight: FontWeight.bold)),
          Text(replyMsg['content'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.message.isMe ? const Color(0xFF0F0F1A).withOpacity(0.7) : Colors.white70, fontSize: 12)),
        ],
      ),
    ) : const SizedBox.shrink();

    Widget forwardBlock = fwdName != null ? Container(
      margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.message.isMe ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        border: Border(left: BorderSide(color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0), width: 2)),
      ),
      child: Text("Forwarded from $fwdName", style: TextStyle(color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0), fontSize: 10, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
    ) : const SizedBox.shrink();

    Widget messageBox = Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: widget.message.isMe ? const Color(0xFF00F5A0) : const Color(0xFF181826),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Wrap(
        alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.end, spacing: 4,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ІМ'Я ВІДПРАВНИКА В ГРУПІ (тільки якщо не ми відправили)
              if (!widget.message.isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(widget.message.senderName, style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              replyBlock,
              forwardBlock,
              _buildHighlightedText(
                widget.message.content,
                widget.searchQuery,
                widget.currentMatchIndex,
                widget.messageIndex, // Це поле треба додати у GroupChatMessageWidget!
                widget.foundMatches, // Це поле треба додати у GroupChatMessageWidget!
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formattedTime, style: TextStyle(color: widget.message.isMe ? const Color(0xFF0F0F1A).withOpacity(0.6) : const Color(0xFF6E6E80), fontSize: 10)),
              if (widget.message.isMe) ...[const SizedBox(width: 4), _buildStatusIcon(widget.message.status)],
            ],
          ),
        ],
      ),
    );

    Widget reactionIcon = GestureDetector(
      onTap: () => widget.onActionSelected('Like'),
      child: SizedBox(
        width: 24,
        child: Column(
          children: [
            Icon(widget.isLikedByMe ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined, size: 18, color: widget.isLikedByMe ? const Color(0xFF00F5A0) : const Color(0xFF6E6E80)),
            if (widget.likesCount > 0) Text("${widget.likesCount}", style: const TextStyle(color: Color(0xFF6E6E80), fontSize: 10)),
          ],
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
      children: widget.message.isMe ? [Padding(padding: const EdgeInsets.only(right: 8), child: reactionIcon), messageBox] : [messageBox, Padding(padding: const EdgeInsets.only(left: 8), child: reactionIcon)],
    );
  }

  void _showBlurActions(BuildContext context, bool isMe) {
    final RenderBox? renderBox = _messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;

    List<Map<String, dynamic>> menuItems = [
      {"title": "Reply", "icon": const FigmaReplyIcon(), "color": const Color(0xFF00F5A0)},
      {"title": "Copy", "icon": const FigmaCopyIcon(), "color": const Color(0xFF00F5A0)},
      // Форвард поки закоментував, бо потрібен імпорт ChatForwardScreen. Якщо він є, розкоментуй:
      // {"title": "Forward", "icon": const FigmaForwardIcon(), "color": const Color(0xFF00F5A0), "isForward": true},
    ];

    if (isMe) {
      menuItems.insert(1, {"title": "Edit", "icon": const FigmaEditIcon(), "color": const Color(0xFF00F5A0)});
      menuItems.add({"title": "Delete", "icon": const FigmaDeleteIcon(), "color": const Color(0xFFFF6B6B)});
    }

    final double menuHeight = menuItems.length * 35.0 + 20;
    final bool showAbove = (position.dy + size.height + menuHeight) > (screenHeight - 50);

    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: "Menu",
      pageBuilder: (ctx, _, __) => Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: Container(color: Colors.black.withOpacity(0.3))),
          ),
          Positioned(
            top: position.dy + 4, right: widget.message.isMe ? 16 : null, left: !widget.message.isMe ? 16 : null,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: size.width,
                child: Align(alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft, child: _buildMessageContainer()),
              ),
            ),
          ),
          Positioned(
            top: showAbove ? position.dy - menuHeight - 3 : position.dy + size.height + 1,
            right: widget.message.isMe ? 16 : null, left: !widget.message.isMe ? 16 : null,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 112, height: menuHeight, padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                decoration: BoxDecoration(color: const Color(0xFF2B2B3B), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: menuItems.map((item) => GestureDetector(
                    onTap: () { widget.onActionSelected(item["title"]); Navigator.pop(ctx); },
                    child: Row(
                      children: [
                        Transform(alignment: Alignment.center, transform: (item["isForward"] ?? false) ? Matrix4.rotationY(pi) : Matrix4.identity(), child: item["icon"]),
                        const SizedBox(width: 15),
                        Text(item["title"], style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, color: item["color"])),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, int currentMatchIndex, int messageIndex, List<Map<String, int>> foundMatches) {
    // Визначаємо колір: для твоїх повідомлень (зелений фон) - чорний текст, для інших - білий
    final Color baseTextColor = widget.message.isMe ? const Color(0xFF0F0F1A) : Colors.white;

    if (query.isEmpty) {
      return Text(
        getCleanContentGroup(text),
        style: TextStyle(color: baseTextColor, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      );
    }

    final List<TextSpan> spans = [];
    final String cleanText = getCleanContentGroup(text);
    final regExp = RegExp(RegExp.escape(query), caseSensitive: false);
    int start = 0;

    regExp.allMatches(cleanText).forEach((match) {
      // Текст ДО знайденої літери
      spans.add(TextSpan(text: cleanText.substring(start, match.start), style: TextStyle(color: baseTextColor)));

      // Перевіряємо, чи це активний збіг (на який ти натиснув стрілками)
      bool isActive = false;
      for(int i = 0; i < foundMatches.length; i++) {
        if (foundMatches[i]['messageIndex'] == messageIndex && foundMatches[i]['matchIndex'] == match.start) {
          if (i == currentMatchIndex) isActive = true;
        }
      }

      // Текст САМОЇ ЗНАЙДЕНОЇ ЛІТЕРИ
      spans.add(TextSpan(
        text: cleanText.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: isActive ? Colors.blue : const Color(0xFFD2691E), // Синій (активний) або Коричневий
          color: Colors.white, // Літера завжди біла, щоб контрастувала на фоні
          fontWeight: FontWeight.bold,
        ),
      ));
      start = match.end;
    });

    // Текст ПІСЛЯ знайденої літери
    spans.add(TextSpan(text: cleanText.substring(start), style: TextStyle(color: baseTextColor)));

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      ),
    );
  }

}