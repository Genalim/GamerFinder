import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Home_Feed_screen.dart';
import 'custom_widgets.dart';
import 'friends_screen.dart';
import 'chats_screen.dart';
import 'settings_screen.dart';
import 'services/chat_manager.dart';
import 'user_session.dart';
import "api_config.dart";
import 'api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Використовуємо звичайні ключі без типізації, щоб уникнути помилок типу
  final GlobalKey _friendsKey = GlobalKey();
  final GlobalKey _chatsKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // 🔔 Підписуємося на оновлення непрочитаних через слухач
    ChatManager().addUnreadListener(_handleUnreadChanged);

    _initChatManager();

    _screens = [
      const HomeFeedScreen(),
      FriendsScreen(key: _friendsKey),
      ChatsScreen(key: _chatsKey),
      const SettingsScreen(),
    ];

    ChatManager().onFriendRequestsChanged = () {
      if (mounted) setState(() {});
    };
  }

  void _handleUnreadChanged() {
    if (mounted) {
      setState(() {
        debugPrint("🔔 [NAV_BAR] Отримано сигнал про нові повідомлення! unreadCount = ${ChatManager().unreadCount}");
      });
    }
  }

  @override
  void dispose() {
    // Обов'язково відписуємось при знищенні екрана
    ChatManager().removeUnreadListener(_handleUnreadChanged);
    super.dispose();
  }

  Future<void> _initChatManager() async {
    final userId = await UserSession.getUserId();
    if (userId != null) {
      ChatManager().init(userId.toString());
      // Видаляємо стару синтаксичну конструкцію ChatManager().onUnreadChanged,
      // оскільки тепер використовуємо addUnreadListener вище.
      _fetchInitialUnreadCount();
    }
  }

  Future<void> _fetchInitialUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/list'),
        headers: await ApiService.getHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        int totalUnread = data.fold(0, (sum, item) => sum + (item['unread_count'] as int? ?? 0));

        ChatManager().setUnreadCount(totalUnread);
      }
    } catch (e) {
      debugPrint("Error fetching unread count: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 🚀 Оновлення для Home Feed (Вкладка 0) — тільки ваш профіль та ігри
    if (index == 0) {
      HomeFeedScreen.onRefreshRequested?.call();
      debugPrint("DEBUG: Оновлення профілю та ігор у HomeFeed без скидання стрічки!");
    }

    // Оновлення для Друзів
    if (index == 1) {
      final state = _friendsKey.currentState;
      if (state != null && state is dynamic) {
        try {
          (state as dynamic).refreshData();
        } catch (e) {
          debugPrint("Помилка оновлення списку друзів: $e");
        }
      }
    }

    // Оновлення для Чатів
    if (index == 2) {
      // Викликаємо наш "гачок", який ми зареєстрували в ChatListWidget
      ChatListWidget.onRefreshRequested?.call();
      debugPrint("DEBUG: Примусове оновлення списку чатів через onRefreshRequested!");
    }
  }


  @override
  Widget build(BuildContext context) {
    debugPrint("BUILD: unreadCount = ${ChatManager().unreadCount}");

    // 🚀 Надійне керування кнопкою "Назад" через стабільний onPopInvoked
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        // 1. Якщо ми не на стрічці (вкладка 0), спочатку повертаємось на стрічку
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }

        // 2. Якщо ми вже на стрічці — згортаємо додаток у фоновий режим
        await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFF0F0F13),

        // IndexedStack зберігає стан екранів
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),

        bottomNavigationBar: NeonBottomNavigator(
          selectedIndex: _selectedIndex,
          onTap: _onItemTapped,
          hasUnreadMessage: ChatManager().unreadCount > 0,
          hasUnreadRequests: ChatManager().friendRequestsCount > 0,
        ),
      ),
    );
  }
}