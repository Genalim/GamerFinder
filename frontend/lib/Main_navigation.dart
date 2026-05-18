import 'package:flutter/material.dart';
import 'Home_Feed_screen.dart';
import 'custom_widgets.dart'; // Імпортуємо, де лежить наш новий бар

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeFeedScreen(),
    const Scaffold(body: Center(child: Text('Friends Screen', style: TextStyle(color: Colors.white)))),
    const Scaffold(body: Center(child: Text('Chats Screen', style: TextStyle(color: Colors.white)))),
    const Scaffold(body: Center(child: Text('Profile Screen', style: TextStyle(color: Colors.white)))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: _screens[_selectedIndex],

      // === НАШ НОВИЙ КАСTОМНИЙ БАР ===
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