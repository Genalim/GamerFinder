import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../api_config.dart'; // Імпортуємо твій конфіг

class ChatManager {
  static final ChatManager _instance = ChatManager._internal();
  factory ChatManager() => _instance;
  ChatManager._internal();

  IO.Socket? _socket;

  // Стан підключення
  bool isConnected = false;
  // Колбек для оновлення UI
  Function(bool)? onStatusChanged;

  IO.Socket get socket {
    if (_socket == null) {
      throw Exception("ChatManager не ініціалізовано! Спочатку викличте init()");
    }
    return _socket!;
  }

  void init(String userId) {
    if (_socket != null) return;

    // Використовуємо ApiConfig.baseUrl
    _socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'query': {'user_id': userId},
      'connectTimeout': 10000,
      'reconnection': true,
      'reconnectionAttempts': 5,
    });

    // Підключення
    _socket!.onConnect((_) {
      print('DEBUG: Сокет підключено!');
      isConnected = true;
      if (onStatusChanged != null) onStatusChanged!(true);
    });

    // Відключення
    _socket!.onDisconnect((reason) {
      print('DEBUG: Сокет відключено: $reason');
      isConnected = false;
      if (onStatusChanged != null) onStatusChanged!(false);
    });

    // Помилки
    _socket!.onConnectError((err) => print('DEBUG: Помилка підключення: $err'));
    _socket!.onError((err) => print('DEBUG: Помилка сокета: $err'));

    _socket!.connect();
  }

  void joinChat(String chatId) {
    socket.emit('join_chat', {'chat_id': chatId});
  }

  void sendMessage(String chatId, String senderId, String content) {
    socket.emit('send_message', {
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
    });
  }
}