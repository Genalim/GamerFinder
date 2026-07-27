import 'package:flutter/material.dart';
import 'sign_in_screen.dart';
import 'user_session.dart';
import 'edit_profile_setup_screen.dart';
import 'edit_game_selection_screen.dart';
import 'edit_language_selection_screen.dart';
import 'edit_play_style_screen.dart';
import 'edit_platform_selection_screen.dart';
import 'Home_Feed_screen.dart';
import 'custom_widgets.dart';
import 'edit_rating_screen.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'dart:convert';
import 'notification_history_screen.dart';
import 'subscription_screen.dart';
import 'services/settings_service.dart';
import 'profile_setup_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GamerProfile? _userProfile;
  bool _matchAlerts = true;
  bool _chatSound = true;

  void initState() {
    super.initState();
    _fetchAndLoadProfile(); // Оновлено: завантажуємо профіль з сервера при старті
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    bool matchAlerts = await SettingsService.isMatchAlertsEnabled();
    bool chatSound = await SettingsService.isChatSoundEnabled();
    setState(() {
      _matchAlerts = matchAlerts;
      _chatSound = chatSound;
    });
  }

  Future<void> _fetchAndLoadProfile() async {
    try {
      final userId = await UserSession.getUserId();
      final token = await UserSession.getToken();
      if (userId == null) {
        _loadProfileData();
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/users/$userId"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          UserSession().currentUser = GamerProfile.fromJson(data);
          _userProfile = UserSession().currentUser;
        });
      } else {
        _loadProfileData();
      }
    } catch (e) {
      debugPrint("Помилка завантаження профілю: $e");
      _loadProfileData();
    }
  }

  Future<void> _deleteAccount() async {
    final token = await UserSession.getToken();
    final userId = await UserSession.getUserId();

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/users/me'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        // 1. Очищаємо сесію
        await UserSession.logout();

        // 2. Перекидаємо на екран входу
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SignInScreen()),
                (route) => false,
          );
        }
      } else {
        // Помилка від сервера
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete account")),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // Оновлюємо профіль при кожному відкритті/фокусі на екрані
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfileData();
  }

  void _loadProfileData() {
    setState(() {
      _userProfile = UserSession().currentUser;
    });
  }

  void _loadUser() {
    setState(() {
      _userProfile = UserSession().currentUser;
    });
  }

  // Метод для генерації аватара
  Widget _buildAvatar(String nickname, String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final String fullAvatarUrl = imageUrl.startsWith('http')
          ? imageUrl
          : '${ApiConfig.baseUrl}${imageUrl.startsWith('/') ? imageUrl : '/$imageUrl'}';

      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00F5A0), width: 1),
          image: DecorationImage(
            image: NetworkImage(fullAvatarUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      String firstLetter = nickname.isNotEmpty ? nickname[0].toUpperCase() : '';
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF181826),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF00F5A0),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
          border: Border.all(color: const Color(0xFF00F5A0), width: 1),
        ),
        child: Center(
          child: Text(
            firstLetter,
            style: const TextStyle(
              fontFamily: 'Love Light',
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.w400,
              fontSize: 45,
              color: Color(0xFF00F5A0),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F0F13);
    const accentColor = Color(0xFF00F5A0);
    const cardColor = Color(0xFF181826);

    final user = _userProfile ?? UserSession().currentUser;
    final String currentNickname = user?.nickname ?? 'Gamer';
    final String? currentAvatarUrl = user?.avatar;
    final String currentEmail = user?.email ?? 'user_email@gmail.com';

    // Округлення рейтингу до 1 десятого знаку (наприклад 3.4 / 5.0)
    final double displayRating = (user?.rating?.toDouble() ?? 0.0);

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Settings & Profile',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SectionHeader(title: 'User Account Info'),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildAvatar(currentNickname, currentAvatarUrl),
                  const SizedBox(height: 12),
                  Text(
                    currentNickname,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentEmail,
                    style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 14, fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Profile Setup & Onboarding'),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: accentColor),
                  title: const Text('Profile Settings', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditProfileScreen()),
                    );
                    // Оновлюємо дані, коли користувач повертається назад на сеттінги
                    _loadProfileData();
                  },
                ),
                const Divider(color: Color(0xFF2B2B3B), height: 1),
                ListTile(
                  leading: const ProfileGamesIcon(),
                  title: const Text('Game Selection', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => const EditGameSelectionScreen()));
                  },
                ),
                const Divider(color: Color(0xFF2B2B3B), height: 1),
                ListTile(
                  leading: const ProfilePlatformsIcon(),
                  title: const Text('Platform Selection', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditPlatformSelectionScreen()),
                    );
                  },
                ),
                const Divider(color: Color(0xFF2B2B3B), height: 1),
                ListTile(
                  leading: const ProfilePlayStyleIcon(),
                  title: const Text('Play Style', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditPlayStyleScreen()),
                    );
                  },
                ),
                const Divider(color: Color(0xFF2B2B3B), height: 1),
                ListTile(
                  leading: const Icon(Icons.language, color: accentColor),
                  title: const Text('Language Selection', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditLanguageSelectionScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Stats & Reputation'),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const FigmaRatingStar(isFilled: true),
              title: const Text('My Global Rating', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Based on community evaluations', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Додано кастомну зірочку перед цифрою
                  const SizedBox(width: 6),
                  Text(
                    '${displayRating.toStringAsFixed(1)} / 5.0',
                    style: const TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditRatingScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Activity Ledger'),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.history, color: accentColor),
              title: const Text('History (Matches & Notifications)', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'App Preferences'),
          Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: accentColor,
                    title: const Text('Desktop Match Alerts', style: TextStyle(color: Colors.white)),
                    value: _matchAlerts, // <--- Змінено з true
                    onChanged: (bool value) async {
                      setState(() => _matchAlerts = value);
                      await SettingsService.setMatchAlertsEnabled(value); // <--- Збереження
                    },
                  ),
                  const Divider(color: Color(0xFF2B2B3B), height: 1),
                  SwitchListTile(
                    activeColor: accentColor,
                    title: const Text('Chat Sounds', style: TextStyle(color: Colors.white)),
                    value: _chatSound, // <--- Змінено з true
                    onChanged: (bool value) async {
                      setState(() => _chatSound = value);
                      await SettingsService.setChatSoundEnabled(value); // <--- Збереження
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Subscription'),
          Card(
            color: const Color(0xFF0066FF).withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF0066FF), width: 1),
            ),
            child: ListTile(
              leading: const Icon(Icons.workspace_premium, color: Colors.blueAccent),
              title: const Text('GamerFinder PRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Manage your premium status', style: TextStyle(color: Colors.white60)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
              onTap: () {Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
              );},
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Account Management'),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF2B2B3B))),
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Log out', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await UserSession.logout();

              // ДОДАЄМО СКИДАННЯ МЕНЕДЖЕРА РЕЄСТРАЦІЇ
              ProfileSetupManager.instance.reset();

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const SignInScreen()),
                    (route) => false,
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFFFF4A4A).withOpacity(0.15),
            leading: const Icon(Icons.delete_forever, color: Color(0xFFFF4A4A)),
            title: const Text('Delete Account', style: TextStyle(color: Color(0xFFFF4A4A))),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF181826),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure you want to delete your account? This action cannot be undone.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteAccount(); // Викликаємо функцію видалення
                      },
                      child: const Text('Delete', style: TextStyle(color: Color(0xFFFF4A4A))),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF8E8EA9),
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}