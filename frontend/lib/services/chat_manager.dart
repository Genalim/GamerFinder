import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../api_config.dart';
import 'package:flutter/foundation.dart';
import 'sound_service.dart';
import '../user_session.dart';
import 'settings_service.dart';

class ChatManager {
  static final ChatManager _instance = ChatManager._internal();
  factory ChatManager() => _instance;
  ChatManager._internal();
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;
  int _friendRequestsCount = 0;
  int get friendRequestsCount => _friendRequestsCount;
  VoidCallback? onFriendRequestsChanged;

  IO.Socket? _socket;

  bool isConnected = false;
  Function(bool)? onStatusChanged;

  IO.Socket? get socket => _socket;

  void init(String userId) {
    if (_socket != null) return;

    print('DEBUG: Ініціалізація сокета для користувача: $userId');

    _socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'path': '/socket.io/',
      'autoConnect': false,
      'auth': {'user_id': userId.toString()},
      'connectTimeout': 10000,
      'reconnection': true,
      'reconnectionAttempts': 5,
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
      }
    });

    _socket!.on('new_notification', (data) {
      SettingsService.isMatchAlertsEnabled().then((isEnabled) {
        if (isEnabled) {
          SoundService.playNotification();
        }
      });
    });
    // -----------------------------------------------------

    _socket!.onAny((event, data) {
      print('DEBUG: ВІД СЕРВЕРА ПРИЙШЛА ПОДІЯ: "$event" | Дані: $data');
    });

    _socket!.connect();
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
}