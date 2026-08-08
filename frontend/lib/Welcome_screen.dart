import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';
import 'Game_Selection.dart';
import 'sign_in_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, // 🚀 Займаємо всю ширину екрана
        height: double.infinity, // 🚀 Займаємо всю висоту екрана
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 1.0],
            colors: [
              Color(0xFF0F0F1A),
              Color(0xFF181826),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isCompact = constraints.maxHeight < 700;

              return SingleChildScrollView( // 🚀 Додаємо прокрутку на випадок дуже маленьких екранів, щоб нічого не зрізалося
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: isCompact ? 10.0 : 20.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center, // 🚀 Центруємо всі елементи по горизонталі
                      children: [
                        // 1) Логотип Games
                        Center(
                          child: Image.asset(
                            'assets/images/Welcome_screen_games.webp',
                            width: isCompact ? 110 : 130,
                            height: isCompact ? 70 : 90,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // 2) Заголовок + Підзаголовок
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Find your perfect\ngaming squad',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: isCompact ? 20 : 24,
                                height: 1.1,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Connect with players,\nanytime, anywhere',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w400,
                                fontSize: isCompact ? 12 : 14,
                                height: 1.21,
                                color: const Color(0xFFA3A3B5),
                              ),
                            ),
                          ],
                        ),

                        // 3) Центральна ілюстрація
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              width: isCompact ? 190 : 260,
                              height: isCompact ? 190 : 260,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/Welcome_screen_play_and_win.webp'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 4) Нижня частина (Кнопка + Sign in)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const GameSelectionScreen()),
                                );
                              },
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: 320,
                                  maxHeight: isCompact ? 75 : 95,
                                ),
                                child: Image.asset(
                                  'assets/images/Button_Get_Started.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 4 : 8),
                            const Text(
                              'Already have an account?',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFFA3A3B5),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: isCompact ? 2 : 6),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SignInScreen()),
                                );
                              },
                              child: Text(
                                'Sign in',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: const Color(0xFF00FFD1),
                                  fontSize: isCompact ? 16 : 19,
                                  fontWeight: FontWeight.w400,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 6 : 12),
                            const Text(
                              'Find. Match. Win.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFFA3A3B5),
                                fontSize: 8,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}