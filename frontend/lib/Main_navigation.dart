import 'package:flutter/material.dart';
import 'Home_Feed_screen.dart';
import 'custom_widgets.dart';
import 'friends_screen.dart';
import 'chats_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeFeedScreen(),
    const FriendsScreen(),
    const ChatsScreen(),
    const Scaffold(
      backgroundColor: Color(0xFF0F0F13),
      body: Center(child: Text('Profile Screen', style: TextStyle(color: Colors.white))),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. Це не дасть всьому екрану підійматися при появі клавіатури
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF0F0F13),

      // 2. Використовуємо body для контенту
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // 3. Використовуємо bottomNavigationBar замість Stack
      bottomNavigationBar: NeonBottomNavigator(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}