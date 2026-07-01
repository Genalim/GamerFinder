import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatManager {
  static final ChatManager _instance = ChatManager._internal();
  factory ChatManager() => _instance;
  ChatManager._internal();

  IO.Socket? _socket; // Зробили змінну nullable

  // Геттер, який перевіряє ініціалізацію
  IO.Socket get socket {
    if (_socket == null) {
      throw Exception("ChatManager не ініціалізовано! Спочатку викличте init()");
    }
    return _socket!;
  }

  void init(String userId) {
    if (_socket != null) return; // Якщо вже є, не ініціалізуємо ще раз

    _socket = IO.io('http://10.0.2.2:8000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'query': {'user_id': userId},
      'connectTimeout': 10000, // 10 секунд
      'reconnection': true,   // Дозволь автоматичне перепідключення
      'reconnectionAttempts': 5,
    });

    _socket!.connect();

    _socket!.onConnect((_) => print('DEBUG: Сокет підключено!'));
    _socket!.onConnectError((err) => print('DEBUG: Помилка підключення: $err'));
    _socket!.onError((err) => print('DEBUG: Помилка сокета: $err'));

    _socket!.onAny((event, data) {
      print('DEBUG: ПРИЛЕТІЛА ПОДІЯ: $event, ДАНІ: $data');
    });
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