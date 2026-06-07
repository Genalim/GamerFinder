import 'package:flutter/material.dart';
import 'Home_Feed_screen.dart'; // Імпорт моделі GamerProfile
import 'custom_widgets.dart';    // Твої реальні FigmaRatingStar, FigmaArrowIcon та нові SVG-іконки
import 'package:auto_size_text/auto_size_text.dart';
import 'user_session.dart';
import 'api_service.dart';

// Створюємо enum для зручного керування станами кнопки дружби
enum FriendStatus {
  addFriend,
  requestSent,
  friends,
  blocked,
}

class GamerProfileScreen extends StatefulWidget {
  final GamerProfile profile;
  const GamerProfileScreen({super.key, required this.profile});

  @override
  State<GamerProfileScreen> createState() => _GamerProfileScreenState();
}

class _GamerProfileScreenState extends State<GamerProfileScreen> {
  // Початковий стан беремо за замовчуванням addFriend
  FriendStatus _currentStatus = FriendStatus.addFriend;

  // Контролер для керування показом меню опцій (Remove / Block / Unblock)
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final status = await ApiService.getFriendStatus(widget.profile.id);

      // Перевіряємо, чи ще актуальний цей віджет (щоб уникнути помилок після закриття)
      if (!mounted) return;

      setState(() {
        if (status == "pending") {
          _currentStatus = FriendStatus.requestSent;
        } else if (status == "accepted") {
          _currentStatus = FriendStatus.friends;
        } else {
          _currentStatus = FriendStatus.addFriend;
        }
      });
    } catch (e) {
      print("Помилка при отриманні статусу: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00F5A0);
    const cardBg = Color(0xFF181826);

    // Закриваємо меню опцій, якщо користувач просто скролить або клікає по екрану
    return GestureDetector(
      onTap: () {
        if (_overlayController.isShowing) {
          _overlayController.hide();
        }
      },
      child: Scaffold(
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
              // 1. ХЕДЕР: Аватарка, Статуси, Нікнейм та Інтерактивна кнопка дій
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
              _buildConnectedAccounts(),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          color: const Color(0xFF0F0F13),
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 12),
          child: _buildActionButtons(accentColor),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color statusColor) {
    return Center(
      child: Text(
        widget.profile.nickname.isNotEmpty ? widget.profile.nickname[0].toUpperCase() : 'G',
        style: TextStyle(
          fontFamily: 'Love Light',
          fontSize: 50,
          color: statusColor,
        ),
      ),
    );
  }

  // МЕТОД 1: Хедер профілю (З інтерактивними кнопками Add Friend / Request Sent / Friends)
  Widget _buildHeader(Color accentColor) {
    final Color statusColor = widget.profile.isOnline ? accentColor : const Color(0xFF8E8EA9);

    final String langsText = (widget.profile.languages.isNotEmpty)
        ? widget.profile.languages.join(' • ')
        : 'Not specified';

    final String playTimeText = widget.profile.readablePlayTime;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Аватарка
        Stack(
          alignment: Alignment.center,
          children: [
            // 1. Шар великого сяйва (це і є ваше drop-shadow)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              ),
            ),
            // 2. Аватарка (БЕЗ жорсткої рамки Border)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Замість Border.all ми додаємо внутрішню тінь або ледь помітний інший ефект,
                // АБО просто обрізаємо картинку.
                // Якщо треба саме підсвічений край — додайте сюди BoxShadow з малим blur:
                boxShadow: [
                  BoxShadow(
                    color: statusColor,
                    blurRadius: 0.2, // Дуже тонкий м'який контур замість жорсткого Border
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: (widget.profile.avatar != null && widget.profile.avatar!.isNotEmpty)
                    ? Image.asset(
                  widget.profile.avatar!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(statusColor),
                )
                    : _buildPlaceholder(statusColor),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),

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
                      widget.profile.nickname,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
                      maxLines: 1,
                      minFontSize: 13,
                      stepGranularity: 1,
                    ),
                  ),
                  if (widget.profile.isPro) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      alignment: Alignment.center,
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
                          height: 0.6,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const FigmaRatingStar(isFilled: true, size: 11),
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
                      color: widget.profile.isOnline ? accentColor : const Color(0xFF8E8EA9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.profile.isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 10),
                  ),
                  const SizedBox(width: 48),
                  Icon(Icons.mic, color: widget.profile.hasVoice ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9), size: 13),
                  const SizedBox(width: 4),
                  const Text(
                    'Voice',
                    style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Мови
              RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.public, color: accentColor.withOpacity(0.6), size: 10),
                      ),
                    ),
                    const TextSpan(text: 'Languages: ', style: TextStyle(color: Color(0xFF8E8EA9))),
                    TextSpan(text: langsText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Час гри
              RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Icon(Icons.access_time, color: accentColor.withOpacity(0.6), size: 12),
                      ),
                    ),
                    const TextSpan(text: 'Play time: ', style: TextStyle(color: Color(0xFF8E8EA9))),
                    TextSpan(text: playTimeText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // КНОПКА ДІЇ (Add Friend / Request Sent / Friends / Blocked)
              _buildDynamicFriendButton(accentColor),
            ],
          ),
        ),
      ],
    );
  }

  // МЕТОД ГЕНЕРАЦІЇ ДИНАМІЧНОЇ КНОПКИ ЗА ЦСС ТА СТАНАМИ
  Widget _buildDynamicFriendButton(Color accentColor) {
    switch (_currentStatus) {
    // Стан 1: Add Friend (Початковий варіант)
      case FriendStatus.addFriend:
        return GestureDetector(
          onTap: () async {
            final success = await ApiService.sendFriendRequest(widget.profile.id);
            if (success && mounted) {
              setState(() {
                _currentStatus = FriendStatus.requestSent;
              });
            }
          },
          child: SizedBox(
            width: 92,
            height: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1, color: accentColor, size: 16),
                const SizedBox(width: 5),
                Text(
                  'Add friend',
                  style: TextStyle(color: accentColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, height: 1.0),
                ),
              ],
            ),
          ),
        );

    // Стан 2: Friend request sent (Сіра, при кліку переходить у Friends)
      case FriendStatus.requestSent:
        const requestColor = Color(0xFF8E8EA9);
        return GestureDetector(
          onTap: () async {
            // Викликаємо API для видалення запиту
            final success = await ApiService.removeFriend(widget.profile.id);
            if (success && mounted) {
              setState(() {
                _currentStatus = FriendStatus.addFriend; // Повертаємо кнопку в Add Friend
              });
            }
          },
          child: SizedBox(
            width: 152,
            height: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.person_remove_alt_1, color: requestColor, size: 16), // Іконка видалення
                const SizedBox(width: 5),
                Expanded( // Додаємо це
                  child: Text(
                    'Request sent/Cancel',
                    style: TextStyle(color: requestColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, height: 1.0),
                    overflow: TextOverflow.ellipsis,)
                ),
              ],
            ),
          ),
        );

    // Стан 3: Friends (Зелена з галочкою + Три крапки праворуч для виклику меню опцій)
      case FriendStatus.friends:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 75,
              height: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, color: accentColor, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    'Friends',
                    style: TextStyle(color: accentColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, height: 1.0),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Огортаємо три крапки в OverlayPortal для випадаючого меню
            OverlayPortal(
              controller: _overlayController,
              overlayChildBuilder: (context) {
                return CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  // Складання зміщення меню (за CSS: left: 270px від екрану, top: 146px)
                  offset: const Offset(33, 2),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _buildOptionsMenu(),
                  ),
                );
              },
              child: CompositedTransformTarget(
                link: _layerLink,
                child: GestureDetector(
                  onTap: () {
                    _overlayController.toggle();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    color: Colors.transparent, // Збільшує зону кліку
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accentColor, width: 1.5),
                        ),
                      )),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

    // Стан 4: Стан коли юзера заблоковано (замість кнопок дружби)
      case FriendStatus.blocked:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'User Blocked',
              style: TextStyle(
                color: Color(0xFFFF4A4A),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 10),
            // Огортаємо три крапки в такий самий OverlayPortal і LayerLink
            OverlayPortal(
              controller: _overlayController,
              overlayChildBuilder: (context) {
                return CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  // Зсуваємо плашку трохи нижче (на 29 пікселів), щоб вона була на рівні top: 173px, як у CSS
                  offset: const Offset(33, 2),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _buildUnblockMenu(),
                  ),
                );
              },
              child: CompositedTransformTarget(
                link: _layerLink,
                child: GestureDetector(
                  onTap: () {
                    _overlayController.toggle(); // Тепер воно ожило і відкриває меню!
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    color: Colors.transparent, // Збільшує зону тача
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accentColor, width: 1.5),
                        ),
                      )),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  // МЕТОД 1.1: Конструктор меню опцій (Remove friend / Block user) за CSS
  Widget _buildOptionsMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 110, // Трохи розширено падінги для тексту
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF181826),
          border: Border.all(color: const Color(0xFF2B2B3B), width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Опція 1: Remove Friend
            InkWell(
              onTap: () {
                _overlayController.hide();
                setState(() {
                  _currentStatus = FriendStatus.addFriend;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: const Text(
                  'Remove friend',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 10, height: 1.0),
                ),
              ),
            ),
            const Divider(color: Color(0xFF2B2B3B), height: 1, thickness: 0.5),
            // Опція 2: Block User
            InkWell(
              onTap: () {
                _overlayController.hide();
                setState(() {
                  _currentStatus = FriendStatus.blocked;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: const Text(
                  'Block user',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 10, height: 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // МЕТОД 1.2: Конструктор меню розблокування (Unblock user) за CSS
  Widget _buildUnblockMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF181826),
          border: Border.all(color: const Color(0xFF2B2B3B), width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Повністю видалити з друзів (навіть із блоку) -> скидає на Add Friend
            InkWell(
              onTap: () {
                _overlayController.hide();
                setState(() {
                  _currentStatus = FriendStatus.addFriend;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: const Text(
                  'Remove friend',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 10, height: 1.0),
                ),
              ),
            ),
            const Divider(color: Color(0xFF2B2B3B), height: 1, thickness: 0.5),

            // 2. Просто розблокувати -> ПОВЕРТАЄ В СТАТУС ДРУЗІВ (Friends)
            InkWell(
              onTap: () {
                _overlayController.hide();
                setState(() {
                  _currentStatus = FriendStatus.friends; // ЗМІНИЛИ ТУТ СТАН
                });
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF181826),
                  border: Border.all(color: const Color(0xFF00F5A0), width: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Unblock user',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 10, height: 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
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
    // Отримуємо ігри користувача
    final myGames = UserSession().currentUser?.gamesList ?? [];
    final games = widget.profile.gamesList;

    // Робимо зелений колір трохи м'якшим, щоб не "горів"
    const Color softGreen = Color(0xFF00C875);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: games.map((game) {
        final bool isMatch = myGames.contains(game);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            // Ледь помітна рамка, якщо гра збігається
            border: isMatch
                ? Border.all(color: softGreen.withOpacity(0.5), width: 1)
                : null,
          ),
          child: Text(
            game,
            style: TextStyle(
              // Текст стає зеленим тільки якщо збігається, інакше залишається білим
              color: isMatch ? softGreen : Colors.white.withOpacity(0.8),
              fontFamily: 'Poppins',
              fontWeight: isMatch ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }

  // МЕТОД 4: Рядок платформ
  Widget _buildPlatformsRow(Color cardBg) {
    final platforms = widget.profile.platformsList.isNotEmpty ? widget.profile.platformsList : ['PS', 'Mobile', 'PC', 'Xbox'];
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
    final tags = widget.profile.tags.isNotEmpty ? widget.profile.tags : ['Casual', 'Competitive'];
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
  Widget _buildConnectedAccounts() {
    if (widget.profile.connectedPlatforms.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: widget.profile.connectedPlatforms.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 15), // Відступ між рядами
          height: 28, // Висота згідно з вашим CSS
          child: Row(
            children: [
              // КОНТЕЙНЕР НАЗВИ (Discord)
              Container(
                width: 101,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF181826),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 15), // Gap: 15px згідно з вашим CSS

              // КОНТЕЙНЕР ID (Player#1234)
              Expanded(
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF181826),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
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