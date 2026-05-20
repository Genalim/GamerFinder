import 'package:flutter/material.dart';
import 'Home_Feed_screen.dart'; // Імпорт моделі GamerProfile
import 'custom_widgets.dart';    // Твої реальні FigmaRatingStar та FigmaArrowIcon
import 'package:auto_size_text/auto_size_text.dart';

class GamerProfileScreen extends StatelessWidget {
  final GamerProfile profile;
  const GamerProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00F5A0);
    const cardBg = Color(0xFF181826);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Gamer Profile',
          style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ХЕДЕР: Аватарка, Статуси, Нікнейм та Кнопка Add Friend
            _buildHeader(accentColor),
            const SizedBox(height: 24),

            // 2. СПИСОК ІГОР (Games List)
            _buildSectionTitle('Games List:', child: const ProfileGamesIcon()),
            const SizedBox(height: 12),
            _buildGamesGrid(cardBg),
            const SizedBox(height: 24),

            // 3. ПЛАТФОРМИ (Platforms)
            _buildSectionTitle('Platforms:', child: const ProfilePlatformsIcon()),
            const SizedBox(height: 12),
            _buildPlatformsRow(cardBg),
            const SizedBox(height: 24),

            // 4. СТИЛЬ ГРИ (Play style)
            _buildSectionTitle('Play style:', child: const ProfilePlayStyleIcon()),
            const SizedBox(height: 12),
            _buildPlayStyleRow(cardBg),
            const SizedBox(height: 24),

            // 5. ПІДКЛЮЧЕНІ ПЛАТФОРМИ (Connected Platforms)
            _buildSectionTitle('Connected Platforms:', child: const ProfileConnectedIcon()),
            const SizedBox(height: 12),
            _buildConnectedPlatforms(cardBg),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // Закріплюємо кнопки жорстко внизу екрана
      bottomNavigationBar: Container(
        color: const Color(0xFF0F0F13),
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 12),
        child: _buildActionButtons(accentColor),
      ),
    );
  }

  // МЕТОД 1: Хедер профілю (Вирівняно Add Friend, назви мов/часу білі)
  Widget _buildHeader(Color accentColor) {
    final Color statusColor = profile.isOnline ? accentColor : const Color(0xFF8E8EA9);

    final String langsText = (profile.languages.isNotEmpty)
        ? profile.languages.join(' • ')
        : 'Not specified';

    final String playTimeText = profile.playTime.isNotEmpty
        ? profile.playTime
        : 'Evening • Late night';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Аватарка
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF181826),
            border: Border.all(color: statusColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 0,
              )
            ],
          ),
          child: Center(
            child: Text(
              profile.nickname.isNotEmpty ? profile.nickname[0].toUpperCase() : 'G',
              style: TextStyle(
                  fontFamily: 'Love Light',
                  fontSize: 50,
                  color: statusColor
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),

        // Інфо-блок праворуч
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Нікнейм + PRO badge + Зірочка
              Row(
                children: [
                  Expanded(
                    child: AutoSizeText(
                      profile.nickname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      minFontSize: 13, // Менше ніж до 13 шрифт не опуститься
                      stepGranularity: 1, // Зменшувати по 1 пікселю за раз
                    ),
                  ),
                  if (profile.isPro) ...[
                    const SizedBox(width: 8),
                    // Плашка PRO чітко за твоїм CSS (34x13, радіус 6, відступи 3х4)
                    Container(
                      width: 34,
                      height: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      alignment: Alignment.center, // Центруємо текст всередині плашки
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00F5A0), Color(0xFF0066FF)],
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          // Імітуємо line-height: 7px та leading-trim для ідеального центрування:
                          height: 0.6,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const FigmaRatingStar(
                      isFilled: true,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'PRO only',
                      style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 7),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // Онлайн статус та мікрофон
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: profile.isOnline ? accentColor : const Color(0xFF8E8EA9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    profile.isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 10),
                  ),
                  const SizedBox(width: 48),
                  Icon(Icons.mic, color: profile.hasVoice ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9), size: 13),
                  const SizedBox(width: 4),
                  const Text(
                    'Voice',
                    style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Мови (Фікс verticalAlignment -> alignment)
              RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.public, color: accentColor.withOpacity(0.6), size: 10)
                      ),
                    ),
                    const TextSpan(text: 'Languages: ', style: TextStyle(color: Color(0xFF8E8EA9))),
                    TextSpan(text: langsText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Час гри (Фікс verticalAlignment -> alignment)
              RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Icon(Icons.access_time, color: accentColor.withOpacity(0.6), size: 12)
                      ),
                    ),
                    const TextSpan(text: 'Play time: ', style: TextStyle(color: Color(0xFF8E8EA9))),
                    TextSpan(text: playTimeText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Кнопка Add friend
              GestureDetector(
                onTap: () => print('Add friend tapped'),
                child: SizedBox(
                  width: 92,
                  height: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Іконка fluent-mdl2:add-friend розміром 16x16
                      Icon(
                        Icons.person_add_alt_1,
                        color: accentColor,
                        size: 16,
                      ),
                      const SizedBox(width: 5), // gap: 5px за CSS
                      // Текст "Add friend" розміром 14px та line-height 100%
                      Text(
                        'Add friend',
                        style: TextStyle(
                          color: accentColor,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          height: 1.0, // line-height: 14px (100%)
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // МЕТОД 2: Заголовки секцій
  Widget _buildSectionTitle(String title, {required Widget child}) {
    return Row(
      children: [
        Opacity(opacity: 0.6, child: child),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 14),
        ),
      ],
    );
  }

  // МЕТОД 3: Побудова сітки ігор
  Widget _buildGamesGrid(Color cardBg) {
    final games = profile.gamesList.isNotEmpty ? profile.gamesList : ['Valorant', 'CS2', 'Fortnite', 'Apex'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: games.map((game) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8)),
          child: Text(
            game,
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 13),
          ),
        );
      }).toList(),
    );
  }

  // МЕТОД 4: Рядок платформ
  Widget _buildPlatformsRow(Color cardBg) {
    final platforms = profile.platformsList.isNotEmpty ? profile.platformsList : ['PS', 'Mobile', 'PC', 'Xbox'];
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: platforms.map((platform) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8)),
          child: Text(
            platform,
            style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

  // МЕТОД 5: Стилі гри
  Widget _buildPlayStyleRow(Color cardBg) {
    final tags = profile.tags.isNotEmpty ? profile.tags : ['Casual', 'Competitive'];
    return Wrap(
      spacing: 9,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8)),
          child: Text(
            tag,
            style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

  // МЕТОД 6: Connected Platforms
  Widget _buildConnectedPlatforms(Color cardBg) {
    final Map<String, String> platforms = profile.connectedPlatforms.isNotEmpty
        ? profile.connectedPlatforms
        : {'Discord': 'Player#1234', 'Steam': 'Player1'};

    return Column(
      children: platforms.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 101,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  entry.key,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Container(
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    entry.value,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // МЕТОД 7: Нижні кнопки дій
  Widget _buildActionButtons(Color accentColor) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: accentColor, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Start chat',
                  style: TextStyle(color: accentColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 15),
                ),
                const SizedBox(width: 10),
                const FigmaArrowIcon(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(12)),
            child: const Center(
              child: Text(
                'Invite to play',
                style: TextStyle(color: Color(0xFF0F0F1A), fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}