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
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'chat_forward_screen.dart';
import 'dart:async';
// Зверни увагу: нам потрібен ChatMessageWidget, ChatMessage, MessageStatus і getCleanContent
// Якщо вони лежать в chat_room_screen.dart, краще винести їх в окремий файл (наприклад, chat_components.dart)
// Або тимчасово імпортувати з chat_room_screen.dart, якщо Dart дозволить без конфліктів.
// Для надійності, я додав їх копії в кінець цього файлу (як ти робив раніше), щоб все працювало "з коробки".

class GroupChatRoomScreen extends StatefulWidget {
  final List<String> participantNames;
  final String chatId;
  final VoidCallback onBack;
  final int unreadCount;

  const GroupChatRoomScreen({
    super.key,
    required this.participantNames,
    required this.chatId,
    required this.onBack,
    this.unreadCount = 0,
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

  late final Function(String, bool) _statusListener;

  // Використовуємо контролери пакета scrollable_positioned_list
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  bool _isInitializing = true;
  int _remainingUnread = 0;
  String? _lastSentReadMessageId;
  int _lastSentMessageIndex = -1;
  bool _isAutoScrolling = false;


  String? _groupName;

  int _currentOffset = 0;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _hasMoreNewer = true;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _foundMatches = [];
  List<int> _foundIndices = [];
  int _currentFoundIndex = -1;

  Map<String, dynamic>? _groupData;
  Map<String, dynamic>? _pinnedMessage;

  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    _remainingUnread = widget.unreadCount;
    _fetchGroupInfo();
    _groupName = "New Group";
    WidgetsBinding.instance.addObserver(this);
    _currentBg = _backgrounds[Random().nextInt(_backgrounds.length)];

    // --- Ініціалізація чату ---
    final myId = UserSession().currentUser?.id.toString() ?? "";
    ChatManager().init(myId);
    ChatManager().joinChat(widget.chatId);

    _statusListener = (userId, isOnline) {
      if (!mounted) return;
      if (_groupData != null && _groupData!['members'] != null) {
        setState(() {
          List members = _groupData!['members'];
          for (var member in members) {
            final memberId = (member['id'] ?? member['user_id'])?.toString();
            if (memberId == userId) {
              member['is_online'] = isOnline;
              print("🔄 [GROUP_REALTIME_STATUS] Учасник $userId змінив статус на: $isOnline");

              // 🚀 ЩОЙНО ХТОСЬ ІЗ УЧАСНИКІВ СТАВ ОНЛАЙН — синхронізуємо повідомлення та статуси прочитання
              if (isOnline && widget.chatId != null && _messages.isNotEmpty) {
                _loadHistory(widget.chatId, isLoadNewer: true);
              }
              break;
            }
          }
        });
      }
    };
    ChatManager().addStatusListener(_statusListener);

    // Передаємо unreadCount у завантаження історії
    _loadHistory(widget.chatId, unreadCount: widget.unreadCount);

    // --- Підписки на сокети ---
    ChatManager().onMessageReceivedInChat = (data) {
      if (mounted) {
        _addNewMessageToUi(data);
      }
    };

    ChatManager().onMessagesReadInChat = (data) {
      if (data['chat_id'] == widget.chatId) {
        _markMessagesAsReadUi(data);
      }
    };

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

    // --- Логіка слухача позицій скролу (ScrollablePositionedList) ---
    _itemPositionsListener.itemPositions.addListener(() {
      if (!mounted) return;
      if (_isInitializing) return;

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
          final String content = msg['content']?.toString() ?? "";

          // Якщо повідомлення НЕ наше
          if (msgSenderId != myId) {
            // 🛡️ ФРОНТЕНД-ФІЛЬТР: Шлемо запит ТІЛЬКИ якщо ми проскролили далі вперед (новий індекс більший за попередній)
            if (_lastSentReadMessageId != msgId && reversedIdx > _lastSentMessageIndex) {
              _lastSentReadMessageId = msgId;
              _lastSentMessageIndex = reversedIdx; // Оновлюємо планку прогресу

              print("🎯 [FRONTEND DETECTIVE] 🚀 ШЛЕМО НА БЕКЕНД РІД ДО ID: $msgId (Індекс масиву: $reversedIdx)");
              _markAsReadOnServer(widget.chatId!, lastMessageId: msgId);
            }
          }
        }
      }

      // --- Пагінація та кнопка вниз ---
      final maxPosition = positions.reduce((max, p) => p.itemTrailingEdge > max.itemTrailingEdge ? p : max);
      final minPosition = positions.reduce((min, p) => min.itemLeadingEdge < min.itemLeadingEdge ? p : min);

      if (maxPosition.index >= _messages.length - 2 && !_isLoadingMore && _hasMoreMessages) {
        _loadHistory(widget.chatId!, isLoadMore: true);
      }
      if (minPosition.index <= 2 && !_isLoadingMore && _hasMoreNewer) {
        _loadHistory(widget.chatId!, isLoadNewer: true);
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
    // --- Логіка вводу тексту ---
    _textController.addListener(() {
      if (_textController.text.isNotEmpty) {
        ChatManager().socket?.emit('typing', {'chat_id': widget.chatId});
      }
      final isEmpty = _textController.text.trim().isEmpty;
      if (_isInputEmpty != isEmpty) setState(() => _isInputEmpty = isEmpty);
    });

    // 🔄 Додаємо локальний таймер оновлення інтерфейсу кожну хвилину, щоб статуси "offline X minutes" перемальовувались
    _uiRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    ChatManager().onReconnected = () {
      if (!mounted || widget.chatId == null) return;
      debugPrint("🔄 [CHAT_ROOM] Сокет ожив! Синхронізуємо пропущені повідомлення...");

      // 🚀 Примусово просимо завантажити новіші повідомлення відносно останнього у списку
      if (_messages.isNotEmpty) {
        _loadHistory(widget.chatId!, isLoadNewer: true);
      } else {
        // Якщо раптом список чомусь був порожнім — робимо повне перезавантаження історії
        _loadHistory(widget.chatId!);
      }
    };

  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();

    // 🛡️ Очищаємо колбеки сокета
    ChatManager().onMessageReceivedInChat = null;
    ChatManager().onMessagesReadInChat = null;
    ChatManager().onReconnected = null;

    ChatManager().removeStatusListener(_statusListener);

    ChatManager().socket?.off('user_typing');
    ChatManager().socket?.off('message_edited');
    ChatManager().socket?.off('message_deleted');
    ChatManager().socket?.off('reaction_updated');
    ChatManager().socket?.off('error');

    _textController.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.addObserver(this);
    super.dispose();
  }


  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 250), () {
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
        final data = json.decode(response.body);

        final myId = UserSession().currentUser?.id.toString() ?? "";

        // 🛡️ ЗАХИСТ ВІД ЗАТИРАННЯ БАЗОЮ:
        // Якщо учасник у списку — це ми самі, одразу ставити йому is_online = true,
        // щоб не чекати поки сокет пришле подію повторно.
        if (data['members'] != null) {
          for (var member in data['members']) {
            final memberId = (member['id'] ?? member['user_id'])?.toString();
            if (memberId == myId) {
              member['is_online'] = true;
            }
          }
        }

        setState(() {
          _groupData = data;
          _groupName = data['name'];
          _pinnedMessage = data['pinned_message'];
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження інфо: $e");
    }
  }

  // --- Методи роботи з файлами ---////
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00F5A0))),
    );

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/chats/${widget.chatId}/upload');
      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll(await ApiService.getHeaders());
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String fileUrl = data['file_url'];

        final String myId = UserSession().currentUser?.id.toString() ?? "";
        final String fileOriginalName = data['file_name'] ?? 'document';
        final String content = isImage ? "[IMAGE:$fileUrl]" : "[FILE:$fileUrl|$fileOriginalName]";
        final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

        _addNewMessageToUi({
          'id': tempId,
          'chat_id': widget.chatId,
          'content': content,
          'sender_id': myId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        ChatManager().sendMessage(widget.chatId, myId, content);
      } else {
        if (mounted) _showErrorSnackBar("Upload failed: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnackBar("Error uploading file");
      }
    }
  }

  // --- МЕТОДИ ДЛЯ РОБОТИ З ПОВІДОМЛЕННЯМИ ---

  Future<void> _loadHistory(String chatId, {bool isLoadMore = false, bool isLoadNewer = false, int unreadCount = 0}) async {
    if (_isLoadingMore || (!_hasMoreMessages && isLoadMore) ||
        (!_hasMoreNewer && isLoadNewer)) return;

    setState(() => _isLoadingMore = true);

    // 🕵️ ДЕТЕКТИВ №1: Фіксуємо вхідні параметри та початковий unreadCount
    print(
        "🕵️ [GROUP_DET_HIST] Запуск _loadHistory. isLoadMore: $isLoadMore, isLoadNewer: $isLoadNewer, поточна кількість _messages у пам'яті: ${_messages.length}, unreadCount: $unreadCount, widget.unreadCount: ${widget.unreadCount}");

    try {
      int currentLimit = 50;
      String queryParams = "limit=$currentLimit";

      if (isLoadMore && _messages.isNotEmpty) {
        final oldestMessageId = _messages.first['id'];
        queryParams += "&before_message_id=$oldestMessageId";
      } else if (isLoadNewer && _messages.isNotEmpty) {
        final newestMessageId = _messages.last['id'];
        queryParams += "&after_message_id=$newestMessageId";
      } else {
        queryParams += "&offset=0";
      }

      // 🕵️ ДЕТЕКТИВ №2: Показуємо точний URL запиту на сервер
      final targetUrl = '${ApiConfig.baseUrl}/messages/$chatId?$queryParams';
      print("🕵️ [GROUP_DET_HIST] Стукаємо на бекенд -> URL: $targetUrl");

      final response = await http.get(
        Uri.parse(targetUrl),
        headers: await ApiService.getHeaders(),
      );

      print("🕵️ [GROUP_DET_HIST] Відповідь від сервера. Статус: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);

        // 🕵️ ДЕТЕКТИВ №3: Скільки саме елементів прийшло від бекенду
        print("🕵️ [GROUP_DET_HIST] Сервер повернув елементів у цьому пакеті: ${list.length}");
        if (list.isNotEmpty) {
          print("🕵️ [GROUP_DET_HIST] Перше повідомлення з пачки ID: ${list.first['id']}, час: ${list.first['created_at']}");
          print("🕵️ [GROUP_DET_HIST] Останнє повідомлення з пачки ID: ${list.last['id']}, час: ${list.last['created_at']}");
        }

        if (list.isEmpty) {
          print("🕵️ [GROUP_DET_HIST] Пачка порожня.");
          if (isLoadMore) {
            setState(() => _hasMoreMessages = false);
          } else if (isLoadNewer) {
            setState(() => _hasMoreNewer = false);
          }
        } else {
          final String myId = UserSession().currentUser?.id.toString() ?? "";
          final String myNickname = UserSession().currentUser?.nickname ?? "You";

          final newMessages = list.map((item) {
            final String senderId = item['sender_id'].toString();
            String nickname = item['sender_nickname'] ?? '';
            if (nickname.isEmpty) {
              nickname = (senderId == myId) ? myNickname : (item['sender_name'] ?? "Member");
            }

            return {
              'id': item['id'].toString(),
              'content': item['content'],
              'sender_id': senderId,
              'sender_nickname': nickname,
              'isMe': senderId == myId,
              'time': _parseDateTime(item['created_at']),
              'status': item['status'] ?? 'sent',
              'reply_to_id': item['reply_to_id'],
              'likes_count': item['likes_count'] ?? 0,
              'is_liked_by_me': item['is_liked_by_me'] ?? false,
            };
          }).toList();

          setState(() {
            if (isLoadMore || isLoadNewer) {
              final Map<String, Map<String, dynamic>> uniqueMap = {};
              for (var msg in [..._messages, ...newMessages]) {
                uniqueMap[msg['id'].toString()] = msg;
              }
              _messages = uniqueMap.values.toList();
            } else {
              final Map<String, Map<String, dynamic>> uniqueMap = {};
              for (var msg in newMessages) {
                uniqueMap[msg['id'].toString()] = msg;
              }
              _messages = uniqueMap.values.toList();
            }
            _messages.sort((a, b) => a['time'].compareTo(b['time']));
          });

          // 🕵️ ДЕТЕКТИВ ПАЧКИ: Виводимо всю пачку із загальними та реверс-індексами
          print("📦 ---------------- [GROUP] ПАЧКА ПОВІДОМЛЕНЬ У ПАМ'ЯТІ (Всього: ${_messages.length}) ----------------");
          for (int i = 0; i < _messages.length; i++) {
            final m = _messages[i];
            final int reversedIndex = _messages.length - 1 - i;
            print("📦 [GROUP_DUMP] Масив-індекс: $i | Реверс-індекс (екранний): $reversedIndex | Текст: '${m['content']}' | Статус: ${m['status']} | ID: ${m['id']}");
          }
          print("📦 --------------------------------------------------------------------------------");

          // ПРИМУСОВИЙ СТРИБОК ПРИ ПЕРВИННОМУ ВХОДІ
          if (!isLoadMore && !isLoadNewer) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_messages.isNotEmpty) {
                final int effectiveUnread = unreadCount > 0 ? unreadCount : widget.unreadCount;

                if (effectiveUnread > 0) {
                  setState(() {
                    _remainingUnread = effectiveUnread;
                    _showScrollDownButton = true;
                  });
                }

                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) {
                    setState(() {
                      _isInitializing = false;
                    });
                  }
                });

                if (_itemScrollController.isAttached) {
                  if (effectiveUnread > 0) {
                    final int targetIndex = min(effectiveUnread, _messages.length - 1);
                    print("🎯 [GROUP_SCROLL] Точний стрибок за unreadCount: $effectiveUnread на позицію $targetIndex");
                    _itemScrollController.jumpTo(index: targetIndex, alignment: 0.2);
                  } else {
                    print("🎯 [GROUP_SCROLL] Непрочитаних немає, стрибаємо на 0");
                    _itemScrollController.jumpTo(index: 0, alignment: 0.0);
                  }
                }
              }
            });
          }
        }
      }
    } catch (e, stackTrace) {
      print("🕵️ [GROUP_DET_HIST] ПОМИЛКА в _loadHistory: $e");
      debugPrint("$stackTrace");
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
    if (!mounted) return;

    final String msgChatId = messageData['chat_id']?.toString() ?? "";
    if (msgChatId.isNotEmpty && msgChatId != widget.chatId) return;

    final String senderId = messageData['sender_id']?.toString() ?? "";
    final String content = messageData['content']?.toString() ?? "";
    final DateTime time = _parseDateTime(messageData['created_at'] ?? DateTime.now());
    final String serverMessageId = messageData['id']?.toString() ?? '';

    // 🎯 Оголошуємо myId одразу тут
    final String myId = UserSession().currentUser?.id.toString() ?? "";

    setState(() {
      // Шукаємо недавнє локальне повідомлення з тимчасовим ID (temp_)
      final int existingIndex = _messages.indexWhere((m) =>
      m['id'].toString().startsWith('temp_') &&
          m['content'] == content &&
          m['sender_id'] == senderId
      );

      if (existingIndex != -1) {
        _messages[existingIndex]['id'] = serverMessageId;
        _messages[existingIndex]['status'] = messageData['status'] ?? 'sent';
      } else {
        final bool isDuplicate = _messages.any((m) => m['id'].toString() == serverMessageId);

        if (isDuplicate) return;

        final String myNickname = UserSession().currentUser?.nickname ?? "You";

        String nickname = messageData['sender_nickname'] ?? '';
        if (nickname.isEmpty) {
          nickname = (senderId == myId) ? myNickname : "Member";
        }

        _messages.add({
          'id': serverMessageId,
          'content': content,
          'sender_id': senderId,
          'sender_nickname': nickname,
          'isMe': senderId == myId,
          'time': time,
          'status': messageData['status'] ?? 'sent',
          'reply_to_id': messageData.containsKey('reply_to_id') ? messageData['reply_to_id'] : null,
          'likes_count': messageData['likes_count'] ?? 0,
          'is_liked_by_me': messageData['is_liked_by_me'] ?? false,
        });
      }

      _messages.sort((a, b) => a['time'].compareTo(b['time']));
    });

    // 🚀 Автоматичне прочитання
    if (senderId != myId && widget.chatId.isNotEmpty) {
      print("🚀 [GROUP AUTO-READ] Автоматично позначаємо нове повідомлення $serverMessageId як прочитане.");
      _markAsReadOnServer(widget.chatId, lastMessageId: serverMessageId);
    }
  }

  Future<void> _handleInitialScroll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (_itemScrollController.isAttached && _messages.isNotEmpty) {
      _itemScrollController.jumpTo(index: 0, alignment: 0.0);
    }
  }

  void _markMessagesAsReadUi(dynamic data) {
    if (!mounted) return;
    final String chatId = data['chat_id']?.toString() ?? "";
    if (chatId != widget.chatId) return;

    final String? lastReadId = data['last_read_id']?.toString();
    final String myId = UserSession().currentUser?.id.toString() ?? "";

    setState(() {
      if (lastReadId != null) {
        final int targetIndex = _messages.indexWhere((m) => m['id'].toString() == lastReadId);

        for (int i = 0; i < _messages.length; i++) {
          var msg = _messages[i];
          bool shouldBeRead = (targetIndex != -1 && i <= targetIndex);

          if (shouldBeRead && msg['status'] != 'read') {
            // Оновлюємо статус як для чужих, так і для наших повідомлень, якщо їх прочитали
            msg['status'] = 'read';
          }
        }
      }
    });
  }

  Future<void> _markAsReadOnServer(String chatId, {String? lastMessageId}) async {
    if (lastMessageId == null || lastMessageId.isEmpty) return;

    try {
      String url = '${ApiConfig.baseUrl}/messages/group/read-up-to/$chatId?last_message_id=$lastMessageId';

      final response = await http.patch(
        Uri.parse(url),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int serverUnread = data['unread_count'] ?? 0;

        final String myId = UserSession().currentUser?.id.toString() ?? "";
        setState(() {
          final int targetIndex = _messages.indexWhere((m) => m['id'].toString() == lastMessageId);

          for (int i = 0; i <= targetIndex && i < _messages.length; i++) {
            var msg = _messages[i];
            if (msg['sender_id'] == myId && msg['status'] != 'read') {
              msg['status'] = 'read'; // Твої повідомлення стають фіолетовими, коли група доскролила до них
            }
          }

          _remainingUnread = serverUnread;
          if (_remainingUnread <= 0) {
            _showScrollDownButton = false;
          }
        });
      }
    } catch (e) {
      debugPrint("Помилка read: $e");
    }
  }

  Future<void> _togglePinMessage(String messageId, bool isPinning) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/chats/${widget.chatId}/pin'),
        headers: await ApiService.getHeaders(),
        body: json.encode({'message_id': isPinning ? messageId : null}),
      );
      if (response.statusCode == 200) {
        setState(() {
          if (isPinning) {
            final msg = _messages.firstWhere((m) => m['id'].toString() == messageId, orElse: () => {});
            if (msg.isNotEmpty) {
              _pinnedMessage = {
                'id': msg['id'],
                'content': msg['content'],
                'sender_nickname': msg['sender_nickname'] ?? 'Member'
              };
            }
          } else {
            _pinnedMessage = null;
          }
        });
      }
    } catch (e) {
      debugPrint("Помилка піну: $e");
    }
  }

  void _showUnpinConfirmationDialog(String messageId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF181826),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF2B2B3B))),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Unpin message?", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Color(0xFF8E8EA9), size: 20)),
            ],
          ),
          content: const Text("Are you sure you want to unpin this message?", style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 14, fontFamily: 'Inter')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("No", style: TextStyle(color: Color(0xFF8E8EA9), fontWeight: FontWeight.bold))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5A0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                Navigator.pop(context);
                _togglePinMessage(messageId, false);
              },
              child: const Text("Yes", style: TextStyle(color: Color(0xFF0F0F1A), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied"), backgroundColor: Color(0xFF181826), duration: Duration(seconds: 1)));
      });
    } else if (action == 'Like') {
      _toggleReaction(message['id'].toString());
    } else if (action == 'Pin') {
      _togglePinMessage(message['id'].toString(), true);
    } else if (action == 'Unpin') {
      _showUnpinConfirmationDialog(message['id'].toString());
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
    int realMessageIndex = _foundMatches[_currentFoundIndex]['messageIndex']!;

    // Перерахунок індексу з урахуванням reverse: true
    int targetIndex = _messages.length - 1 - realMessageIndex;

    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
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
                if (_pinnedMessage != null) _buildPinnedMessageBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      _messages.isEmpty
                          ? const Center(
                        child: Text("No messages yet", style: TextStyle(color: Color(0xFF8E8EA9))),
                      )
                          : ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        reverse: true, // Реверс важливий для коректного скролу з 0 внизу!
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          // Дзеркальний індекс для reverse: true
                          final int reversedIndex = _messages.length - 1 - index;
                          final msg = _messages[reversedIndex];
                          final String msgId = msg['id'].toString();

                          final bool isHighlighted = _isSearching &&
                              _foundMatches.any((m) => m['messageIndex'] == reversedIndex);

                          final bool isNewDay = reversedIndex == 0 ||
                              !isSameDayGroup(msg['time'], _messages[reversedIndex - 1]['time']);

                          final status = GroupMessageStatus.values.firstWhere(
                                (e) => e.name == (msg['status'] ?? 'sent'),
                            orElse: () => GroupMessageStatus.sent,
                          );

                          return GroupChatMessageWidget(
                            searchQuery: _searchController.text,
                            currentMatchIndex: _currentFoundIndex,
                            messageIndex: reversedIndex,
                            foundMatches: _foundMatches,
                            showDateDivider: isNewDay,
                            isHighlighted: isHighlighted,
                            likesCount: msg['likes_count'] ?? 0,
                            isLikedByMe: msg['is_liked_by_me'] ?? false,
                            pinnedMessage: _pinnedMessage,
                            message: GroupChatMessage(
                              id: msgId,
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
                          right: 20,
                          bottom: 20,
                          child: GestureDetector(
                            onTap: () {
                              if (_messages.isNotEmpty) {
                                _markAsReadOnServer(widget.chatId, lastMessageId: _messages.last['id'].toString());
                              }
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

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _foundMatches = [];
        _currentFoundIndex = -1;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/${widget.chatId}/search?query=${Uri.encodeComponent(query)}'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> serverResults = json.decode(response.body);
        List<Map<String, dynamic>> newFoundMatches = [];

        for (var item in serverResults) {
          final String messageId = item['id'].toString();
          int localIndex = _messages.indexWhere((m) => m['id'] == messageId);

          if (localIndex != -1) {
            newFoundMatches.add({
              'messageIndex': localIndex,
              'messageId': messageId,
            });
          } else {
            // Якщо повідомлення знайдено бекендом, але його ще немає в локальному списку — додаємо його
            final String myId = UserSession().currentUser?.id.toString() ?? "";
            final parsedMsg = {
              'id': messageId,
              'content': item['content'],
              'sender_id': item['sender_id'].toString(),
              'sender_nickname': item['sender_nickname'] ?? "Member",
              'isMe': item['sender_id'].toString() == myId,
              'time': _parseDateTime(item['created_at']),
              'status': item['status'] ?? 'read',
              'likes_count': 0,
              'is_liked_by_me': false,
            };

            _messages.add(parsedMsg);
            _messages.sort((a, b) => a['time'].compareTo(b['time']));

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
          _currentFoundIndex = _foundMatches.isNotEmpty ? 0 : -1;
          _scrollToFoundMessage();
        });
      }
    } catch (e) {
      debugPrint("Помилка пошуку: $e");
    }
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

    int onlineCount = 0;
    int totalMembers = 0;

    final String myId = UserSession().currentUser?.id.toString() ?? "";
    print("🕵️ [ONLINE_DETECTIVE] Мій поточний ID з UserSession: '$myId' (тип: ${myId.runtimeType})");

    if (_groupData != null && _groupData!['members'] != null) {
      final List members = _groupData!['members'];
      totalMembers = members.length;
      print("🕵️ [ONLINE_DETECTIVE] Всього учасників у групі: $totalMembers");

      onlineCount = members.where((m) {
        final memberId = (m['id'] ?? m['user_id'])?.toString() ?? "";
        final bool serverIsOnline = m['is_online'] == true;
        final String nickname = m['nickname'] ?? m['name'] ?? 'Unknown';

        // Жорстка перевірка на совпадіння ID (провіримо чи це я)
        final bool isMe = (memberId == myId);

        // Хто вважається онлайн: або це я, або сервер каже що він true
        final bool finalOnlineState = isMe || serverIsOnline;

        print("🕵️ [ONLINE_DETECTIVE] - Учасник: '$nickname' (ID: '$memberId') | Сервер каже is_online: $serverIsOnline | Це я? $isMe => Враховуємо як онлайн: $finalOnlineState");

        return finalOnlineState;
      }).length;

      print("🕵️ [ONLINE_DETECTIVE] ✅ Загальний підсумок onlineCount: $onlineCount");
    } else {
      print("🕵️ [ONLINE_DETECTIVE] ⚠️ _groupData або _groupData['members'] ще порожні!");
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
                          : (_groupData != null
                          ? "$totalMembers members | $onlineCount online"
                          : "group"),
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
    debugPrint("DEBUG GROUP AVATAR URL: $avatarUrl"); // <--- Додай це сюди

    final List<dynamic> members = _groupData!['members'] ?? [];

    return SizedBox(
      width: 45,
      height: 45,
      child: ClipOval(
        child: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? buildAvatar(avatarUrl, '?', 45)
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
      return _buildLetterAvatar(initial, size);
    }

    final String fullAvatarUrl = avatarUrl.startsWith('http')
        ? avatarUrl
        : '${ApiConfig.baseUrl}${avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl'}';

    return Image.network(
      fullAvatarUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint("❌ ПОМИЛКА МЕРЕЖІ В ХЕДЕРІ: $error | URL: $fullAvatarUrl"); // <--- Додай це
        return _buildLetterAvatar(initial, size);
      },
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
              GestureDetector(
                onTap: _showAttachmentOptions,
                child: const Padding(padding: EdgeInsets.only(bottom: 8), child: FigmaAttachIcon()),
              ),
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
                            final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

                            _addNewMessageToUi({
                              'id': tempId,
                              'chat_id': widget.chatId,
                              'content': content,
                              'sender_id': myId,
                              'created_at': DateTime.now().toUtc().toIso8601String(),
                              'reply_to_id': replyId,
                            });

                            ChatManager().sendMessage(widget.chatId, myId, content, replyTo: replyId);
                            setState(() => _messageToReply = null);

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_itemScrollController.isAttached && _messages.isNotEmpty) {
                                _itemScrollController.scrollTo(
                                  index: 0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
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

  Widget _buildPinnedMessageBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF181826),
        border: Border(bottom: BorderSide(color: Color(0xFF2B2B3B), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin, color: Color(0xFF00F5A0), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (_pinnedMessage == null) return;
                final pinnedId = _pinnedMessage!['id'].toString();

                // 1. Шукаємо індекс у поточному списку
                int index = _messages.indexWhere((m) => m['id'].toString() == pinnedId);

                // 2. Якщо його немає в пам'яті (старе повідомлення) — підвантажуємо історію вгору
                while (index == -1 && _hasMoreMessages && !_isLoadingMore) {
                  await _loadHistory(widget.chatId, isLoadMore: true);
                  index = _messages.indexWhere((m) => m['id'].toString() == pinnedId);
                }

                // 3. Коли знайшли або воно вже було — скролимо до нього
                if (index != -1 && _itemScrollController.isAttached) {
                  int targetIndex = _messages.length - 1 - index;
                  _itemScrollController.scrollTo(
                    index: targetIndex,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: 0.5,
                  );
                } else {
                  _showErrorSnackBar("Pinned message is not available");
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pinnedMessage!['sender_nickname'] ?? "Pinned Message",
                    style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _pinnedMessage!['content'] ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showUnpinConfirmationDialog(_pinnedMessage!['id'].toString()),
            child: const Icon(Icons.close, color: Color(0xFF8E8EA9), size: 18),
          ),
        ],
      ),
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
  final List<Map<String, dynamic>> foundMatches;
  final Map<String, dynamic>? pinnedMessage;

  const GroupChatMessageWidget({
    super.key, required this.message, required this.likesCount, required this.isLikedByMe,
    required this.onActionSelected, required this.allMessages, this.showDateDivider = false,
    this.isHighlighted = false,
    required this.searchQuery,
    required this.currentMatchIndex,
    required this.messageIndex,
    required this.foundMatches,
    this.pinnedMessage,
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
                    onLongPress: () => _showBlurActions(context, widget.message.isMe, widget.pinnedMessage),
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
              if (!widget.message.isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(widget.message.senderName, style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              replyBlock,
              forwardBlock,
              _buildMessageContent(), // <--- Використовуємо наш новий обробник контенту
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

  void _showBlurActions(BuildContext context, bool isMe, Map<String, dynamic>? pinnedMessage) {
    final RenderBox? renderBox = _messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;

    // 🎯 Визначаємо, чи запінене саме це повідомлення зараз
    final bool isThisPinned = pinnedMessage != null && pinnedMessage['id']?.toString() == widget.message.id;

    List<Map<String, dynamic>> menuItems = [
      {"title": "Reply", "icon": const FigmaReplyIcon(), "color": const Color(0xFF00F5A0)},
      {"title": "Copy", "icon": const FigmaCopyIcon(), "color": const Color(0xFF00F5A0)},
      {"title": "Forward", "icon": const FigmaForwardIcon(), "color": const Color(0xFF00F5A0), "isForward": true},
      // 📌 Додаємо динамічний пункт Pin / Unpin
      {
        "title": isThisPinned ? "Unpin" : "Pin",
        "icon": const Icon(Icons.push_pin, size: 16, color: Color(0xFF00F5A0)),
        "color": const Color(0xFF00F5A0)
      },
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

  Widget _buildHighlightedText(String text, String query, int currentMatchIndex, int messageIndex, List<Map<String, dynamic>> foundMatches) {
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

  Widget _buildMessageContent() {
    final String rawContent = widget.message.content;
    final String cleanText = getCleanContentGroup(rawContent);

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
            return Container(
              width: 200,
              height: 100,
              color: Colors.red.withOpacity(0.2),
              child: const Center(
                child: Text(
                  "[Помилка завантаження]",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            );
          },
        ),
      );
    }

    if (cleanText.startsWith('[FILE:') && cleanText.endsWith(']')) {
      final String innerContent = cleanText.substring(6, cleanText.length - 1);
      String fileUrl = innerContent;
      String fileName = "Document";

      if (innerContent.contains('|')) {
        final parts = innerContent.split('|');
        fileUrl = parts[0];
        fileName = parts.length > 1 ? parts[1] : parts[0].split('/').last;
      } else {
        fileName = fileUrl.split('/').last;
      }

      final Color baseTextColor = widget.message.isMe ? const Color(0xFF0F0F1A) : Colors.white;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: widget.message.isMe ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0), size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fileName,
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