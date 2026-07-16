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

  @override
  void initState() {
    super.initState();
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

  // --- МЕТОДИ ДЛЯ РОБОТИ З ПОВІДОМЛЕННЯМИ ---

  Future<void> _loadHistory(String chatId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/messages/$chatId'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        final String myId = UserSession().currentUser?.id.toString() ?? "";
        final String myNickname = UserSession().currentUser?.nickname ?? "You";

        setState(() {
          _messages = list.map((item) => {
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

          _messages.sort((a, b) => a['time'].compareTo(b['time']));
        });
        _handleInitialScroll();
      }
    } catch (e) {
      debugPrint("Помилка завантаження історії: $e");
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
            Positioned.fill(child: Image.asset('assets/ChatBackground/$_currentBg', fit: BoxFit.cover, opacity: const AlwaysStoppedAnimation(0.3))),
            Column(
              children: [
                _buildHeader(displayName),
                Expanded(
                  child: Stack(
                    children: [
                      _messages.isEmpty
                          ? const Center(child: Text("No messages yet", style: TextStyle(color: Color(0xFF8E8EA9))))
                          : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final bool isNewDay = index == 0 || !isSameDayGroup(msg['time'], _messages[index - 1]['time']);
                          final status = GroupMessageStatus.values.firstWhere((e) => e.name == (msg['status'] ?? 'sent'), orElse: () => GroupMessageStatus.sent);

                          return GroupChatMessageWidget(
                            key: ValueKey(msg['id']),
                            showDateDivider: isNewDay,
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
                      if (_showScrollDownButton)
                        Positioned(
                          right: 20, bottom: 20,
                          child: GestureDetector(
                            onTap: () {
                              _markAsReadOnServer(widget.chatId);
                              _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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

  Widget _buildHeader(String displayName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 57, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: widget.onBack, // Оновлення відбудеться, бо ChatsScreen передає сюди _closeAndRefresh
            child: const SizedBox(width: 40, height: 40, child: ChatBackIcon(size: 24)),
          ),
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
                    Text(_isTyping ? "someone typing..." : "group", style: TextStyle(color: _isTyping ? Colors.white : const Color(0xFF00F5A0), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatGroupInfoScreen(chatId: widget.chatId)));
            },
            child: const FigmaGroupInfoIcon(size: 45),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupAvatar() {
    final members = widget.participantNames; // Або краще тягнути з бекенду
    return Container(
      width: 36, height: 36,
      decoration: const BoxDecoration(color: Color(0xFF181826), shape: BoxShape.circle),
      child: GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.zero,
        children: members.take(4).map((n) => Center(
            child: Text(n[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Color(0xFF00F5A0)))
        )).toList(),
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

  const GroupChatMessageWidget({
    super.key, required this.message, required this.likesCount, required this.isLikedByMe,
    required this.onActionSelected, required this.allMessages, this.showDateDivider = false,
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
            child: Text(DateFormat('d MMMM yyyy').format(widget.message.timestamp.toLocal()), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, color: Colors.white)),
          ),
        Align(
          alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 1.0,
            child: Align(
              alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                key: _messageKey, margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
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
              Text(getCleanContentGroup(widget.message.content), style: TextStyle(color: widget.message.isMe ? const Color(0xFF0F0F1A) : Colors.white, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
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
}