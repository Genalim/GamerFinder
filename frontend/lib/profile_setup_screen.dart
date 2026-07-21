import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'custom_widgets.dart';
import 'package:flutter/services.dart';
import 'Email_verification_screen.dart';
import 'profile_setup_manager.dart'; // 1. ІМПОРТУЄМО МЕНЕДЖЕР СТАНУ
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'dart:convert';
import 'api_config.dart';
import 'user_session.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  bool _isLoading = false;
  bool _isNicknameValid = true;
  String? _nicknameError;

  Future<void> _handleFinish() async {
    setState(() => _isLoading = true);
    // 1. Спочатку визначаємо, що ми вантажимо: своє фото чи стандартне
    String? avatarUrl = _selectedAvatarPath; // якщо це шлях з ассетів

    if (_imageFile != null) {
      // Юзер обрав своє фото, вантажимо його на сервер
      avatarUrl = await _uploadAvatarToServer(_imageFile!.path);
    }

    // 2. Фіксуємо дані в менеджері
    _manager.nickname = _nicknameController.text;
    _manager.email = _emailController.text;
    _manager.password = _passwordController.text;
    _manager.selectedAvatarPath = avatarUrl; // Зберігаємо отриманий URL або старий шлях

    _platformControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        _manager.connectedAccounts[key] = controller.text;
      }
    });

    // 3. Відправляємо на бекенд
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register'),
        headers: {"Content-Type": "application/json"},
        body: _manager.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(email: _emailController.text),
            ),
          );
        }
      }
    } catch (e) {
      print("Помилка реєстрації: $e");
    }
    setState(() => _isLoading = false);
  }

  //====  Перевырка чи э нікнейм вже ===
  Future<void> _checkNicknameAvailability(String nickname) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/check-nickname/$nickname'),
      );

      if (response.statusCode == 200) {
        final exists = json.decode(response.body)['exists'];
        setState(() {
          if (exists) {
            _nickMsg = "Nickname already taken";
            _nickColor = const Color(0xFFFF3B5C);
            _nickValid = false;
          } else {
            _nickMsg = "Nickname is available";
            _nickColor = const Color(0xFF00F5A0);
            _nickValid = true;
          }
        });
      }
    } catch (e) {
      print("Помилка при перевірці: $e");
    }
  }


// Твій допоміжний метод для завантаження
  Future<String?> _uploadAvatarToServer(String filePath) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/upload-avatar'));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      var res = await request.send();

      if (res.statusCode == 200) {
        var responseData = await res.stream.bytesToString();
        return json.decode(responseData)['url'];
      }
    } catch (e) {
      print("Помилка завантаження: $e");
    }
    return null;
  }

  // === 2. ПІДКЛЮЧАЄМО ЄДИНИЙ МЕНЕДЖЕР ===
  final _manager = ProfileSetupManager.instance;

  List<String> _freeAvatars = [];
  List<String> _proAvatars = [];
  bool _isLoadingAssets = true;
  Timer? _nickDebounce;
  Timer? _emailDebounce;

  // Контролери робимо late, щоб заповнити їх в initState з менеджера
  late TextEditingController _nicknameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  final Map<String, TextEditingController> _platformControllers = {
    'Discord': TextEditingController(),
    'TeamSpeak': TextEditingController(),
    'Mumble': TextEditingController(),
    'Guilded': TextEditingController(),
    'Steam chat': TextEditingController(),
  };

  String _activeField = "";
  bool _nickValid = false,
      _emailValid = false,
      _passValid = false,
      _obscurePassword = true;

  // Логіка аватарок
  String? _selectedAvatarPath;
  File? _imageFile;
  bool _isFreeTab = true;
  final ImagePicker _picker = ImagePicker();

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
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _platformControllers.forEach((key, controller) => controller.dispose());
    _nickDebounce?.cancel(); // Це зупинить таймер при закритті екрана
    _emailDebounce?.cancel();
    super.dispose();
  }

  // === 3. ПІДТЯГУЄМО ДАНІ, ЯКЩО КОРИСТУВАЧ ПОВЕРНУВСЯ ===
  @override
  void initState() {
    super.initState();
    _loadAvatarAssets();

    // Заповнюємо поля тим, що збережено в менеджері (якщо там пусто — буде просто порожній рядок)
    _nicknameController = TextEditingController(text: _manager.nickname);
    _emailController = TextEditingController(text: _manager.email);
    _passwordController = TextEditingController(text: _manager.password);
    _selectedAvatarPath = _manager.selectedAvatarPath;

    // Якщо користувач повернувся і поля вже були заповнені — запускаємо валідацію, щоб увімкнути кнопку
    if (_nicknameController.text.isNotEmpty) _validateNick(
        _nicknameController.text);
    if (_emailController.text.isNotEmpty) _validateEmail(_emailController.text);
    if (_passwordController.text.isNotEmpty) _validatePass(
        _passwordController.text);

    for (var p in _platformControllers.keys) {
      _pMsgs[p] = _getInitialHint(p);
      _pColors[p] = const Color(0xFF6F6F80);
      _pValid[p] = false;
    }

  }

  Future<void> _loadAvatarAssets() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/avatars-list'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> freeList = data['free'] ?? [];
        final List<dynamic> proList = data['pro'] ?? [];

        if (mounted) {
          setState(() {
            _freeAvatars = freeList.map((e) => e.toString()).toList();
            _proAvatars = proList.map((e) => e.toString()).toList();
            _isLoadingAssets = false;
          });

          // Кешуємо мережеві картинки для плавності
          for (var url in _freeAvatars) {
            precacheImage(NetworkImage(url), context);
          }
          for (var url in _proAvatars) {
            precacheImage(NetworkImage(url), context);
          }
        }
      }
    } catch (e) {
      print("Error loading avatars from server: $e");
    }
  }

  String _getInitialHint(String p) {
    if (p == 'Discord') return "Format: Username#1234";
    if (p == 'Guilded') return "Format: username#123";
    if (p == 'Steam chat') return "Use Steam username or numeric SteamID64";
    return "3–20 characters, letters, numbers, . or _";
  }

  bool get _isFormReady => _nickValid && _emailValid && _passValid;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      // 1. Одразу після вибору запускаємо кропер
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Робимо квадрат
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Avatar',
            toolbarColor: const Color(0xFF0F0F1A),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFF00F5A0),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          // 2. Тепер зберігаємо шлях до вже обрізаного файлу
          _imageFile = File(croppedFile.path);
          _selectedAvatarPath = null; // Стандартну аватарку скидаємо
        });
        Navigator.pop(context); // Закриваємо модалку після вибору
      }
    }
  }

  Future<void> _validateNick(String v) async {
    final reg = RegExp(r'^[a-zA-Z0-9_.]+$');

    if (_nickDebounce?.isActive ?? false) _nickDebounce!.cancel();

    // 1. Спочатку скидаємо валідність
    setState(() {
      _nickValid = false; // ПРИМУСОВО СКИНУЛИ
    });

    // 2. Локальні перевірки
    if (v.isEmpty) {
      setState(() {
        _nickMsg = "3–20 characters, letters, numbers, . or _ only";
        _nickColor = const Color(0xFF6F6F80);
      });
      return;
    }

    if (v.length < 3 || v.length > 20) {
      setState(() {
        _nickMsg = "Nickname must be 3–20 characters";
        _nickColor = const Color(0xFFFF3B5C);
      });
      return;
    }

    if (!reg.hasMatch(v)) {
      setState(() {
        _nickMsg = "Only letters, numbers, . or _ allowed";
        _nickColor = const Color(0xFFFF3B5C);
      });
      return;
    }

    // 3. Якщо локально все ОК, тоді перевіряємо сервер
    setState(() {
      _nickMsg = "Checking availability...";
      _nickColor = Colors.white70;
    });

    _nickDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _checkNicknameAvailability(v);
    });
  }

  Future<void> _checkEmailAvailability(String email) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/check-email/$email'),
      );

      if (response.statusCode == 200) {
        final exists = json.decode(response.body)['exists'];
        if (mounted) {
          setState(() {
            if (exists) {
              _emailMsg = "Email already registered";
              _emailColor = const Color(0xFFFF3B5C);
              _emailValid = false;
            } else {
              _emailMsg = "Email is available";
              _emailColor = const Color(0xFF00F5A0);
              _emailValid = true;
            }
          });
        }
      }
    } catch (e) {
      print("Помилка перевірки пошти: $e");
    }
  }

  void _validateEmail(String v) {
    final reg = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (_emailDebounce?.isActive ?? false) _emailDebounce!.cancel();

    setState(() {
      _emailValid = false; // Поки перевіряємо — форма не готова
      if (v.isEmpty) {
        _emailMsg = "Enter a valid email (e.g. user@example.com)";
        _emailColor = const Color(0xFF6F6F80);
      } else if (!reg.hasMatch(v)) {
        _emailMsg = "Invalid email format";
        _emailColor = const Color(0xFFFF3B5C);
      } else {
        _emailMsg = "Checking availability...";
        _emailColor = Colors.white70;

        _emailDebounce = Timer(const Duration(milliseconds: 500), () {
          _checkEmailAvailability(v);
        });
      }
    });
  }

  void _validatePass(String v) {
    setState(() {
      if (v.isEmpty) {
        _passMsg = "6–30 characters, no spaces";
        _passColor = const Color(0xFF6F6F80);
        _passValid = false;
      } else if (v.contains(' ')) {
        _passMsg = "Spaces are not allowed";
        _passColor = const Color(0xFFFF3B5C);
        _passValid = false;
      } else if (v.length < 6 || v.length > 30) {
        _passMsg = "Password must be 6–30 characters";
        _passColor = const Color(0xFFFF3B5C);
        _passValid = false;
      } else {
        _passMsg = "Password looks good";
        _passColor = const Color(0xFF00F5A0);
        _passValid = true;
      }
    });
  }

  void _validatePlatform(String p, String v) {
    setState(() {
      bool isValid = false;
      String error = "";
      if (v.isEmpty) {
        _pMsgs[p] = _getInitialHint(p);
        _pColors[p] = const Color(0xFF6F6F80);
        _pValid[p] = false;
        return;
      }
      if (p == 'Discord') {
        isValid = RegExp(r'^.{2,32}#[0-9]{4}$').hasMatch(v);
        error = "Format: Name#1234 (4 digits)";
      } else if (p == 'Guilded') {
        isValid = RegExp(r'^.{3,32}#[0-9]{3}$').hasMatch(v);
        error = "Format: Name#123 (3 digits)";
      } else if (p == 'Steam chat') {
        if (RegExp(r'^[0-9]+$').hasMatch(v)) {
          isValid = v.length == 17;
          error = "SteamID64 must be 17 digits";
        } else {
          isValid = v.length >= 3 && v.length <= 32;
          error = "Username must be 3–32 characters";
        }
      } else {
        isValid = RegExp(r'^[a-zA-Z0-9_.]{3,20}$').hasMatch(v);
        if (v.contains(' '))
          error = "Spaces not allowed";
        else
          error = "3–20 chars, letters, numbers, . or _";
      }
      _pMsgs[p] = isValid ? "$p looks good" : error;
      _pColors[p] = isValid ? const Color(0xFF00F5A0) : const Color(0xFFFF3B5C);
      _pValid[p] = isValid;
    });
  }

  void _showAvatarPicker() {
    String? tempPath = _selectedAvatarPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<String> currentAvatars = _isFreeTab
                ? _freeAvatars
                : _proAvatars;

            return Container(
              height: MediaQuery
                  .of(context)
                  .size
                  .height * 0.8,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildTabItem('FREE', _isFreeTab, () =>
                            setModalState(() => _isFreeTab = true)),
                        const SizedBox(width: 10),
                        _buildTabItem('PRO', !_isFreeTab, () =>
                            setModalState(() => _isFreeTab = false)),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                              Icons.close, color: Colors.white54, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Choose your avatar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161622),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(
                            0.05)),
                      ),
                      child: _isLoadingAssets
                          ? const Center(child: CircularProgressIndicator(
                          color: Color(0xFF00F5A0)))
                          : Stack(
                        children: [
                          GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 15,
                              crossAxisSpacing: 15,
                            ),
                            itemCount: currentAvatars.length,
                            itemBuilder: (context, index) {
                              String path = currentAvatars[index];
                              final String fullAvatarUrl = path.startsWith('http') ? path : '${ApiConfig.baseUrl}$path';
                              bool isSelected = tempPath == path;

                              return GestureDetector(
                                onTap: () {
                                  // Якщо це вкладка PRO, перевіряємо чи юзер має PRO (можеш підставити свою перевірку)
                                  bool isUserPro = UserSession().currentUser?.isPro ?? false;
                                  if (!_isFreeTab && !isUserPro) {
                                    // Якщо немає PRO — нічого не робимо (або показуємо сповіщення)
                                    return;
                                  }
                                  setModalState(() => tempPath = path);
                                },
                                child: RepaintBoundary(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? const Color(
                                            0xFF00F5A0) : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Stack(
                                        children: [
                                          Image.network(
                                            fullAvatarUrl,
                                            fit: BoxFit.cover,
                                            width: 100,
                                            height: 100,
                                            filterQuality: FilterQuality.low,
                                            errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.error, color: Colors.red),
                                          ),
                                          if (!_isFreeTab) ...[
                                            Container(
                                                color: Colors.black.withOpacity(
                                                    0.6)),
                                            const Center(
                                              child: Icon(
                                                Icons.lock_outline,
                                                color: Colors.white24,
                                                size: 22,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (!_isFreeTab)
                            Positioned(
                              bottom: 185,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  color: Colors.transparent,
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: const TextSpan(
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                      children: [
                                        TextSpan(
                                            text: 'Unlock with GameBuddy PRO in '),
                                        TextSpan(
                                          text: 'Settings',
                                          style: TextStyle(
                                            color: Color(0xFF00F5A0),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '\nafter registration', // Перенесення перед after, далі такий самий білий стиль
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    child: NeonGameButton(
                      isActive: tempPath != null,
                      onTap: () {
                        if (tempPath != null) {
                          setState(() {
                            _selectedAvatarPath = tempPath;
                            _imageFile = null;
                          });
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabItem(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF181826) : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: isActive ? Border.all(
              color: const Color(0xFF00F5A0), width: 1) : null,
        ),
        child: Text(label, style: TextStyle(
            color: isActive ? const Color(0xFF00F5A0) : Colors.white38,
            fontWeight: FontWeight.bold,
            fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery
        .of(context)
        .viewInsets
        .bottom > 0;

    // ОНОВЛЕНО: Додаємо PopScope, щоб ловити системні жести "Назад" (свайпи та кнопки телефона)
    return PopScope(
      canPop: true, // Дозволяємо вихід з екрана
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Що б користувач не натиснув для виходу назад — зберігаємо його тексти в пам'ять
          _manager.nickname = _nicknameController.text;
          _manager.email = _emailController.text;
          _manager.password = _passwordController.text;
          _manager.selectedAvatarPath = _selectedAvatarPath;
        }
      },
      child: GestureDetector(
        onTap: () {
          setState(() => _activeField = "");
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F13),
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildAppBar('Profile Setup'),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                            33, 0, 33, isKeyboardOpen ? 20 : 120),
                        child: Column(
                          children: [
                            const SizedBox(height: 30),
                            _buildAvatarBlock(),
                            const SizedBox(height: 40),
                            _buildMainField(
                                _nicknameController,
                                'Enter your nickname',
                                'nick',
                                _nickMsg,
                                _nickColor,
                                _nickValid,
                                _validateNick,
                                145),
                            const SizedBox(height: 10),
                            _buildMainField(
                                _emailController,
                                'Enter your email',
                                'email',
                                _emailMsg,
                                _emailColor,
                                _emailValid,
                                _validateEmail,
                                145),
                            const SizedBox(height: 10),
                            _buildMainField(
                                _passwordController,
                                'Create a password',
                                'pass',
                                _passMsg,
                                _passColor,
                                _passValid,
                                _validatePass,
                                145,
                                isPass: true),
                            const SizedBox(height: 30),
                            const Text('Connected Platforms (optional)',
                                style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 16,
                                    color: Colors.white)),
                            const SizedBox(height: 15),
                            ..._platformControllers.keys.map((p) =>
                                _buildPlatformBlock(p)).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isKeyboardOpen)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      alignment: Alignment.center,
                      color: const Color(0xFF0F0F13),
                      child: _buildFinishButton(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
                Icons.arrow_back_ios_new, color: Colors.white, size: 24),
            // ОНОВЛЕНО ТУТ: При натисканні "Назад" страхуємо поточний текст користувача
            onPressed: () {
              _manager.nickname = _nicknameController.text;
              _manager.email = _emailController.text;
              _manager.password = _passwordController.text;
              _manager.selectedAvatarPath = _selectedAvatarPath;
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins'),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAvatarBlock() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickImage(ImageSource.camera),
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF181826),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00F5A0), width: 1),
              image: _imageFile != null
                  ? DecorationImage(
                image: FileImage(_imageFile!),
                fit: BoxFit.cover,
              )
                  : (_selectedAvatarPath != null
                  ? DecorationImage(
                image: NetworkImage(
                  _selectedAvatarPath!.startsWith('http')
                      ? _selectedAvatarPath!
                      : '${ApiConfig.baseUrl}${_selectedAvatarPath!.startsWith('/') ? _selectedAvatarPath! : '/$_selectedAvatarPath'}',
                ),
                fit: BoxFit.cover,
              )
                  : null),
            ),
            child: (_imageFile == null && _selectedAvatarPath == null)
                ? const Center(
                child: Icon(Icons.camera, size: 50, color: Color(0xFF00F5A0)))
                : null,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 80),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Take a photo or', style: TextStyle(
                    color: Color(0xFF6F6F80),
                    fontSize: 10,
                    fontFamily: 'Poppins')),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: const Text('Upload Avatar', style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      decoration: TextDecoration.underline)),
                ),
              ],
            ),
            GestureDetector(
              onTap: _showAvatarPicker,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text('Game Buddy', style: TextStyle(color: Color(0xFF00F5A0),
                      fontSize: 10,
                      fontFamily: 'Poppins')),
                  Text('Avatars', style: TextStyle(color: Color(0xFF00F5A0),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins')),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainField(TextEditingController ctrl, String h, String id,
      String m, Color c, bool v, Function(String) onCh, double w,
      {bool isPass = false}) {
    bool active = _activeField == id;
    return Column(children: [
      Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFF181826),
            borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: ctrl,
          onChanged: onCh,
          onTap: () {
            setState(() => _activeField = id);
            onCh(ctrl.text);
          },
          obscureText: isPass ? _obscurePassword : false,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          cursorColor: const Color(0xFF00F5A0),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: h,
            hintStyle: const TextStyle(color: Color(0xFF6F6F80)),
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            isDense: true,
            prefixIcon: isPass
                ? const Opacity(
                opacity: 0, child: Icon(Icons.visibility, size: 20))
                : null,
            suffixIcon: isPass ? IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF6F6F80), size: 20),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ) : null,
          ),
        ),
      ),
      if (active) _buildValidationRow(m, c, w, v),
    ]);
  }

  Widget _buildPlatformBlock(String p) {
    bool active = _activeField == p;
    return Column(children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Container(width: 101,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF181826),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
                p, style: const TextStyle(color: Colors.white, fontSize: 13))),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF181826),
                borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _platformControllers[p],
              onChanged: (v) => _validatePlatform(p, v),
              onTap: () {
                setState(() => _activeField = p);
                _validatePlatform(p, _platformControllers[p]!.text);
              },
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Enter ID',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF6F6F80)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ),
      ])),
      if (active) _buildValidationRow(
          _pMsgs[p] ?? "", _pColors[p] ?? Colors.grey, 155,
          _pValid[p] ?? false),
    ]);
  }

  Widget _buildValidationRow(String m, Color c, double w, bool v) {
    return Padding(padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(children: [
          Expanded(child: Center(child: SizedBox(width: w,
              child: Text(m, textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 10,
                      color: c,
                      height: 1.2))))),
          Container(width: 156,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFF181826),
                  borderRadius: BorderRadius.circular(12),
                  border: v
                      ? Border.all(color: const Color(0xFF00F5A0))
                      : null),
              child: Center(child: Text('Save', style: TextStyle(
                  color: v ? Colors.white : const Color(0xFF6F6F80),
                  fontSize: 14)))),
        ]));
  }

  Widget _buildFinishButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeonFinishButton(
        isActive: _isFormReady,
        onTap: () async {
          if (!_isFormReady) return;

          // Показуємо лоадер, якщо треба (опціонально)
          await _handleFinish();
        },
      ),
    );
  }
}