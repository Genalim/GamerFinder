import 'Welcome_screen.dart';
import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GameBuddy',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
      ),
      // Ось тут замінюємо старий RegistrationScreen на новий
      home: const WelcomeScreen(),
    );
  }
}