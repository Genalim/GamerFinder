import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';
import 'Game_Selection.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
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
        child: Stack(
          children: [
            // 1) Логотип Games
            Positioned(
              top: 50,
              left: screenWidth / 2 - 142 / 2,
              width: 142,
              height: 104,
              child: Image.asset(
                'assets/images/Welcome_screen_games.webp',
                fit: BoxFit.contain,
              ),
            ),

            // 2) Головний заголовок
            Positioned(
              top: 155,
              left: screenWidth / 2 - 300 / 2,
              width: 300,
              child: const Text(
                'Find your perfect\ngaming squad',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
            ),

            // 3) Другорядний текст
            Positioned(
              top: 250,
              left: screenWidth / 2 - 212 / 2,
              width: 212,
              child: const Text(
                'Connect with players,\nanytime, anywhere',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 1.21,
                  color: Color(0xFFA3A3B5),
                ),
              ),
            ),

            // 4) Центральна ілюстрація
            Positioned(
              top: 310,
              left: screenWidth / 2 - 300 / 2,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/Welcome_screen_play_and_win.webp'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // 5) Нижня частина з гігантською кнопкою
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // КНОПКА-КАРТИНКА (+20% до попереднього, разом ~480px)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GameSelectionScreen()), // Змінили тут
                      );
                    },
                    child: SizedBox(
                      width: 480,
                      height: 110,
                      child: Image.asset(
                        'assets/images/Button_Get_Started.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'Already have an account?',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFFA3A3B5),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: () {
                      // Логіка Sign In
                    },
                    child: const Text(
                      'Sign in',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF00FFD1),
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        height: 0.85,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

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
            ),
          ],
        ),
      ),
    );
  }
}