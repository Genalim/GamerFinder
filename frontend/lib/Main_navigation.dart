import 'package:flutter/material.dart';
import 'Home_Feed_screen.dart';
import 'custom_widgets.dart';
import 'friends_screen.dart';
import 'chats_screen.dart';
import 'settings_screen.dart';
import 'services/chat_manager.dart';
import 'user_session.dart';

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

  Future<void> _initChatManager() async {
    final userId = await UserSession.getUserId();
    if (userId != null) {
      ChatManager().init(userId.toString());
      ChatManager().onUnreadChanged = () {
        if (mounted) setState(() {});
      };
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0F0F13),

      // IndexedStack зберігає стан екранів, але ми їх "смикаємо" через refreshData
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: NeonBottomNavigator(
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped, // Використовуємо наш оновлений метод
        hasUnreadMessage: ChatManager().unreadCount > 0,
        hasUnreadRequests: ChatManager().friendRequestsCount > 0,
      ),
    );
  }
}