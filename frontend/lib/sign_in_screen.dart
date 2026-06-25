import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Home_Feed_screen.dart';
import 'user_session.dart';
import 'Main_navigation.dart';
import 'api_config.dart';
import 'package:http/http.dart' as http;

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _errorMessage = '';
  bool _isLoading = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _nicknameController.text.isNotEmpty && _passwordController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "nickname": _nicknameController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      print("Статус відповіді: ${response.statusCode}");
      print("Тіло відповіді: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final userId = data['id'];
        // ПРИПУСКАЮ, що токен приходить у полі 'access_token' або 'token'
        // Перевірте логи в консолі, щоб дізнатися точне ім'я поля!
        final token = data['access_token'];

        if (userId == null) {
          throw Exception("ID юзера відсутній");
        }

        // Зберігаємо ID
        await UserSession.saveUserId(userId);

        // ВАЖЛИВО: Зберігаємо токен!
        if (token != null) {
          UserSession.setToken(token);
          print("Токен успішно збережено в UserSession");
        }

        if (mounted) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainNavigationScreen())
          );
        }
      }else {
        setState(() => _errorMessage = 'Невірний нік або пароль (код: ${response.statusCode})');
      }
    } catch (e) {
      print("ПОМИЛКА: $e");
      setState(() => _errorMessage = 'Сталася помилка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    // Виносимо змінну стану сюди, щоб вона не скидалася при кожному оновленні діалогу
    bool isValid = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF181826),
            title: const Text('Reset Password', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: emailController,
              onChanged: (value) {
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                final bool isNowValid = emailRegex.hasMatch(value);

                if (isValid != isNowValid) {
                  setStateDialog(() {
                    isValid = isNowValid;
                  });
                }
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'example@mail.com',
                hintStyle: const TextStyle(color: Color(0xFF4A4A6A)),
                filled: true,
                fillColor: const Color(0xFF0F0F1A),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00F5A0), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00F5A0), width: 2),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B),
                ),
                onPressed: isValid ? () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset link sent!')));
                } : null,
                child: Text(
                  'Send',
                  style: TextStyle(color: isValid ? Colors.black : Colors.white60),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(),
              const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(controller: _nicknameController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Nickname')),
                    const SizedBox(height: 16),
                    TextFormField(controller: _passwordController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Password')),
                  ],
                ),
              ),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _showForgotPasswordDialog(context), child: const Text('Forgot your password?', style: TextStyle(color: Color(0xFF00F5A0))))),
              if (_errorMessage.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isFormValid && !_isLoading ? _handleSignIn : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _isFormValid ? const Color(0xFF00F5A0) : const Color(0xFF2B2B3B)),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : Text('Sign In', style: TextStyle(color: _isFormValid ? Colors.black : Colors.white60, fontSize: 18,)),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    hintText: label,
    hintStyle: const TextStyle(color: Color(0xFF8E8EA9)),
    filled: true,
    fillColor: const Color(0xFF181826),
    border: InputBorder.none, // Прибирає рамку зовсім
  );
}