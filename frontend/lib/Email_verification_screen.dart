import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'sign_in_screen.dart';


class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  int _secondsRemaining = 45;
  bool _canResend = false;
  Timer? _timer;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startEmailVerificationPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
    _pollingTimer?.cancel();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 45;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  void _startEmailVerificationPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/auth/check-verification-status?email=${widget.email}'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final bool isVerified = data['is_verified'] ?? false;

          if (isVerified) {
            _pollingTimer?.cancel(); // Зупиняємо перевірку

            if (!mounted) return;

            // Показуємо приємне повідомлення успіху
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email verified successfully! Please sign in.', style: TextStyle(fontSize: 15)),
                backgroundColor: Color(0xFF00F5A0),
              ),
            );

            // Перекидаємо на екран Sign In, очищаючи історію навігації
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SignInScreen()),
                  (route) => false,
            );
          }
        }
      } catch (e) {
        print("Polling error: $e");
      }
    });
  }

  Future<void> _openEmailApp() async {
    final Uri emailLaunchUri = Uri(scheme: 'mailto');
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        _showNoEmailAppDialog();
      }
    } catch (e) {
      _showNoEmailAppDialog();
    }
  }

  void _showNoEmailAppDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
            'Check your inbox',
            style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 18)
        ),
        content: Text(
          'We couldn\'t open your email app automatically.\n\nPlease check your inbox manually at:\n${widget.email}',
          style: const TextStyle(color: Color(0xFFA3A3B5), fontFamily: 'Poppins', fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
                'Got it',
                style: TextStyle(color: Color(0xFF00F5A0), fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resendEmail() async {
    if (!_canResend) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/resend-verification'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": widget.email}),
      );

      if (response.statusCode == 200) {
        _startTimer();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification link resent successfully!', style: TextStyle(fontSize: 15)),
            backgroundColor: Color(0xFF00F5A0),
          ),
        );
      }
    } catch (e) {
      print("Error resending email: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar('Email Verification'),

                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 33),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Головний заголовок екрана
                          const Text(
                            'Verify your email',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 45),

                          // Блок інформації про відправку листа
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'We sent a verification link to:',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  height: 1.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 15),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.mail_outline,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 15),
                                  Text(
                                    widget.email,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 16,
                                      height: 1.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 45),

                          // --- ОБВЕДЕНИЙ БЛОК ---
                          // 1. Інструкція перевірки
                          const Text(
                            'Please check your inbox and click the link to activate your account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              fontSize: 17,
                              color: Color(0xFFA3A3B5),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 25),

                          // 2. Текстовий роздільник "or" (БЕЗ ПАЛОК, ВЕЛИКИЙ, БІЛИЙ)
                          const Text(
                            'or',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 25),

                          // 3. Кнопка "Open email app"
                          GestureDetector(
                            onTap: _openEmailApp,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Open email app',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                        height: 1.5,
                                        color: Color(0xFF00F5A0),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Transform.scale(
                                      scaleX: -1,
                                      child: const Icon(
                                        Icons.logout,
                                        color: Color(0xFF00F5A0),
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Підказка під кнопкою
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    '(Available if mail app is configured on this device)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 16,
                                      color: Color(0xFF8E8E9F),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // -------------------------------------------

                          const SizedBox(height: 50),

                          // Кнопка повторної відправки
                          GestureDetector(
                            onTap: _canResend ? _resendEmail : null,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _canResend ? 1.0 : 0.4,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _canResend
                                        ? 'Resend email'
                                        : 'Resend email (${_secondsRemaining}s)',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 20,
                                      height: 1.5,
                                      color: Color(0xFF00F5A0),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.refresh,
                                    color: Color(0xFF00F5A0),
                                    size: 17,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 45), // Відступ до дебаг-кнопки

                          // Кнопка "Try again" (якщо вказав не ту пошту)
                          GestureDetector(
                            onTap: () async {
                              // 1. Можемо додатково повідомити бекенд видалити цей непідтверджений профіль,
                              // щоб пошта одразу звільнилася
                              try {
                                await http.post(
                                  Uri.parse('${ApiConfig.baseUrl}/auth/cancel-registration'),
                                  headers: {"Content-Type": "application/json"},
                                  body: json.encode({"email": widget.email}),
                                );
                              } catch (e) {
                                print("Error clearing unverified user: $e");
                              }

                              // 2. Повертаємось на екран налаштування профілю
                              if (!mounted) return;
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Try again',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: Color(0xFF6F6F80),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 48), // Просто відступ замість кнопки назад, щоб заголовок був ідеально по центру
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}