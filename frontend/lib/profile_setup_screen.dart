import 'package:flutter/material.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final Map<String, TextEditingController> _platformControllers = {
    'Discord': TextEditingController(),
    'TeamSpeak': TextEditingController(),
    'Mumble': TextEditingController(),
    'Guilded': TextEditingController(),
    'Steam chat': TextEditingController(),
  };

  String _activeField = "";
  bool _nickValid = false, _emailValid = false, _passValid = false, _obscurePassword = true;

  String _nickMsg = "3–20 characters, letters, numbers, . or _ only";
  Color _nickColor = const Color(0xFF6F6F80);
  String _emailMsg = "Enter a valid email (e.g. user@example.com)";
  Color _emailColor = const Color(0xFF6F6F80);
  String _passMsg = "6–30 characters, no spaces";
  Color _passColor = const Color(0xFF6F6F80);

  final Map<String, String> _pMsgs = {};
  final Map<String, Color> _pColors = {};
  final Map<String, bool> _pValid = {};

  @override
  void initState() {
    super.initState();
    for (var p in _platformControllers.keys) {
      _pMsgs[p] = _getInitialHint(p);
      _pColors[p] = const Color(0xFF6F6F80);
      _pValid[p] = false;
    }
  }

  String _getInitialHint(String p) {
    if (p == 'Discord') return "Format: Username#1234";
    if (p == 'Guilded') return "Format: username#123";
    if (p == 'Steam chat') return "Use Steam username or numeric SteamID64";
    return "3–20 characters, letters, numbers, . or _";
  }

  bool get _isFormReady => _nickValid && _emailValid && _passValid;

  void _validateNick(String v) {
    setState(() {
      final reg = RegExp(r'^[a-zA-Z0-9_.]+$');
      if (v.isEmpty) { _nickMsg = "3–20 characters, letters, numbers, . or _ only"; _nickColor = const Color(0xFF6F6F80); _nickValid = false; }
      else if (!reg.hasMatch(v) || v.length < 3 || v.length > 20) { _nickMsg = "Invalid format or length"; _nickColor = const Color(0xFFFF3B5C); _nickValid = false; }
      else { _nickMsg = "Nickname is available"; _nickColor = const Color(0xFF00F5A0); _nickValid = true; }
    });
  }

  void _validateEmail(String v) {
    setState(() {
      final reg = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (v.isEmpty || !reg.hasMatch(v) || v.length < 5) { _emailMsg = "Please enter a valid email address"; _emailColor = const Color(0xFFFF3B5C); _emailValid = false; }
      else { _emailMsg = "Email looks good"; _emailColor = const Color(0xFF00F5A0); _emailValid = true; }
    });
  }

  void _validatePass(String v) {
    setState(() {
      if (v.isEmpty || v.contains(' ') || v.length < 6 || v.length > 20) { _passMsg = "Password must be 6–20 characters"; _passColor = const Color(0xFFFF3B5C); _passValid = false; }
      else { _passMsg = "Password looks good"; _passColor = const Color(0xFF00F5A0); _passValid = true; }
    });
  }

  void _validatePlatform(String p, String v) {
    setState(() {
      bool isValid = false;
      if (v.isEmpty) { _pMsgs[p] = _getInitialHint(p); _pColors[p] = const Color(0xFF6F6F80); }
      else {
        if (p == 'Discord') isValid = RegExp(r'^.{2,32}#[0-9]{4}$').hasMatch(v);
        else if (p == 'Guilded') isValid = RegExp(r'^.{3,32}#[0-9]{3}$').hasMatch(v);
        else if (p == 'Steam chat') isValid = RegExp(r'^[0-9]{17}$').hasMatch(v) || RegExp(r'^[a-zA-Z0-9_.]{3,32}$').hasMatch(v);
        else isValid = RegExp(r'^[a-zA-Z0-9_.]{3,20}$').hasMatch(v);
        _pMsgs[p] = isValid ? "$p looks good" : "Invalid format";
        _pColors[p] = isValid ? const Color(0xFF00F5A0) : const Color(0xFFFF3B5C);
      }
      _pValid[p] = isValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { setState(() => _activeField = ""); FocusScope.of(context).unfocus(); },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F13),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 33),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Text('Profile Setup', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 30),

                      _buildAvatarBlock(),

                      const SizedBox(height: 40),
                      _buildMainField(_nicknameController, 'Enter your nickname', 'nick', _nickMsg, _nickColor, _nickValid, _validateNick, 125),
                      const SizedBox(height: 10),
                      _buildMainField(_emailController, 'Enter your email', 'email', _emailMsg, _emailColor, _emailValid, _validateEmail, 132),
                      const SizedBox(height: 10),
                      _buildMainField(_passwordController, 'Create a password', 'pass', _passMsg, _passColor, _passValid, _validatePass, 128, isPass: true),
                      const SizedBox(height: 30),
                      const Text('Connected Platforms (optional)', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, color: Colors.white)),
                      const SizedBox(height: 15),
                      ..._platformControllers.keys.map((p) => _buildPlatformBlock(p)).toList(),
                    ],
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 33, vertical: 20), child: _buildFinishButton()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarBlock() {
    return Column(
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(color: const Color(0xFF181826), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF00F5A0), width: 1)),
          child: const Center(child: Icon(Icons.camera, size: 50, color: Color(0xFF00F5A0))),
        ),
        const SizedBox(height: 15),
        // Використовуємо Stack, щоб текст був ЧІТКО по центру іконки
        Stack(
          alignment: Alignment.topCenter,
          children: [
            // Текст суворо по центру
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Take a photo or', style: TextStyle(color: Color(0xFF6F6F80), fontSize: 10, fontFamily: 'Poppins')),
                const SizedBox(height: 4),
                const Text('Upload Avatar', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins', decoration: TextDecoration.underline)),
              ],
            ),
            // Game Buddy праворуч
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text('Game Buddy', style: TextStyle(color: Color(0xFF00F5A0), fontSize: 10, fontFamily: 'Poppins')),
                  Text('Avatars', style: TextStyle(color: Color(0xFF00F5A0), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainField(TextEditingController ctrl, String h, String id, String m, Color c, bool v, Function(String) onCh, double w, {bool isPass = false}) {
    bool active = _activeField == id;
    return Column(children: [
      Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12)), child: TextField(controller: ctrl, onChanged: onCh, onTap: () => setState(() => _activeField = id), obscureText: isPass ? _obscurePassword : false, textAlignVertical: TextAlignVertical.center, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: h, hintStyle: const TextStyle(color: Color(0xFF6F6F80)), contentPadding: const EdgeInsets.symmetric(horizontal: 20), isCollapsed: true, border: InputBorder.none, suffixIcon: isPass ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: _obscurePassword ? const Color(0xFF6F6F80) : const Color(0xFF00F5A0), size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null))),
      if (active) _buildValidationRow(m, c, w, v),
    ]);
  }

  Widget _buildPlatformBlock(String p) {
    bool active = _activeField == p;
    return Column(children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Container(width: 101, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12)), child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 13))),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12)), child: TextField(controller: _platformControllers[p], onChanged: (v) => _validatePlatform(p, v), onTap: () => setState(() => _activeField = p), textAlignVertical: TextAlignVertical.center, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: const InputDecoration(hintText: 'Enter ID', hintStyle: TextStyle(fontSize: 12, color: Color(0xFF6F6F80)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15), isCollapsed: true)))),
      ])),
      if (active) _buildValidationRow(_pMsgs[p] ?? "", _pColors[p] ?? Colors.grey, 135, _pValid[p] ?? false),
    ]);
  }

  Widget _buildValidationRow(String m, Color c, double w, bool v) {
    return Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Row(children: [
      Expanded(child: Center(child: SizedBox(width: w, child: Text(m, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: c, height: 1.2))))),
      Container(width: 156, height: 44, decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12), border: v ? Border.all(color: const Color(0xFF00F5A0)) : null), child: Center(child: Text('Save', style: TextStyle(color: v ? Colors.white : const Color(0xFF6F6F80), fontSize: 14)))),
    ]));
  }

  Widget _buildFinishButton() {
    return Container(width: double.infinity, height: 55, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: _isFormReady ? const LinearGradient(colors: [Color(0xFF00D1FF), Color(0xFF00F5A0)]) : null, color: _isFormReady ? null : const Color(0xFF2B2B3B), boxShadow: _isFormReady ? [const BoxShadow(color: Color.fromRGBO(0, 255, 209, 0.45), blurRadius: 22)] : []), child: Center(child: Text('Finish setup', style: TextStyle(color: _isFormReady ? const Color(0xFF0F0F1A) : const Color(0xFF6B6B80), fontSize: 16, fontWeight: FontWeight.w700))));
  }
}
