import 'Welcome_screen.dart';
import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';
import 'package:flutter/services.dart';
import 'services/sound_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  // Забезпечуємо ініціалізацію зв'язку з платформою перед викликом SystemChrome
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 Ініціалізуємо аудіоконтекст для коректної роботи звуків на всіх пристроях
  await SoundService.init();

  // Фіксуємо орієнтацію додатку суто у вертикальному положенні (Portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GameBuddy',
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
      ),
      home: const WelcomeScreen(),
    );
  }
}