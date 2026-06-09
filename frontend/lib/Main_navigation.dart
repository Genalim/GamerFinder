import 'package:flutter/material.dart';
import 'Home_Feed_screen.dart';
import 'custom_widgets.dart';
import 'friends_screen.dart';
import 'chats_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // 1. Ключ для доступу до методів FriendsScreen
  final GlobalKey<State<FriendsScreen>> _friendsKey = GlobalKey();

  // 2. Оголошуємо список як late (ініціалізуємо в initState)
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeFeedScreen(),
      FriendsScreen(key: _friendsKey), // Тут ми передаємо наш ключ
      const ChatsScreen(),
      const SettingsScreen(),
    ];
  }

  // Метод для зміни табів
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Якщо користувач натиснув на FriendsScreen (індекс 1)
    if (index == 1) {
      final state = _friendsKey.currentState;
      // Викликаємо метод оновлення, якщо він існує
      if (state != null && state is dynamic) {
        try {
          (state as dynamic).refreshData();
        } catch (e) {
          debugPrint("Помилка оновлення списку: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      ),
    );
  }
}