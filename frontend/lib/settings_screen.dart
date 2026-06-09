import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';
import 'Game_Selection.dart';
import 'Language_Selection_screen.dart';
import 'Choose_your_playstyle.dart';
import 'Choose_your_platform.dart';

// Імпортуйте ваші реальні екрани (LoginScreen, EditProfileScreen, Game_Selection тощо)
// import 'login_screen.dart';
// import 'edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Метод для генерації аватара за вашим CSS
  Widget _buildAvatar(String nickname, String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00F5A0), width: 1),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Якщо картинки немає, рендеримо літеру за CSS (Love Light)
      String firstLetter = nickname.isNotEmpty ? nickname[0].toUpperCase() : '';
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF181826),
          shape: BoxShape.circle,
          boxShadow: [
            const BoxShadow(
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
              fontSize: 30,
              height: 27 / 30, // 0.9 відповідно до css line-height 27px при 30px size
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

    // Зразок змінних (замініть на реальні дані з вашого UserSession)
    final String currentNickname = 'gamer_nickname';
    final String? currentAvatarUrl = null; // наприклад, посилання на картинку з бекенду

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // ПРИБРАНО СТРІЛКУ НАЗАД З ВЕРХУ
        title: const Text(
          'Settings & Profile',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 0. Секція: Інформація профілю (Логін, пошта, аватар)
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
                    currentNickname, // Ваш логін з сесії
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'user_email@gmail.com', // Ваша пошта
                    style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 14, fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 1. Секція: Редагування профілю (Таби онбордингу + профіль сеттінг)
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
                  onTap: () {
                    // Перехід на екран зміни пошти, нікнейму чи паролю
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                  },
                ),
                const Divider(color: Color(0xFF2B2B3B), height: 1),
                ListTile(
                  leading: const Icon(Icons.games, color: accentColor),
                  title: const Text('Game Selection', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                  onTap: () {
                    // Перехід на екран вибору ігор
                  },
                ),
                const Divider(color: Color(0xFF2B2B3B), height: 1),
                ListTile(
                  leading: const Icon(Icons.devices, color: accentColor),
                  title: const Text('Platform Selection', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                  onTap: () {
                    // Перехід на екран платформ
                  },
                ),
                const Divider(color: Color(0xFF2B2B3B), height: 1),
                ListTile(
                  leading: const Icon(Icons.tune, color: accentColor),
                  title: const Text('Play Style', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                  onTap: () {
                    // Перехід на стиль гри та мови
                  },
                ),
                const Divider(color: Color(0xFF2B2B3B), height: 1),
                ListTile(
                  leading: const Icon(Icons.tune, color: accentColor),
                  title: const Text('Language Selection', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
                  onTap: () {
                    // Перехід на стиль гри та мови
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Секція: Рейтинг та статистика
          const SectionHeader(title: 'Stats & Reputation'),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text('My Global Rating', style: TextStyle(color: Colors.white)),
              trailing: Text('4.92 / 5.0', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
              subtitle: Text('Based on community evaluations', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 12)),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Історія (History)
          const SectionHeader(title: 'Activity Ledger'),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.history, color: accentColor),
              title: const Text('History (Matches & Notifications)', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
              onTap: () {
                // Перехід в історію, де логи не зникають, але їх можна видалити
              },
            ),
          ),
          const SizedBox(height: 20),

          // 4. Налаштування чатів та сповіщень
          const SectionHeader(title: 'App Preferences'),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: accentColor,
                  title: const Text('Desktop Match Alerts', style: TextStyle(color: Colors.white)),
                  value: true,
                  onChanged: (bool value) {},
                ),
                const Divider(color: Color(0xFF2B2B3B), height: 1),
                SwitchListTile(
                  activeColor: accentColor,
                  title: const Text('Chat Sounds', style: TextStyle(color: Colors.white)),
                  value: true,
                  onChanged: (bool value) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Підписка PRO
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
              onTap: () {
                // Екран PRO підписки
              },
            ),
          ),
          const SizedBox(height: 20),

          // 6. Аккаунт (Вихід та видалення)
          const SectionHeader(title: 'Account Management'),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF2B2B3B))),
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Log out', style: TextStyle(color: Colors.white)),
            onTap: () async {
              // РЕАЛЬНА ЛОГІКА ВИХОДУ (Очищення сесії та перенаправлення)
              // await UserSession.instance.logout();
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => const LoginScreen()),
              //   (route) => false,
              // );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFFFF4A4A).withOpacity(0.15),
            leading: const Icon(Icons.delete_forever, color: Color(0xFFFF4A4A)),
            title: const Text('Delete Account', style: TextStyle(color: Color(0xFFFF4A4A))),
            onTap: () {
              // Логіка видалення аккаунту
            },
          ),
        ],
      ),
    );
  }
}

// Допоміжний віджет заголовків секцій
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