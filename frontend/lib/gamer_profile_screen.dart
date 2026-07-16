import 'package:flutter/material.dart';
import 'Home_Feed_screen.dart'; // Імпорт моделі GamerProfile
import 'custom_widgets.dart';    // Твої реальні FigmaRatingStar, FigmaArrowIcon та нові SVG-іконки
import 'package:auto_size_text/auto_size_text.dart';
import 'user_session.dart';
import 'api_service.dart';
import 'new_chat_room_screen.dart';

// Створюємо enum для зручного керування станами кнопки дружби
enum FriendStatus {
  addFriend,
  requestSent,
  requestReceived,
  friends,
  blockedByMe,    // Ви заблокували (бачите меню з Unblock / Remove)
  blockedByOther,
}

class GamerProfileScreen extends StatefulWidget {
  final GamerProfile profile;
  const GamerProfileScreen({super.key, required this.profile});

  // ВСТАВТЕ ЦЕЙ МЕТОД ВСЕРЕДИНУ КЛАСУ GamerProfileScreen
  static Future<void> openFromId(BuildContext context, String userId) async {
    // Показуємо спінер
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00F5A0))),
    );

    try {
      final profileData = await ApiService.getUserProfileById(userId);

      if (context.mounted) {
        // Використовуємо rootNavigator: true, щоб точно закрити діалог
        Navigator.of(context, rootNavigator: true).pop();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GamerProfileScreen(profile: profileData)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      print("Помилка відкриття профілю: $e");
    }
  }

  @override
  State<GamerProfileScreen> createState() => _GamerProfileScreenState();
}

class _GamerProfileScreenState extends State<GamerProfileScreen> {
  // Початковий стан беремо за замовчуванням addFriend
  FriendStatus _currentStatus = FriendStatus.addFriend;

  // Контролер для керування показом меню опцій (Remove / Block / Unblock)
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();

  int _currentProfileRating = 0;
  bool _hasRatedGamer = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      print("DEBUG: Початок завантаження статусу та рейтингу...");
      final status = await ApiService.getFriendStatus(widget.profile.id);
      print("DEBUG: Статус дружби отримано: $status");
      final ratingData = await ApiService.getMyRating(widget.profile.id);
      print("DEBUG: Рейтинг отримано: $ratingData");

      if (!mounted) return;

      setState(() {
        if (status == "request_sent") { // Змінено з "pending"
          _currentStatus = FriendStatus.requestSent;
        } else if (status == "request_received") { // Додано обробку
          _currentStatus = FriendStatus.requestReceived;
        } else if (status == "accepted") {
          _currentStatus = FriendStatus.friends;
        } else if (status == "blocked_by_me") {
          _currentStatus = FriendStatus.blockedByMe;
        } else if (status == "blocked_by_other") {
          _currentStatus = FriendStatus.blockedByOther;
        } else {
          _currentStatus = FriendStatus.addFriend;
        }
        _currentProfileRating = ratingData['rating'] ?? 0;
        _hasRatedGamer = ratingData['is_rated'] ?? false;
        print("DEBUG: setState успішно завершено.");
      });
    } catch (e) {
      print("Помилка: $e");
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

              //Rating
              _buildProfileRatingSection(),

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

  Future<void> _showInviteDialog(BuildContext context, GamerProfile profile, VoidCallback onInviteSent) async {
    String? selectedGame;
    bool _isSending = false;

    final myGames = UserSession().currentUser?.gamesList ?? [];
    final commonGames = profile.gamesList.where((g) => myGames.contains(g)).toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: const Color(0xFF181826),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Invite to play in:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                ...commonGames.map((game) => RadioListTile<String>(
                  title: Text(game, style: const TextStyle(color: Colors.white)),
                  value: game,
                  groupValue: selectedGame,
                  onChanged: _isSending ? null : (val) => setModalState(() => selectedGame = val),
                  activeColor: const Color(0xFF00F5A0),
                )),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: _isSending ? null : () => Navigator.pop(context),
                        child: const Text('Cancel')
                    ),
                    ElevatedButton(
                      onPressed: (selectedGame == null || _isSending) ? null : () async {
                        setModalState(() => _isSending = true); // Блокуємо відправку
                        bool success = await ApiService.sendInvite(profile.id, selectedGame!);
                        if (success && mounted) {
                          // Якщо сервер дозволив - оновлюємо локальний таймер
                          UserSession.instance.registerInvite(profile.id);
                          onInviteSent();
                          Navigator.pop(context);
                        } else {
                          // ЯКЩО СЕРВЕР ПОВЕРНУВ ПОМИЛКУ (наприклад, 429), показуємо SnackBar
                          if (mounted) {
                            setModalState(() => _isSending = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Wait 10 minutes before next invite")),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5A0)),
                      child: _isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))
                          : const Text('Send', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                )
              ],
            ),
          ),
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
    final String ratingText = widget.profile.rating.toStringAsFixed(1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Аватарка
        Stack(
          alignment: Alignment.center,
          children: [
            // 1. Шар сяйва
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.6),
                    blurRadius: 8, spreadRadius: -2,
                  ),
                ],
              ),
            ),
            // 2. Аватарка або Буква
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF181826), // Ваш стандартний темний колір фону
                boxShadow: [
                  BoxShadow(color: statusColor, blurRadius: 0.2),
                ],
              ),
              child: (widget.profile.avatar != null && widget.profile.avatar!.isNotEmpty)
                  ? ClipOval(
                child: Image.asset(
                  widget.profile.avatar!,
                  width: 100, height: 100, fit: BoxFit.cover,
                ),
              )
                  : _buildLetterAvatar(widget.profile.nickname, widget.profile.isOnline),
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
                  // Нікнейм: займає весь доступний простір, але стискається при потребі
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Стискається під розмір вмісту
                      children: [
                        Flexible(
                          child: Text(
                            widget.profile.nickname,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins'
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.profile.isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0066FF)]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 8)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 2. Зірочка та рейтинг (завжди праворуч, фіксований розмір)
                  const SizedBox(width: 10), // Відступ перед зіркою
                  Row(
                    children: [
                      const FigmaRatingStar(isFilled: true, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        (UserSession().currentUser?.isPro ?? false)
                            ? widget.profile.rating.toStringAsFixed(1)
                            : 'PRO only',
                        style: TextStyle(
                          color: (UserSession().currentUser?.isPro ?? false)
                              ? accentColor
                              : const Color(0xFF8E8EA9),
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          // Динамічний розмір: 15 для рейтингу, 10 для "PRO only"
                          fontSize: (UserSession().currentUser?.isPro ?? false) ? 15 : 10,
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildLetterAvatar(String nickname, bool isOnline) {
    return Center(
      child: Text(
        nickname.isNotEmpty ? nickname[0].toUpperCase() : 'G',
        style: TextStyle(
          fontFamily: 'Love Light',
          fontSize: 50, // Збільшено для розміру 100px аватара
          fontWeight: FontWeight.w400,
          color: isOnline ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9),
        ),
      ),
    );
  }

  // МЕТОД ГЕНЕРАЦІЇ ДИНАМІЧНОЇ КНОПКИ ЗА ЦСС ТА СТАНАМИ
  Widget _buildDynamicFriendButton(Color accentColor) {
    switch (_currentStatus) {
    // Стан 1: Add Friend
      case FriendStatus.addFriend:
        return GestureDetector(
          onTap: () async {
            final success = await ApiService.sendFriendRequest(widget.profile.id);
            if (mounted) {
              await _fetchStatus();
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

    // 2.1 Request Sent Варіант 2Ви відправили запит (можна скасувати, залишаємо ваш GestureDetector)
      case FriendStatus.requestSent:
        const requestColor = Color(0xFF8E8EA9);
        return GestureDetector(
          onTap: () async {
            final success = await ApiService.removeFriend(widget.profile.id);
            if (success && mounted) {
              setState(() {
                _currentStatus = FriendStatus.addFriend;
              });
            }
          },
          child: const SizedBox(
            width: 220,
            height: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_remove_alt_1, color: requestColor, size: 16),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Request sent/Cancel',
                    style: TextStyle(color: requestColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );

    //2.2 Request Sent Варіант 2 Вам надіслали запит (сірий неклікабельний контейнер)
      case FriendStatus.requestReceived:
        const requestColor = Color(0xFF8E8EA9);
        return GestureDetector(
          child: const SizedBox(
            width: 152,
            height: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_empty, color: requestColor, size: 16),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Waiting for answer',
                    style: TextStyle(color: requestColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );

    // Стан 3: Friends
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
            OverlayPortal(
              controller: _overlayController,
              overlayChildBuilder: (context) {
                return CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
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
                    color: Colors.transparent,
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

    // Стан 4: Ви заблокували користувача
      case FriendStatus.blockedByMe:
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
            OverlayPortal(
              controller: _overlayController,
              overlayChildBuilder: (context) {
                return CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
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
                    _overlayController.toggle();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    color: Colors.transparent,
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

    // Стан 5: Вас заблокували
      case FriendStatus.blockedByOther:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'User unavailable',
              style: TextStyle(
                color: Color(0xFFFF4A4A),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
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
              onTap: () async {
                // 1. Спочатку ховаємо меню
                _overlayController.hide();

                // 2. Викликаємо API
                final success = await ApiService.removeFriend(widget.profile.id);

                // 3. Якщо успішно - оновлюємо UI
                if (success && mounted) {
                  setState(() {
                    _currentStatus = FriendStatus.addFriend;
                  });

                  // Невелика індикація для користувача
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend removed successfully')),
                  );
                } else {
                  // Обробка помилки, якщо щось пішло не так
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to remove friend')),
                    );
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: const Text(
                  'Remove friend',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                      height: 1.0
                  ),
                ),
              ),
            ),
            const Divider(color: Color(0xFF2B2B3B), height: 1, thickness: 0.5),
            // Опція 2: Block User
            InkWell(
              onTap: () async {
                // 1. Ховаємо меню
                _overlayController.hide();

                // 2. Викликаємо API для блокування
                // Переконайтеся, що widget.profile.id існує у вашій моделі
                final success = await ApiService.blockUser(widget.profile.id);

                // 3. Якщо запит успішний, оновлюємо стан UI
                if (success && mounted) {
                  setState(() {
                    _currentStatus = FriendStatus.blockedByMe;
                  });

                  // Додатковий фідбек для користувача
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User has been blocked')),
                  );
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to block user')),
                    );
                  }
                }
              },
              // Зберігаємо ваш дизайн контейнера
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: const Text(
                  'Block user',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                      height: 1.0
                  ),
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
            // 1. Повністю видалити з друзів (навіть із блоку) -> Викликаємо API та скидаємо на Add Friend
            InkWell(
              onTap: () async {
                _overlayController.hide();

                // Показуємо діалогове вікно підтвердження перед видаленням
                final bool? confirmDelete = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF181826),
                      title: const Text(
                        'Remove Friend',
                        style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
                      ),
                      content: const Text(
                        'User will also be removed from Blocked. Remove?',
                        style: TextStyle(color: Colors.grey, fontFamily: 'Inter'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('No', style: TextStyle(color: Colors.white)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Yes', style: TextStyle(color: Color(0xFF00F5A0))),
                        ),
                      ],
                    );
                  },
                );

                // Викликаємо API для видалення дружби/блокування тільки якщо користувач натиснув Yes
                if (confirmDelete == true) {
                  final success = await ApiService.removeFriend(widget.profile.id);

                  if (success && mounted) {
                    setState(() {
                      _currentStatus = FriendStatus.addFriend;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Статус успішно видалено')),
                    );
                  }
                }
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
              onTap: () async {
                _overlayController.hide();

                // Викликаємо новий бекенд-ендпоінт
                final success = await ApiService.unblockUser(widget.profile.id);

                if (success && mounted) {
                  setState(() {
                    _currentStatus = FriendStatus.friends; // Повертаємо статус друзів
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Користувача розблоковано')),
                  );
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Не вдалося розблокувати користувача')),
                    );
                  }
                }
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

  // === ОЦІНЮВАННЯ ПРОФІЛЮ ==
  Widget _buildProfileRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Please rate gamer:',
          style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () async {
                // 1. Одразу міняємо інтерфейс, щоб користувач бачив результат кліку
                setState(() {
                  _currentProfileRating = index + 1;
                  _hasRatedGamer = true;
                });

                // 2. Відправляємо запит на сервер
                final success = await ApiService.rateUser(widget.profile.id, index + 1);

                if (success && mounted) {
                  // 3. ЯК ТІЛЬКИ сервер підтвердив успіх,
                  // ми викликаємо _fetchStatus(), щоб він завантажив СВІЖИЙ середній рейтинг
                  await _fetchStatus();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rating updated!')),
                    );
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FigmaRatingStar(isFilled: index < _currentProfileRating),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
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
    final bool isEnabled = UserSession.instance.canInvite(widget.profile.id);
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              // 1. Показуємо лоадер, бо запит може зайняти час
              showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));

              try {
                // 2. Викликаємо АПІ для отримання/створення чату
                final response = await ApiService.getOrCreateChat(widget.profile.id);
                final String chatId = response['chat_id'];

                if (mounted) {
                  Navigator.pop(context); // Ховаємо лоадер

                  // 3. Відкриваємо чат
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatRoomScreen(
                        friendName: widget.profile.nickname,
                        chatId: chatId,
                        friendId: widget.profile.id.toString(),
                        // ДОДАЙ ЦЕЙ ПАРАМЕТР:
                        onBack: () {
                          Navigator.pop(context); // Закриває ChatRoomScreen
                          _fetchStatus();         // Оновлює статус дружби на екрані профілю
                        },
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Помилка відкриття чату")));
              }
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: accentColor, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Start chat', style: TextStyle(color: accentColor, fontSize: 15)),
                  const SizedBox(width: 10),
                  const FigmaArrowIcon(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: isEnabled
                ? () async {
              // Викликаємо діалог інвайту
              await _showInviteDialog(context, widget.profile, () {
                setState(() {
                  // Реєструємо інвайт у глобальному стані
                  UserSession.instance.registerInvite(widget.profile.id);
                  // 2. Оновлюємо інтерфейс профілю (перемальовуємо кнопки)
                  setState(() {});
                });
              });
            }
                : null, // Якщо не дозволено, нічого не станеться
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                // Якщо вимкнено — сірий колір, якщо ввімкнено — акцентний
                color: isEnabled ? accentColor : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  isEnabled ? 'Invite to play' : 'Invite to play',
                  style: TextStyle(
                      color: isEnabled ? const Color(0xFF0F0F1A) : Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}