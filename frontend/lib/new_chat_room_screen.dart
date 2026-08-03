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
import 'chats_screen.dart';
import 'chat_forward_screen.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatRoomScreen extends StatefulWidget {
  final String friendName;
  final String? friendId;
  final String? chatId;
  final VoidCallback onBack;
  final String? initialMessage;
  final int unreadCount;

  const ChatRoomScreen({
    super.key,
    required this.friendName,
    required this.onBack,
    this.friendId,
    this.chatId,
    this.initialMessage,
    this.unreadCount = 0,
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
  int _firstUnreadIndex = -1;
  final FocusNode _focusNode = FocusNode();
  double _currentBottomPadding = 20.0;
  Map<String, dynamic>? _messageToEdit;
  Map<String, dynamic>? _messageToReply;

  bool _isFriendOnline = false;

  // Додаємо змінну для реального ID чату
  String? _activeChatId;

  int _remainingUnread = 0;

  bool _isInitializing = true;
  bool _isJumpingToUnread = false;

  int _currentOffset = 0;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _hasMoreNewer = true;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _foundMatches = [];
  int _currentFoundIndex = -1;

  bool _isAutoScrolling = false;
  String? _lastSentReadMessageId;
  int _lastSentMessageIndex = -1;

  String? _friendLastSeen;
  late final Function(String, bool) _statusListener;

  // Використовуємо контролери пакета scrollable_positioned_list
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  void _markMessagesAsReadUi(Map<String, dynamic> data) {
    if (!mounted) return;

    final String chatId = data['chat_id']?.toString() ?? "";
    if (chatId != _activeChatId) return;

    final String? lastReadId = data['last_read_id']?.toString();
    print("🕵️ [DEEP_DETECTIVE] 🟢 ВИКЛИК _markMessagesAsReadUi для last_read_id: $lastReadId");

    setState(() {
      if (lastReadId != null) {
        final int targetIndex = _messages.indexWhere((m) => m['id'].toString() == lastReadId);
        print("🕵️ [DEEP_DETECTIVE] Цільовий індекс для $lastReadId у масиві: $targetIndex");

        for (int i = 0; i < _messages.length; i++) {
          var msg = _messages[i];
          final String msgId = msg['id'].toString();
          final String content = msg['content'].toString();
          final String currentStatus = msg['status'];

          bool shouldBeRead = (targetIndex != -1 && i <= targetIndex);

          if (shouldBeRead && currentStatus != 'read') {
            print("🕵️ [DEEP_DETECTIVE] ✅ ЗМІНЮЄМО НА READ -> Текст: '$content' (індекс: $i, ID: $msgId)");
            msg['status'] = 'read';
          } else if (!shouldBeRead && currentStatus == 'read') {
            print("🕵️ [DEEP_DETECTIVE] ⚠️ АНОМАЛІЯ! Текст '$content' (індекс: $i, ID: $msgId) вже READ, хоча індекс ($i) > targetIndex ($targetIndex)!");
          }
        }
      }
    });
  }

  bool _isConnected = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _remainingUnread = widget.unreadCount;
    WidgetsBinding.instance.addObserver(this);
    print("DEBUG: ChatRoomScreen відкрився. chatId: ${widget.chatId}, friendId: ${widget.friendId}");
    _currentBg = _backgrounds[Random().nextInt(_backgrounds.length)];

    _isConnected = ChatManager().isConnected;

    ChatManager().onStatusChanged = (connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
      });
    };

    // 🚀 ДОДАЄМО СЛУХАЧ ОНЛАЙН-СТАТУСУ В РЕАЛЬНОМУ ЧАСІ:
    _statusListener = (userId, isOnline) {
      if (!mounted) return;
      if (userId == widget.friendId) {
        setState(() {
          _isFriendOnline = isOnline;
          print("🔄 [REALTIME_STATUS] Статус друга ${widget.friendName} змінено на: $isOnline");
          if (!isOnline) {
            _friendLastSeen = DateTime.now().toUtc().toIso8601String();
          }
        });
      }
    };
    ChatManager().addStatusListener(_statusListener);

    final myId = UserSession().currentUser?.id.toString() ?? "";
    ChatManager().init(myId);

    ChatManager().socket?.off('new_message');
    ChatManager().socket?.on('new_message', (data) {
      _addNewMessageToUi(data);
    });

    ChatManager().socket?.off('messages_read');
    ChatManager().socket?.on('messages_read', (data) {
      if (data['chat_id'] == _activeChatId) {
        _markMessagesAsReadUi(data);
      }
    });

    ChatManager().socket?.on('user_typing', (data) {
      if (data['chat_id'] == _activeChatId) {
        setState(() => _isTyping = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }
    });

    ChatManager().socket?.off('message_edited');
    ChatManager().socket?.on('message_edited', (data) {
      if (!mounted) return;

      final String messageId = data['message_id'].toString();
      final String newContent = data['new_content'];

      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          _messages[index]['content'] = newContent;
        }
      });
    });

    // Змінна для простого дебаунсу запитів
    DateTime _lastPatchTime = DateTime.now();
    DateTime? _lastSentReadTime;

    // Підписка на позиції елементів для визначення скролу та кнопки вниз
    DateTime _lastBadgeFetchTime = DateTime.now();

    // Підписка на позиції елементів для визначення скролу та читання

    final Set<String> sentReadIds = {};

    _itemPositionsListener.itemPositions.addListener(() {
      if (!mounted) return;
      if (_isInitializing || _isJumpingToUnread || _activeChatId == null) return;

      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;

      final visibleItems = positions.where((p) => p.itemLeadingEdge <= 1.0 && p.itemTrailingEdge >= 0.0).toList();

      if (visibleItems.isNotEmpty) {
        final targetVisibleItem = visibleItems.reduce((min, p) => p.index < min.index ? p : min);
        int reversedIdx = _messages.length - 1 - targetVisibleItem.index;

        if (reversedIdx >= 0 && reversedIdx < _messages.length) {
          final msg = _messages[reversedIdx];
          final String myId = UserSession().currentUser?.id.toString() ?? "";
          final String msgSenderId = msg['sender_id']?.toString() ?? "";
          final String msgId = msg['id']?.toString() ?? "";

          // Якщо повідомлення НЕ наше
          if (msgSenderId != myId) {
            // 🛡️ ФРОНТЕНД-ФІЛЬТР: Шлемо запит ТІЛЬКИ якщо ми проскролили далі вперед (новий індекс більший за попередній)
            if (_lastSentReadMessageId != msgId && reversedIdx > _lastSentMessageIndex) {
              _lastSentReadMessageId = msgId;
              _lastSentMessageIndex = reversedIdx; // Оновлюємо планку прогресу

              print("🎯 [FRONTEND DETECTIVE] 🚀 ШЛЕМО НА БЕКЕНД РІД ДО ID: $msgId (Індекс масиву: $reversedIdx)");
              _markAsReadOnServer(_activeChatId!, lastMessageId: msgId);
            }
          }
        }
      }

      // --- Пагінація та кнопка вниз ---
      final maxPosition = positions.reduce((max, p) => p.itemTrailingEdge > max.itemTrailingEdge ? p : max);
      final minPosition = positions.reduce((min, p) => min.itemLeadingEdge < min.itemLeadingEdge ? p : min);

      if (maxPosition.index >= _messages.length - 2 && !_isLoadingMore && _hasMoreMessages && _activeChatId != null) {
        _loadHistory(_activeChatId!, isLoadMore: true);
      }
      if (minPosition.index <= 2 && !_isLoadingMore && _hasMoreNewer && _activeChatId != null) {
        _loadHistory(_activeChatId!, isLoadNewer: true);
      }

      final bool isNearBottomEdge = positions.any((p) => p.index <= 1);
      bool shouldShow = true;
      if ((minPosition.index == 0 && minPosition.itemLeadingEdge >= -0.1) || isNearBottomEdge) {
        shouldShow = false;
      } else {
        shouldShow = minPosition.index > 0 || minPosition.itemLeadingEdge < -0.1;
      }

      if (_showScrollDownButton != shouldShow) {
        setState(() => _showScrollDownButton = shouldShow);
      }
    });

    _initializeChat();

    _textController.addListener(() {
      if (_activeChatId != null && _textController.text.isNotEmpty) {
        ChatManager().socket?.emit('typing', {'chat_id': _activeChatId});
      }
      final isEmpty = _textController.text.trim().isEmpty;
      if (_isInputEmpty != isEmpty) setState(() => _isInputEmpty = isEmpty);
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

    _messages.sort((a, b) => a['time'].compareTo(b['time']));

    ChatManager().socket?.off('message_deleted');
    ChatManager().socket?.on('message_deleted', (data) {
      if (!mounted) return;

      if (data['chat_id'] == _activeChatId) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == data['message_id'].toString());
        });
      }
    });

    ChatManager().socket?.on('error', (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Error occurred'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _fetchFreshUnreadCount() async {
    if (_activeChatId == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/$_activeChatId/unread-count'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int freshCount = data['unread_count'] ?? 0;
        if (mounted && _remainingUnread != freshCount) {
          setState(() {
            _remainingUnread = freshCount;
          });
        }
      }
    } catch (e) {
      debugPrint("Помилка отримання актуального unread count: $e");
    }
  }

  Future<void> _loadHistory(String chatId, {bool isLoadMore = false, bool isLoadNewer = false, int unreadCount = 0}) async {
    if (_isLoadingMore || (!_hasMoreMessages && isLoadMore) ||
        (!_hasMoreNewer && isLoadNewer)) return;

    setState(() => _isLoadingMore = true);

    // 🕵️ ДЕТЕКТИВ №1: Фіксуємо вхідні параметри
    print(
        "🕵️ [DET_HIST] Запуск _loadHistory. isLoadMore: $isLoadMore, isLoadNewer: $isLoadNewer, поточна кількість _messages у пам'яті: ${_messages
            .length}, unreadCount: $unreadCount");

    try {
      int currentLimit = 50;
      String queryParams = "limit=$currentLimit";

      // Формуємо URL залежно від напрямку пагінації
      if (isLoadMore && _messages.isNotEmpty) {
        // Скролимо вгору (шукаємо старіші) — передаємо ID найпершого елемента у масиві
        final oldestMessageId = _messages.first['id'];
        queryParams += "&before_message_id=$oldestMessageId";
      } else if (isLoadNewer && _messages.isNotEmpty) {
        // Скролимо вниз (шукаємо новіші) — передаємо ID найостаннішого елемента у масиві
        final newestMessageId = _messages.last['id'];
        queryParams += "&after_message_id=$newestMessageId";
      } else {
        // Первинний вхід (offset=0)
        queryParams += "&offset=0";
      }

      // 🕵️ ДЕТЕКТИВ №2: Показуємо точний URL запиту на сервер
      final targetUrl = '${ApiConfig.baseUrl}/messages/$chatId?$queryParams';
      print("🕵️ [DET_HIST] Стукаємо на бекенд -> URL: $targetUrl");

      final response = await http.get(
        Uri.parse(targetUrl),
        headers: await ApiService.getHeaders(),
      );

      print("🕵️ [DET_HIST] Відповідь від сервера. Статус: ${response
          .statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);

        // 🕵️ ДЕТЕКТИВ №3: Скільки саме елементів прийшло від бекенду
        print("🕵️ [DET_HIST] Сервер повернув елементів у цьому пакеті: ${list
            .length}");
        if (list.isNotEmpty) {
          print("🕵️ [DET_HIST] Перше повідомлення з пачки ID: ${list
              .first['id']}, час: ${list.first['created_at']}");
          print("🕵️ [DET_HIST] Останнє повідомлення з пачки ID: ${list
              .last['id']}, час: ${list.last['created_at']}");
        }

        if (list.isEmpty) {
          print("🕵️ [DET_HIST] Пачка порожня.");
          if (isLoadMore) {
            setState(() => _hasMoreMessages = false);
          } else if (isLoadNewer) {
            setState(() => _hasMoreNewer = false);
          }
        } else {
          final String myId = UserSession().currentUser?.id.toString() ?? "";
          final String myNickname = UserSession().currentUser?.nickname ??
              "You";

          final newMessages = list.map((item) =>
          {
            'id': item['id'].toString(),
            'content': item['content'],
            'sender_id': item['sender_id'].toString(),
            'sender_nickname': item['sender_nickname'] ??
                (item['sender_id'].toString() == myId ? myNickname : widget
                    .friendName),
            'isMe': item['sender_id'].toString() == myId,
            'time': _parseDateTime(item['created_at']),
            'status': item['status'] ?? 'sent',
            'reply_to_id': item['reply_to_id'],
            'likes_count': item['likes_count'] ?? 0,
            'is_liked_by_me': item['is_liked_by_me'] ?? false,
          }).toList();

          setState(() {
            if (isLoadMore || isLoadNewer) {
              // Створюємо карту для захисту від дублів при довантаженні (вгору або вниз)
              final Map<String, Map<String, dynamic>> uniqueMap = {};
              for (var msg in [..._messages, ...newMessages]) {
                uniqueMap[msg['id'].toString()] = msg;
              }
              _messages = uniqueMap.values.toList();
              print(
                  "🕵️ [DET_HIST] Довантажено. Загалом у пам'яті тепер: ${_messages
                      .length}");
            } else {
              // Для первинного завантаження теж проганяємо через унікальність
              final Map<String, Map<String, dynamic>> uniqueMap = {};
              for (var msg in newMessages) {
                uniqueMap[msg['id'].toString()] = msg;
              }
              _messages = uniqueMap.values.toList();
              print(
                  "🕵️ [DET_HIST] Первинне завантаження. Загалом у пам'яті тепер: ${_messages
                      .length}");
            }
            _messages.sort((a, b) => a['time'].compareTo(b['time']));
          });

          // 🕵️ ДЕТЕКТИВ ПАЧКИ: Виводимо всю пачку із загальними та реверс-індексами
          print("📦 ---------------- ПАЧКА ПОВІДОМЛЕНЬ У ПАМ'ЯТІ (Всього: ${_messages.length}) ----------------");
          for (int i = 0; i < _messages.length; i++) {
            final m = _messages[i];
            final int reversedIndex = _messages.length - 1 - i;
            print("📦 [MESSAGES_DUMP] Масив-індекс: $i | Реверс-індекс (екранний): $reversedIndex | Текст: '${m['content']}' | Статус: ${m['status']} | ID: ${m['id']}");
          }
          print("📦 --------------------------------------------------------------------------------");

          // ПРИМУСОВИЙ СТРИБОК ЛИШЕ ПРИ ПЕРВИННОМУ ВХОДІ (!isLoadMore && !isLoadNewer)
          if (!isLoadMore && !isLoadNewer) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_messages.isNotEmpty) {
                if (widget.unreadCount > 0) {
                  setState(() {
                    _remainingUnread = widget.unreadCount;
                    _showScrollDownButton = true;
                  });
                }

                // Ставимо 1000 мс, щоб дати повністю відмалюватися списку, як у груповому чаті
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) {
                    setState(() {
                      _isInitializing = false;
                    });
                  }
                });

                if (_itemScrollController.isAttached) {
                  if (widget.unreadCount > 0) {
                    final int targetIndex = min(widget.unreadCount, _messages.length - 1);
                    print("🎯 [SCROLL] Точний стрибок за unreadCount: ${widget.unreadCount} на позицію $targetIndex");

                    _isJumpingToUnread = true; // 🛡️ Блокуємо слухач від хибних спрацьовувань при стрибку

                    // Просто викликаємо jumpTo (він миттєвий)
                    _itemScrollController.jumpTo(index: targetIndex, alignment: 0.2);

                    // І запускаємо паралельний таймер на зняття блокування
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) {
                        _isJumpingToUnread = false; // 🔓 Знімаємо блокування
                      }
                    });
                  } else {
                    _itemScrollController.jumpTo(index: 0, alignment: 0.0);
                  }
                }
              }
            });
          }
        }
      }
    } catch (e, stackTrace) {
      print("🕵️ [DET_HIST] ПОМИЛКА в _loadHistory: $e");
      debugPrint("$stackTrace");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  String? _friendAvatarUrl;

  Future<void> _markAsReadOnServer(String chatId, {String? lastMessageId}) async {
    if (lastMessageId == null || lastMessageId.isEmpty) return;

    try {
      // Використовуємо такий же ендпоінт або аналогічний для приватних чатів з передачею last_message_id
      String url = '${ApiConfig.baseUrl}/messages/read-up-to/$chatId?last_message_id=$lastMessageId';

      final response = await http.patch(
        Uri.parse(url),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Якщо бекенд повертає unread_count у відповіді, беремо його.
        // Якщо ні — бекенд можна трохи доповнити, або залишити страховочний виклик _fetchFreshUnreadCount()
        final int serverUnread = data['unread_count'] ?? 0;

        final String myId = UserSession().currentUser?.id.toString() ?? "";
        setState(() {
          final int targetIndex = _messages.indexWhere((m) => m['id'].toString() == lastMessageId);

          for (int i = 0; i <= targetIndex && i < _messages.length; i++) {
            var msg = _messages[i];
            if (msg['sender_id'] != myId && msg['status'] != 'read') {
              msg['status'] = 'read';
            }
          }

          _remainingUnread = serverUnread;
          if (_remainingUnread <= 0) {
            _showScrollDownButton = false;
          }
        });

        _fetchFreshUnreadCount();
      }
    } catch (e) {
      debugPrint("Помилка при спробі позначити як прочитане: $e");
    }
  }

  Future<void> _initializeChat() async {
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      setState(() => _activeChatId = widget.chatId);
    } else if (widget.friendId != null) {
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

    if (_activeChatId != null) {
      ChatManager().joinChat(_activeChatId!);

      // 👈 Передаємо unreadCount сюди
      _loadHistory(_activeChatId!, unreadCount: widget.unreadCount);

      if (widget.friendId != null) {
        _loadFriendAvatar(widget.friendId!);
      }
    } else {
      debugPrint("КРИТИЧНА ПОМИЛКА: Не вдалося отримати _activeChatId");
    }
  }

  Future<void> _loadFriendAvatar(String friendId) async {
    print("🕵️ [AVATAR_DEBUG] Викликаємо завантаження для friendId: $friendId");
    try {
      final userResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$friendId'),
        headers: await ApiService.getHeaders(),
      );

      print("🕵️ [AVATAR_DEBUG] Відповідь /users/$friendId: статуc ${userResponse.statusCode}, тіло: ${userResponse.body}");

      if (userResponse.statusCode == 200 && userResponse.body.isNotEmpty) {
        final userData = json.decode(userResponse.body);
        setState(() {
          _friendAvatarUrl = userData['avatar'];
          _isFriendOnline = userData['is_online'] ?? false;
          _friendLastSeen = userData['last_seen'];
          print("🕵️ [AVATAR_DEBUG] Успішно збережено _friendLastSeen = $_friendLastSeen");
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження аватара: $e");
    }
  }

  @override
  void dispose() {
    print("🚨 [LIFECYCLE_DETECTOR] Викликано dispose для ChatRoomScreen!");

    // 🛡️ Обов'язково знімаємо слухач статусів та всі сокет-події екрану
    ChatManager().removeStatusListener(_statusListener);
    ChatManager().socket?.off('new_message');
    ChatManager().socket?.off('messages_read');
    ChatManager().socket?.off('user_typing');
    ChatManager().socket?.off('message_edited');
    ChatManager().socket?.off('message_deleted');
    ChatManager().socket?.off('reaction_updated');
    ChatManager().socket?.off('error');

    _textController.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 250), () {
        // Перевіряємо за допомогою .isAttached натомість .hasClients
        if (mounted && _itemScrollController.isAttached && _messages.isNotEmpty) {
          _itemScrollController.scrollTo(
            index: 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
    if (!timeString.contains('Z') && !timeString.contains('+')) {
      timeString += 'Z';
    }
    return DateTime.parse(timeString).toLocal();
  }

  void _addNewMessageToUi(Map<String, dynamic> messageData) {
    if (!mounted) {
      print("🕵️ [MSG_DETECTOR] ⚠️ _addNewMessageToUi проігноровано, бо mounted = false");
      return;
    }

    final String msgChatId = messageData['chat_id']?.toString() ?? "";
    if (msgChatId.isNotEmpty && msgChatId != _activeChatId) {
      return;
    }

    final String senderId = messageData['sender_id']?.toString() ?? "";
    final String content = messageData['content']?.toString() ?? "";
    final DateTime time = _parseDateTime(messageData['created_at'] ?? DateTime.now());
    final String serverMessageId = messageData['id']?.toString() ?? '';

    // 🎯 ОСЬ ТУТ ВОНО ОБОВ'ЯЗКОВО МАЄ БУТИ ОГОЛОШЕНЕ:
    final String myId = UserSession().currentUser?.id.toString() ?? "";

    setState(() {
      // Шукаємо недавнє локальне повідомлення з тимчасовим ID (temp_)
      final int existingIndex = _messages.indexWhere((m) =>
      m['id'].toString().startsWith('temp_') &&
          m['content'] == content &&
          m['sender_id'] == senderId
      );

      if (existingIndex != -1) {
        print("🕵️ [MSG_DETECTOR] 🔄 Знайдено локальний 'temp_' дублікат. Оновлюємо його на серверний ID: $serverMessageId");
        _messages[existingIndex]['id'] = serverMessageId;
        _messages[existingIndex]['status'] = messageData['status'] ?? 'sent';
      } else {
        final bool isDuplicate = _messages.any((m) => m['id'].toString() == serverMessageId);

        if (isDuplicate) {
          print("🕵️ [MSG_DETECTOR] 🔄 Знайдено дублікат повідомлення за ID, пропускаємо додавання.");
          return;
        }

        print("🕵️ [MSG_DETECTOR] ✅ Додаємо нове повідомлення у _messages...");
        _messages.add({
          'id': serverMessageId,
          'content': content,
          'sender_id': senderId,
          'sender_nickname': messageData.containsKey('sender_nickname')
              ? messageData['sender_nickname']
              : (senderId == myId // Використовується тут
              ? UserSession().currentUser?.nickname ?? "You"
              : widget.friendName),
          'isMe': senderId == myId, // І тут
          'time': time,
          'status': messageData['status'] ?? 'sent',
          'reply_to_id': messageData.containsKey('reply_to_id') ? messageData['reply_to_id'] : null,
          'likes_count': messageData['likes_count'] ?? 0,
          'is_liked_by_me': messageData['is_liked_by_me'] ?? false,
        });
      }

      _messages.sort((a, b) => a['time'].compareTo(b['time']));
    });

    // 🚀 Автоматичне прочитання у кінці методу:
    if (senderId != myId && _activeChatId != null) { // І тут
      print("🚀 [AUTO-READ] Автоматично позначаємо нове повідомлення $serverMessageId як прочитане.");
      _markAsReadOnServer(_activeChatId!, lastMessageId: serverMessageId);
    }
  }
  String _removeForwardTag(String content) {
    return content.replaceAll(RegExp(r'^\[FWD:[^\]]+\]'), '');
  }

  Future<void> _handleInitialScroll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final myId = UserSession().currentUser?.id.toString();
    int unreadIdx = _messages.indexWhere((m) => m['sender_id'] != myId && m['status'] != 'read');

    setState(() {
      _firstUnreadIndex = unreadIdx;
    });

    if (_itemScrollController.isAttached && _messages.isNotEmpty) {
      _itemScrollController.jumpTo(index: 0);
    }
  }

  void _handleMessageAction(String action, Map<String, dynamic> message) {
    final String cleanContent = getCleanContent(message['content'].toString());

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
    } else if (action == 'Forward') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatForwardScreen(
            messageId: message['id'].toString(),
            messageContent: cleanContent,
          ),
        ),
      );
    } else if (action == 'Delete') {
      _deleteMessage(message['id'].toString());
    } else if (action == 'Copy') {
      Clipboard.setData(ClipboardData(text: cleanContent)).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Copied to clipboard", style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFF181826),
            duration: Duration(seconds: 1),
          ),
        );
      });
    } else if (action == 'Like') {
      _toggleReaction(message['id'].toString());
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    print("🕵️ [DELETE_DEBUG] Намагаємося видалити повідомлення з ID: $messageId");

    if (messageId.isEmpty || messageId == 'unknown_id' || messageId.startsWith('temp_')) {
      setState(() {
        _messages.removeWhere((m) => m['id'] == messageId);
      });
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/messages/$messageId'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == messageId);
        });
      }
    } catch (e) {
      debugPrint("Помилка видалення: $e");
    }
  }

  Future<void> _fetchFriendsAndOpenGroupScreen() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/friends/list'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200 && mounted) {
        List<dynamic> list = json.decode(response.body);

        List<FriendItem> friends = list.map((item) {
          final data = item['user'] ?? item;
          final nickname = data['nickname'] ?? 'Unknown';
          final userId = data['id'] ?? 0;
          final String? avatar = data['avatar']?.toString();

          return FriendItem(
            id: userId,
            name: nickname,
            avatarUrl: avatar,
            status: data['is_online'] == true ? 'online' : 'offline',
            initial: nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
            isOnline: data['is_online'] ?? false,
          );
        }).toList();

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatAddFriendsGroupScreen(
              onClose: () => Navigator.pop(context),
              currentFriendName: widget.friendName,
              currentPartnerId: widget.friendId,
              friendsList: friends,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Помилка завантаження друзів для групи: $e");
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _foundMatches = [];
        _currentFoundIndex = -1;
      });
      return;
    }

    if (_activeChatId == null) return;

    try {
      // Робимо запит до нового ендпоінта бекенда для пошуку по всій базі
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/$_activeChatId/search?query=${Uri.encodeComponent(query)}'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> serverResults = json.decode(response.body);

        List<Map<String, dynamic>> newFoundMatches = [];

        for (var item in serverResults) {
          final String messageId = item['id'].toString();

          // Шукаємо, чи є це знайдее повідомлення у вже завантаженому локальному списку _messages
          int localIndex = _messages.indexWhere((m) => m['id'] == messageId);

          if (localIndex != -1) {
            // Якщо воно є в пам'яті, фіксуємо його індекс
            newFoundMatches.add({
              'messageIndex': localIndex,
              'messageId': messageId,
            });
          } else {
            // Якщо повідомлення глибоко в історії і ще не завантажене у _messages,
            // ми можемо додати його тимчасово в масив або підвантажити пачку навколо нього.
            // Щоб воно не губилося, додаємо його в загальний список _messages:
            final String myId = UserSession().currentUser?.id.toString() ?? "";
            final parsedMsg = {
              'id': messageId,
              'content': item['content'],
              'sender_id': item['sender_id'].toString(),
              'sender_nickname': item['sender_nickname'] ?? widget.friendName,
              'isMe': item['sender_id'].toString() == myId,
              'time': _parseDateTime(item['created_at']),
              'status': item['status'] ?? 'read',
              'likes_count': 0,
              'is_liked_by_me': false,
            };

            _messages.add(parsedMsg);
            // Сортуємо масив за часом, щоб не ламати логіку реверса
            _messages.sort((a, b) => a['time'].compareTo(b['time']));

            // Перераховуємо індекс після додавання
            int newIndex = _messages.indexWhere((m) => m['id'] == messageId);
            if (newIndex != -1) {
              newFoundMatches.add({
                'messageIndex': newIndex,
                'messageId': messageId,
              });
            }
          }
        }

        setState(() {
          _foundMatches = newFoundMatches;
          // Ставимо індекс на перший знайдений результат
          _currentFoundIndex = _foundMatches.isNotEmpty ? 0 : -1;
          _scrollToFoundMessage();
        });
      }
    } catch (e) {
      debugPrint("Помилка при виконанні пошуку по історії: $e");
    }
  }

  void _scrollToFoundMessage() {
    if (_foundMatches.isEmpty || _currentFoundIndex == -1) return;
    final matchInfo = _foundMatches[_currentFoundIndex];
    if (_itemScrollController.isAttached) {
      final int realMessageIndex = matchInfo['messageIndex']!;
      // Коректний перерахунок для ScrollablePositionedList з reverse: true
      final int targetIndex = _messages.length - 1 - realMessageIndex;

      _itemScrollController.scrollTo(
        index: targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // Позиціонує знайдене повідомлення чітко по центру екрана
      );
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181826),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Attach to message",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF00F5A0)),
                title: const Text("Photo from Gallery", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF00F5A0)),
                title: const Text("Take a Photo", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file, color: Color(0xFF00F5A0)),
                title: const Text("Document / File", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);

    if (image != null) {
      final int bytesLength = await image.length();
      if (bytesLength > 1 * 1024 * 1024) {
        _showErrorSnackBar("File is too large. Max size is 1MB.");
        return;
      }
      await _uploadAndSendFile(image.path, isImage: true);
    }
  }

  Future<void> _pickAndSendFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(withData: true);

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;

      if (file.size > 1 * 1024 * 1024) {
        _showErrorSnackBar("File is too large. Max size is 1MB.");
        return;
      }

      await _uploadAndSendFile(file.path!, isImage: false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _uploadAndSendFile(String filePath, {required bool isImage}) async {
    if (_activeChatId == null) return;

    print("🕵️ [NAV_DETECTOR] Відкриваємо діалог завантаження...");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00F5A0))),
    );

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/chats/${_activeChatId}/upload');
      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll(await ApiService.getHeaders());
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("🕵️ [NAV_DETECTOR] Запит завершено. Статус: ${response.statusCode}. Чи mounted: $mounted");

      if (mounted) {
        print("🕵️ [NAV_DETECTOR] Викликаємо Navigator.pop(context) для закриття крутилки...");
        Navigator.of(context, rootNavigator: true).pop(); // Закриваємо саме діалог, гарантовано не чіпаючи екран чату
        print("🕵️ [NAV_DETECTOR] Navigator.pop(context) успішно відпрацював.");
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String fileUrl = data['file_url'];

        final String myId = UserSession().currentUser?.id.toString() ?? "";
        final String fileOriginalName = data['file_name'] ?? 'document';
        final String content = isImage ? "[IMAGE:$fileUrl]" : "[FILE:$fileUrl|$fileOriginalName]";

        _addNewMessageToUi({
          'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
          'chat_id': _activeChatId,
          'content': content,
          'sender_id': myId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        ChatManager().sendMessage(_activeChatId!, myId, content);
      } else {
        if (mounted) _showErrorSnackBar("Upload failed: ${response.statusCode}");
      }
    } catch (e) {
      print("🕵️ [NAV_DETECTOR] 💥 Виняток у завантаженні: $e");
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnackBar("Error uploading file");
      }
    }
  }

  Future<void> _markSingleAsReadOnServer(String messageId) async {
    try {
      final url = '${ApiConfig.baseUrl}/messages/$messageId/read';
      final response = await http.patch(
        Uri.parse(url),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final String myId = UserSession().currentUser?.id.toString() ?? "";
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == messageId);
          if (idx != -1 && _messages[idx]['sender_id'] != myId) {
            if (_messages[idx]['status'] != 'read') {
              _messages[idx]['status'] = 'read';
              // 👇 Зменшуємо лічильник нечитаних на екрані плавно по мірі скролу
              if (_remainingUnread > 0) {
                _remainingUnread--;
              }
            }
          }
        });

        _fetchFreshUnreadCount();
      }
    } catch (e) {
      debugPrint("Помилка при позначенні одного повідомлення як прочитаного: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    final String initial = widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?';
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
                _buildHeader(initial),
                Expanded(
                  child: Stack(
                    children: [
                      ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        reverse: true,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final int reversedIndex = _messages.length - 1 - index;
                          final msg = _messages[reversedIndex];
                          final String msgId = msg['id'].toString();

                          final bool isNewDay = reversedIndex == 0 || !isSameDay(msg['time'], _messages[reversedIndex - 1]['time']);
                          final status = MessageStatus.values.firstWhere(
                                (e) => e.name == (msg['status'] ?? 'sent'),
                            orElse: () => MessageStatus.sent,
                          );

                          return ChatMessageWidget(
                            searchQuery: _searchController.text,
                            currentMatchIndex: _currentFoundIndex,
                            messageIndex: reversedIndex,
                            foundMatches: _foundMatches,
                            isHighlighted: _isSearching && _foundMatches.any((m) => m['messageIndex'] == reversedIndex),
                            showDateDivider: isNewDay,
                            likesCount: msg['likes_count'] ?? 0,
                            isLikedByMe: msg['is_liked_by_me'] ?? false,
                            message: ChatMessage(
                              id: msgId,
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
                                _markAsReadOnServer(_activeChatId!);
                              }
                              // 🚀 ПРИМУСОВЕ ГАСІННЯ КНОПКИ ТА ЛІЧИЛЬНИКА ПРИ КЛІКУ
                              setState(() {
                                _showScrollDownButton = false;
                                _remainingUnread = 0;
                              });
                              if (_messages.isNotEmpty && _itemScrollController.isAttached) {
                                _itemScrollController.scrollTo(
                                  index: 0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const FigmaScrollDownIcon(),
                                Builder(
                                  builder: (context) {
                                    if (_remainingUnread <= 0) return const SizedBox.shrink();

                                    return Positioned(
                                      right: -2,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF00F5A0),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          "$_remainingUnread",
                                          style: const TextStyle(
                                            color: Color(0xFF0F0F1A),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
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

  String _formatOfflineTime(String? lastSeenIso) {
    if (lastSeenIso == null || lastSeenIso.isEmpty) return "offline";

    try {
      String timeString = lastSeenIso.trim();

      // Якщо формат з бази "YYYY-MM-DD HH:mm:ss", замінюємо пробіл на 'T' для коректного парсингу
      if (timeString.contains(' ') && !timeString.contains('T')) {
        timeString = timeString.replaceFirst(' ', 'T');
      }

      // Якщо немає жодної часової зони чи 'Z', примусово додаємо 'Z' (узгоджуємо з UTC)
      if (!timeString.contains('Z') && !timeString.contains('+') && !timeString.contains(RegExp(r'-\d{2}:\d{2}'))) {
        timeString += 'Z';
      }

      DateTime lastSeenTime = DateTime.parse(timeString).toLocal();
      Duration difference = DateTime.now().difference(lastSeenTime);

      // Додаємо захист від мінусової різниці (якщо годинники трохи розходяться)
      if (difference.isNegative) {
        return "offline just now";
      }

      if (difference.inMinutes < 1) {
        return "offline just now";
      } else if (difference.inMinutes < 60) {
        int minutes = difference.inMinutes;
        return "offline $minutes minute${minutes == 1 ? '' : 's'}";
      } else if (difference.inHours < 24) {
        int hours = difference.inHours;
        return "offline $hours hour${hours == 1 ? '' : 's'}";
      } else {
        int days = difference.inDays;
        return "offline $days day${days == 1 ? '' : 's'}";
      }
    } catch (e) {
      debugPrint("Помилка парсингу last_seen: $e");
      return "offline";
    }
  }

  Widget _buildHeader(String initial) {
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
                  decoration: const InputDecoration(hintText: "Search...", hintStyle: TextStyle(color: Color(0xFF8E8EA9)), border: InputBorder.none),
                  onChanged: _performSearch,
                ),
              ),
              if (_foundMatches.isNotEmpty) ...[
                Text("${_currentFoundIndex + 1}/${_foundMatches.length}", style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 12)),
                GestureDetector(
                  onTap: () {
                    setState(() => _currentFoundIndex = (_currentFoundIndex - 1 + _foundMatches.length) % _foundMatches.length);
                    _scrollToFoundMessage();
                  },
                  child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                ),
                // Стрілка вгору — тепер збільшує індекс
                GestureDetector(
                  onTap: () {
                    setState(() => _currentFoundIndex = (_currentFoundIndex + 1) % _foundMatches.length);
                    _scrollToFoundMessage();
                  },
                  child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                ),
              ],
              GestureDetector(
                onTap: () => setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _foundMatches = [];
                  _currentFoundIndex = -1;
                }),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Color(0xFF00F5A0), BlendMode.srcIn),
                  child: FigmaCloseButton(
                    onTap: () => setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      _foundMatches = [];
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 57, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(onTap: widget.onBack, child: const SizedBox(width: 40, height: 40, child: ChatBackIcon(size: 24))),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  FocusScope.of(context).unfocus();

                  if (widget.friendId != null) {
                    await GamerProfileScreen.openFromId(context, widget.friendId!);

                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) {
                        FocusScope.of(context).unfocus();
                      }
                    });
                  }
                },
                child: ClipOval(
                  child: buildAvatar(_friendAvatarUrl, initial, 32),
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
                        : (!_isConnected
                        ? "connecting..."
                        : (_isFriendOnline ? "online" : _formatOfflineTime(_friendLastSeen))), // Якщо сокет лежить -> "connecting...", якщо живий -> показуємо реальний статус гравця
                    style: TextStyle(
                      color: _isTyping
                          ? Colors.white
                          : (!_isConnected
                          ? Colors.orange
                          : (_isFriendOnline ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9))),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
            color: const Color(0xFF181826),
            onSelected: (value) {
              if (value == 'Add Friends') {
                _fetchFriendsAndOpenGroupScreen();
              } else if (value == 'Search') {
                setState(() => _isSearching = true);
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (mounted) FocusScope.of(context).requestFocus(_focusNode);
                });
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'Add Friends', child: Text("Add Friends", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'Search', child: Text("Search", style: TextStyle(color: Colors.white))),
            ],
          ),
        ],
      ),
    );
  }

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

    final String fullAvatarUrl = avatarUrl.startsWith('http')
        ? avatarUrl
        : '${ApiConfig.baseUrl}${avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl'}';

    return Image.network(
      fullAvatarUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial),
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
              GestureDetector(
                onTap: _showAttachmentOptions,
                child: const Padding(padding: EdgeInsets.only(bottom: 8), child: FigmaAttachIcon()),
              ),
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
                        if (_itemScrollController.isAttached && _messages.isNotEmpty) {
                          _itemScrollController.scrollTo(
                            index: 0,
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
                    _isInputEmpty
                        ? const FigmaSendInactiveIcon()
                        : GestureDetector(
                      onTap: () async {
                        final String myId = UserSession().currentUser?.id.toString() ?? "";
                        final String content = _textController.text.trim();

                        if (_activeChatId != null && content.isNotEmpty) {
                          if (_messageToEdit != null) {
                            await _editMessageOnServer(_messageToEdit!['id'].toString(), content);
                            setState(() => _messageToEdit = null);
                          } else {
                            final replyId = _messageToReply != null ? _messageToReply!['id'] : null;
                            final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
                            _addNewMessageToUi({
                            'id': tempId,
                            'content': content,
                            'sender_id': myId,
                            'created_at': DateTime.now().toUtc().toIso8601String(),
                            'reply_to_id': replyId,
                            });


                            ChatManager().sendMessage(_activeChatId!, myId, content, replyTo: replyId);
                            setState(() => _messageToReply = null);

                            _isAutoScrolling = true;
                            setState(() => _showScrollDownButton = false); // Примусово ховаємо стрілку одразу

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_itemScrollController.isAttached && _messages.isNotEmpty) {
                                _itemScrollController.scrollTo(
                                  index: 0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                ).then((_) {
                                  Future.delayed(const Duration(milliseconds: 50), () {
                                    _isAutoScrolling = false;
                                  });
                                });
                              }
                            });
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
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/react'),
        headers: await ApiService.getHeaders(),
      );
    } catch (e) {
      setState(() {
        _messages[index]['is_liked_by_me'] = !(_messages[index]['is_liked_by_me']);
      });
    }
  }
}

String getCleanContent(String content) {
  if (content.startsWith('[FWD:')) {
    final endIdx = content.indexOf(']');
    if (endIdx != -1) {
      return content.substring(endIdx + 1);
    }
  }
  return content;
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
  int likesCount;
  bool isLikedByMe;

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
    this.likesCount = 0,
    this.isLikedByMe = false,
  });
}

class ChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final int likesCount;
  final bool isLikedByMe;
  final Function(String) onActionSelected;
  final bool showDateDivider;
  final List<Map<String, dynamic>> allMessages;
  final bool isHighlighted;
  final String searchQuery;
  final int currentMatchIndex;
  final int messageIndex;
  final List<Map<String, dynamic>> foundMatches;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.likesCount,
    required this.isLikedByMe,
    required this.onActionSelected,
    required this.allMessages,
    this.showDateDivider = false,
    this.isHighlighted = false,
    required this.searchQuery,
    required this.currentMatchIndex,
    required this.messageIndex,
    required this.foundMatches,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
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
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                decoration: widget.isHighlighted
                    ? BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14))
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

  Widget _buildStatusIcon(MessageStatus status) {
    final Color iconColor = (status == MessageStatus.read)
        ? const Color(0xFF8C52FF)
        : (widget.message.isMe ? const Color(0xFF0F0F1A).withOpacity(0.6) : const Color(0xFF6E6E80));

    if (status == MessageStatus.sent) {
      return FigmaSingleCheckIcon(color: iconColor);
    } else {
      return FigmaDoubleCheckIcon(color: iconColor);
    }
  }

  Widget _buildMessageContainer() {
    String rawContent = widget.message.content;
    String? fwdName;
    String displayContent = rawContent;
    String formattedTime = DateFormat('HH:mm').format(widget.message.timestamp.toLocal());
    final double maxWidth = MediaQuery.of(context).size.width * 0.75;

    final replyMsg = (widget.message.replyToId != null)
        ? widget.allMessages.firstWhere((m) => m['id'] == widget.message.replyToId, orElse: () => {})
        : {};

    if (rawContent.startsWith('[FWD:')) {
      final match = RegExp(r'^\[FWD:([^\]]+)\](.*)').firstMatch(rawContent);
      if (match != null) {
        fwdName = match.group(1);
        displayContent = match.group(2) ?? "";
      }
    }

    Widget replyBlock = const SizedBox.shrink();
    if (replyMsg.isNotEmpty) {
      final String myId = UserSession().currentUser?.id.toString() ?? "";
      final String myNickname = UserSession().currentUser?.nickname ?? "You";

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

    Widget forwardBlock = fwdName != null ? Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.message.isMe ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        border: Border(left: BorderSide(color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0), width: 2)),
      ),
      child: Text("Forwarded from $fwdName", style: TextStyle(
          color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0),
          fontSize: 10, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic
      )),
    ) : const SizedBox.shrink();

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
              replyBlock,
              forwardBlock,
              _buildMessageContent(),
            ],
          ),
          timeAndStatus,
        ],
      ),
    );

    Widget reactionIcon = GestureDetector(
      onTap: () => widget.onActionSelected('Like'),
      child: SizedBox(
        width: 24,
        child: Column(
          children: [
            Icon(
              widget.isLikedByMe ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
              size: 18,
              color: widget.isLikedByMe ? const Color(0xFF00F5A0) : const Color(0xFF6E6E80),
            ),
            if (widget.likesCount > 0)
              Text(
                "${widget.likesCount}",
                style: const TextStyle(color: Color(0xFF6E6E80), fontSize: 10),
              ),
          ],
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: widget.message.isMe
          ? [
        Padding(padding: const EdgeInsets.only(right: 8), child: reactionIcon),
        messageBox
      ]
          : [
        messageBox,
        Padding(padding: const EdgeInsets.only(left: 8), child: reactionIcon)
      ],
    );
  }

  void _showBlurActions(BuildContext context, bool isMe) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;

    List<Map<String, dynamic>> menuItems = [
      {"title": "Reply", "icon": const FigmaReplyIcon(), "color": const Color(0xFF00F5A0)},
      {"title": "Copy", "icon": const FigmaCopyIcon(), "color": const Color(0xFF00F5A0)},
      {"title": "Forward", "icon": const FigmaForwardIcon(), "color": const Color(0xFF00F5A0), "isForward": true},
    ];

    if (isMe) {
      menuItems.insert(1, {"title": "Edit", "icon": const FigmaEditIcon(), "color": const Color(0xFF00F5A0)});
      menuItems.add({"title": "Delete", "icon": const FigmaDeleteIcon(), "color": const Color(0xFFFF6B6B)});
    }

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

  Widget _buildHighlightedText(String text, String query, int currentMatchIndex, int messageIndex, List<Map<String, dynamic>> foundMatches) {
    final Color baseTextColor = widget.message.isMe ? const Color(0xFF0F0F1A) : Colors.white;

    if (query.isEmpty) {
      return Text(
        getCleanContent(text),
        style: TextStyle(color: baseTextColor, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      );
    }

    final List<TextSpan> spans = [];
    final String cleanText = getCleanContent(text);
    final regExp = RegExp(RegExp.escape(query), caseSensitive: false);
    int start = 0;

    regExp.allMatches(cleanText).forEach((match) {
      spans.add(TextSpan(text: cleanText.substring(start, match.start), style: TextStyle(color: baseTextColor)));

      bool isActive = false;
      for(int i = 0; i < foundMatches.length; i++) {
        if (foundMatches[i]['messageIndex'] == messageIndex) {
          if (i == currentMatchIndex) isActive = true;
        }
      }

      spans.add(TextSpan(
        text: cleanText.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: isActive ? Colors.blue : const Color(0xFFD2691E),
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = match.end;
    });

    spans.add(TextSpan(text: cleanText.substring(start), style: TextStyle(color: baseTextColor)));

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      ),
    );
  }

  Widget _buildMessageContent() {
    final String rawContent = widget.message.content;
    final String cleanText = getCleanContent(rawContent);

    if (cleanText.startsWith('[IMAGE:') && cleanText.endsWith(']')) {
      final String imageUrl = cleanText.substring(7, cleanText.length - 1);
      final String fullUrl = imageUrl.startsWith('http')
          ? imageUrl
          : '${ApiConfig.baseUrl}${imageUrl.startsWith('/') ? imageUrl : '/$imageUrl'}';

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          fullUrl,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print("❌ ПОМИЛКА РЕНДЕРУ КАРТИНКИ: $error | URL: $fullUrl");
            return Container(
              width: 200,
              height: 100,
              color: Colors.red.withOpacity(0.2),
              child: Center(
                child: Text(
                  "[Помилка завантаження]",
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            );
          },
        ),
      );
    }

    if (cleanText.startsWith('[FILE:') && cleanText.endsWith(']')) {
      // Витягуємо вміст всередині квадратних дужок після [FILE:
      final String innerContent = cleanText.substring(6, cleanText.length - 1);

      String fileUrl = innerContent;
      String fileName = "Document";

      // Якщо у нас збережено у форматі "url|name"
      if (innerContent.contains('|')) {
        final parts = innerContent.split('|');
        fileUrl = parts[0];
        fileName = parts.length > 1 ? parts[1] : parts[0].split('/').last;
      } else {
        fileName = fileUrl.split('/').last;
      }

      final Color baseTextColor = widget.message.isMe ? const Color(0xFF0F0F1A) : Colors.white;

      final String fullUrl = fileUrl.startsWith('http')
          ? fileUrl
          : '${ApiConfig.baseUrl}${fileUrl.startsWith('/') ? fileUrl : '/$fileUrl'}';

      return GestureDetector(
        onTap: () async {
          debugPrint("Клік на файл: $fullUrl");
          final Uri uri = Uri.parse(fullUrl);

          // Спеціальний режим для мобільних додатків, щоб файл відкривався/скачувався зовнішнім браузером або системою
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication, // Відкриває у зовнішньому браузері/системній програмі завантаження
            );
          } else {
            debugPrint("Не вдалося відкрити посилання: $fullUrl");
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0), size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName, // <--- Тепер тут буде справжня назва файлу, а не айдішнік!
                style: TextStyle(
                  color: baseTextColor,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return _buildHighlightedText(
      rawContent,
      widget.searchQuery,
      widget.currentMatchIndex,
      widget.messageIndex,
      widget.foundMatches,
    );
  }
}