import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../api_config.dart';
import 'package:flutter/foundation.dart';
import 'sound_service.dart';
import '../user_session.dart';
import 'settings_service.dart';
import 'dart:async'; // Для Timer
import 'package:http/http.dart' as http; // Для http
import '../api_service.dart';

class ChatManager {
  static final ChatManager _instance = ChatManager._internal();
  factory ChatManager() => _instance;
  ChatManager._internal();
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;
  int _friendRequestsCount = 0;
  int get friendRequestsCount => _friendRequestsCount;
  VoidCallback? onFriendRequestsChanged;

  final List<Function(String userId, bool isOnline)> _statusListeners = [];

  void addStatusListener(Function(String userId, bool isOnline) listener) {
    if (!_statusListeners.contains(listener)) {
      _statusListeners.add(listener);
    }
  }

  void removeStatusListener(Function(String userId, bool isOnline) listener) {
    _statusListeners.remove(listener);
  }

  IO.Socket? _socket;

  bool isConnected = false;
  Function(bool)? onStatusChanged;

  Timer? _heartbeatTimer;

  IO.Socket? get socket => _socket;

  VoidCallback? onNewMessageReceived;
  VoidCallback? onChatListNeedsRefresh;

  void init(String userId) {
    if (_socket != null) return;

    print('DEBUG: Ініціалізація сокета для користувача: $userId');


    // 🚀 Запускаємо серцебиття для оновлення онлайну
    _startHeartbeat();

    _socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'path': '/socket.io/',
      'autoConnect': false,
      'auth': {'user_id': userId.toString()},
      'connectTimeout': 10000,
      'reconnection': true,
      'reconnectionAttempts': double.infinity, // <--- Змінюємо на нескінченність або прибираємо обмеження
      'reconnectionDelay': 1000,               // Початкова затримка перед реконектом (1 сек)
      'reconnectionDelayMax': 5000,
    });

    _socket!.onConnect((_) {
      print('DEBUG: Сокет підключено!');
      isConnected = true;
      if (onStatusChanged != null) onStatusChanged!(true);
    });

    _socket!.onDisconnect((reason) {
      print('DEBUG: Сокет відключено: $reason');
      isConnected = false;
      if (onStatusChanged != null) onStatusChanged!(false);
    });

    _socket!.onConnectError((err) => print('DEBUG: Помилка підключення: $err'));
    _socket!.onError((err) => print('DEBUG: Помилка сокета: $err'));

    // --- БЕЗПЕЧНИЙ ВИКЛИК ЗВУКІВ БЕЗ ASYNC/AWAIT УНУТРІ ---
    _socket!.on('new_message', (data) {
      final String senderId = data['sender_id']?.toString() ?? "";
      final String myId = UserSession().currentUser?.id.toString() ?? "";

      if (senderId != myId && senderId.isNotEmpty) {
        SettingsService.isChatSoundEnabled().then((isEnabled) {
          if (isEnabled) {
            SoundService.playIncomingMessage();
          }
        });
        // 🚀 1. Збільшуємо лічильник непрочитаних для нижнього бейджа
        _unreadCount++;
        if (onUnreadChanged != null) {
          onUnreadChanged!();
        }

        // 🚀 2. Оновлюємо і список чатів, і UI
        onNewMessageReceived?.call();
        onChatListNeedsRefresh?.call();
      }
    });

    _socket!.on('new_notification', (data) {
      print("🕵️ [SOUND_DETECTIVE] 🔔 Отримано подію 'new_notification'. Перевіряємо налаштування звуку...");

      SettingsService.isMatchAlertsEnabled().then((isEnabled) {
        print("🕵️ [SOUND_DETECTIVE] 🎛️ Статус isMatchAlertsEnabled() зчитано як: $isEnabled");

        if (isEnabled) {
          print("🕵️ [SOUND_DETECTIVE] ✅ Успіх! Відтворюємо звук нотифікації.");
          SoundService.playNotification();
        } else {
          print("🕵️ [SOUND_DETECTIVE] ❌ Звук НЕ відтворено, оскільки налаштування вимкнене (false або null).");
        }
      }).catchError((error) {
        print("🕵️ [SOUND_DETECTIVE] 💥 ПОМИЛКА при зчитуванні SettingsService: $error");
      });
    });
    // -----------------------------------------------------

    _socket!.onAny((event, data) {
      print('DEBUG: ВІД СЕРВЕРА ПРИЙШЛА ПОДІЯ: "$event" | Дані: $data');
    });

    _socket!.connect();

    _socket!.on('user_status_changed', (data) {
      final String changedUserId = data['user_id']?.toString() ?? "";
      final bool isOnline = data['is_online'] ?? false;

      if (changedUserId.isNotEmpty) {
        // Викликаємо кожного зареєстрованого слухача у списку
        for (var listener in _statusListeners) {
          listener(changedUserId, isOnline);
        }
      }
    });


  }

  void joinChat(String chatId) {
    socket?.emit('join_chat', {'chat_id': chatId});
  }

  void sendMessage(String chatId, String senderId, String content, {String? replyTo}) {
    socket?.emit('send_message', {
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'reply_to_id': replyTo,
    });
  }

  Function()? onUnreadChanged;

  void setUnreadCount(int count) {
    _unreadCount = count;
    if (onUnreadChanged != null) {
      onUnreadChanged!();
    }
  }

  void setFriendRequestsCount(int count) {
    _friendRequestsCount = count;
    onFriendRequestsChanged?.call();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Кожні 30 секунд пінг на сервер
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/users/ping'),
          headers: await ApiService.getHeaders(),
        );
      } catch (e) {
        debugPrint("Heartbeat ping error: $e");
      }
    });
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socket?.disconnect();
    _socket = null;
  }

}