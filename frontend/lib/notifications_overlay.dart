import 'package:flutter/material.dart';
import 'custom_widgets.dart'; // Наш файл з усіма кастомними SVG

enum NotificationType { match, rating, pro }
enum NotificationState { pending, accepted, declined, expired, matched }

class NotificationModel {
  final String id;
  final String userNickname;
  final String message;
  final NotificationType type;
  final NotificationState state;
  final String time;
  final String game;
  final String platform;
  final String mode;
  final String language;
  int currentRating; // Поточний вибір зірочок (0 - якщо ще нічого не обрано)
  bool isRated;       // Чи була зафіксована оцінка кнопкою

  NotificationModel({
    required this.id,
    this.userNickname = '',
    required this.message,
    required this.type,
    NotificationState? state,
    required this.time,
    this.game = 'Valorant',
    this.platform = 'PC',
    this.mode = 'Competitive',
    this.language = 'English',
    this.currentRating = 0, // Початковий стан: 0 зірочок (нічого не обрано)
    this.isRated = false,   // Ще не натиснуто
  }) : state = state ?? NotificationState.pending;
}

class NotificationsOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const NotificationsOverlay({super.key, required this.onClose});

  @override
  State<NotificationsOverlay> createState() => _NotificationsOverlayState();
}

class _NotificationsOverlayState extends State<NotificationsOverlay> {
  String _activeNotificationTab = 'All';
  bool _allArchived = false;

  final List<NotificationModel> _notifications = [
    NotificationModel(id: '1', userNickname: 'NOVA', message: 'invited you to play Valorant', type: NotificationType.match, state: NotificationState.pending, time: '5s ago', game: 'Valorant'),
    NotificationModel(id: '6', userNickname: 'NOVA', message: 'You matched with', type: NotificationType.match, state: NotificationState.matched, time: '15m ago', game: 'Valorant'),
    NotificationModel(id: '2', userNickname: 'MMA_boxer', message: 'has accepted your invitation to', type: NotificationType.match, state: NotificationState.accepted, time: '15m ago', game: 'Dota 2'),
    NotificationModel(id: '3', userNickname: 'NOVA', message: 'How was your game with NOVA?', type: NotificationType.rating, state: NotificationState.pending, time: '5s ago'),
    NotificationModel(id: '4', userNickname: 'Mario_gamer', message: 'has declined your invitation to', type: NotificationType.match, state: NotificationState.declined, time: '22 Feb 2026', game: 'SMITE'),
    NotificationModel(id: '5', userNickname: 'NOVA', message: 'The invitation has expired.', type: NotificationType.match, state: NotificationState.expired, time: '5m ago', game: 'Valorant'),
  ];

  void _removeNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allArchived
        ? <NotificationModel>[]
        : _notifications.where((n) {
      if (_activeNotificationTab == 'All') return true;
      if (_activeNotificationTab == 'Match' && n.type == NotificationType.match) return true;
      if (_activeNotificationTab == 'Rating' && n.type == NotificationType.rating) return true;
      if (_activeNotificationTab == 'PRO' && n.type == NotificationType.pro) return true;
      return false;
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 540),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Таби фільтрів
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFigmaTab('Match'),
                const SizedBox(width: 9),
                _buildFigmaTab('Rating'),
                const SizedBox(width: 9),
                _buildFigmaTab('PRO'),
                const SizedBox(width: 9),
                _buildFigmaTab('All'),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2B2B3B), height: 1),

          // Список карт або Empty state
          Flexible(
            child: filtered.isEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Container(
                width: 327,
                height: 126,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF181826),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2B2B3B), width: 0.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _allArchived ? 'All notifications archived' : 'No notifications found',
                      style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w500),
                    ),
                    if (_allArchived) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _allArchived = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF00F5A0), width: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Undo', style: TextStyle(color: Color(0xFF00F5A0), fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              itemCount: filtered.length + 1,
              itemBuilder: (context, index) {
                if (index == filtered.length) {
                  return _buildArchiveAllButton();
                }
                return _buildFigmaCard(filtered[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaCard(NotificationModel item) {
    if (item.type == NotificationType.rating) {
      return _buildRatingCard(item);
    }
    switch (item.state) {
      case NotificationState.pending:
        return _buildMatchInviteCard(item, isExpired: false);
      case NotificationState.expired:
        return _buildMatchInviteCard(item, isExpired: true);
      case NotificationState.accepted:
        return _buildChatAcceptedCard(item);
      case NotificationState.declined:
        return _buildDeclinedCard(item);
      case NotificationState.matched:
        return _buildMutualMatchCard(item);
    }
  }

  // === КАРТКА 1: ВЗАЄМНИЙ МАТЧ ===
  Widget _buildMutualMatchCard(NotificationModel item) {
    return Container(
      width: 319,
      height: 70,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF00F5A0), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, size: 12, color: Color(0xFF00F5A0)),
              const SizedBox(width: 6),
              const Text('Match found', style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: TextStyle(color: const Color(0xFF8E8EA9).withOpacity(0.75), fontSize: 9, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          Align(
            alignment: const Alignment(0.0, 0.2),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  const TextSpan(text: 'You matched with ', style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w400)),
                  TextSpan(text: item.userNickname, style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Start chat ', style: TextStyle(color: Color(0xDA00F5A0), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                FigmaArrowIcon(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === КАРТКА 2: ЗАПРОШЕННЯ ===
  Widget _buildMatchInviteCard(NotificationModel item, {required bool isExpired}) {
    final Color borderColor = isExpired ? const Color(0xFF8E8EA9) : const Color(0xFF00F5A0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: borderColor, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.sports_esports, size: 14, color: isExpired ? const Color(0xFF8E8EA9) : const Color(0xFF00F5A0)),
              const SizedBox(width: 6),
              const Text('Play invite', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9, fontFamily: 'Inter')),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${item.userNickname} ', style: TextStyle(color: isExpired ? const Color(0xFF8E8EA9) : const Color(0xFF00F5A0), fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              const Icon(Icons.star, color: Colors.amber, size: 11),
              const Text('PRO only ', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 8, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
              Flexible(
                child: Text(
                  isExpired ? 'The invitation has expired.' : 'invited you to play ${item.game}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.platform, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter')),
              _buildDot(),
              Text(item.mode, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter')),
              _buildDot(),
              Text(item.language, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter')),
              _buildDot(),
              const Text('Online now', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter')),
            ],
          ),
          const SizedBox(height: 10),
          if (!isExpired) ...[
            const Text('Invite expires in 5 min', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 11, fontFamily: 'Inter')),
            const SizedBox(height: 10),
          ],
          Opacity(
            opacity: isExpired ? 0.3 : 1.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    height: 30,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text('Decline', style: TextStyle(color: borderColor, fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 30,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: const Text('Accept', style: TextStyle(color: Color(0xFF0F0F1A), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === КАРТКА 3: ПРИЙНЯТИЙ ІНВАЙТ ===
  Widget _buildChatAcceptedCard(NotificationModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF00F5A0), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sentiment_satisfied, size: 14, color: Color(0xFF00F5A0)),
              const SizedBox(width: 6),
              const Text('Your play invite was accepted!', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '${item.userNickname} ', style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                TextSpan(
                    text: '${item.message.replaceAll(' ${item.game}', '')} ',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w500)
                ),
                TextSpan(text: item.game, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Start chat ', style: TextStyle(color: Color(0xDA00F5A0), fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                FigmaArrowIcon(),
              ],
            ),
          )
        ],
      ),
    );
  }

  // === КАРТКА 4: ВІДХИЛЕНИЙ ІНВАЙТ ===
  Widget _buildDeclinedCard(NotificationModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF00F5A0), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sentiment_very_dissatisfied, size: 14, color: const Color(0xFF00F5A0).withOpacity(0.7)),
              const SizedBox(width: 6),
              const Text('Your play invite was declined', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '${item.userNickname} ', style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                TextSpan(
                    text: '${item.message.replaceAll(' ${item.game}', '')} ',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w500)
                ),
                TextSpan(text: item.game, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === КАРТКА 5: РЕЙТИНГ (Оновлена логіка кнопки за CSS) ===
  Widget _buildRatingCard(NotificationModel item) {
    // Визначаємо колір для кнопки на основі стану за твоїм CSS
    Color buttonColor;
    String buttonText;

    if (item.isRated) {
      buttonColor = const Color(0xFFD8FF2C); // Оцінка виставлена
      buttonText = 'Rated';
    } else if (item.currentRating > 0) {
      buttonColor = const Color(0xFFD8FF2C); // Оцінка обрана, чекає кліку
      buttonText = 'Rate now';
    } else {
      buttonColor = const Color(0xFF6B6B80); // Нічого не обрано (сірий)
      buttonText = 'Rate now';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFFD8FF2C), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Твоя кастомна Figma зірочка замість старої іконки хедера — завжди жовта
              const FigmaRatingStar(isFilled: true),
              const SizedBox(width: 6),
              const Text('Rate your last teammate', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.message, style: const TextStyle(color: Color(0xFFB8B8C6), fontSize: 13, fontFamily: 'Inter')),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ряд зірочок
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: item.isRated
                        ? null // Якщо вже надіслано рейтинг, блокуємо кліки
                        : () {
                      setState(() {
                        item.currentRating = index + 1;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: FigmaRatingStar(isFilled: index < item.currentRating),
                    ),
                  );
                }),
              ),

              // Динамічна кнопка за твоїми CSS-стилями з Figma
              GestureDetector(
                onTap: (item.currentRating > 0 && !item.isRated)
                    ? () {
                  setState(() {
                    item.isRated = true; // Фіксуємо оцінку
                  });
                }
                    : null,
                child: Container(
                  width: 145,
                  height: 25,
                  padding: const EdgeInsets.symmetric(vertical: 4), // Коригуємо під висоту 25 та інлайн лінію
                  decoration: BoxDecoration(
                    color: const Color(0xFF181826),
                    border: Border.all(color: buttonColor, width: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      color: buttonColor,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      height: 1.17,
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildArchiveAllButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _allArchived = !_allArchived;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Archive all', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _allArchived ? const Color(0xFF00F5A0).withOpacity(0.1) : Colors.transparent,
                  border: Border.all(color: _allArchived ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9).withOpacity(0.6), width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _allArchived ? const Icon(Icons.check, size: 16, color: Color(0xFF00F5A0)) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(color: Color(0xFFD9D9D9), shape: BoxShape.circle),
    );
  }

  Widget _buildFigmaTab(String tabName) {
    final isSelected = _activeNotificationTab == tabName;
    Decoration decoration;
    Color textColor;

    switch (tabName) {
      case 'Match':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0).withOpacity(0.4);
        decoration = BoxDecoration(
          color: isSelected ? const Color(0xFF00F5A0) : const Color(0xFF00F5A0).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF00F5A0).withOpacity(0.5), blurRadius: 6)] : null,
        );
        break;
      case 'Rating':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFFD8FF2C).withOpacity(0.4);
        decoration = BoxDecoration(
          color: isSelected ? const Color(0xFFD8FF2C) : const Color(0xFFD8FF2C).withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFD8FF2C).withOpacity(0.5), blurRadius: 6)] : null,
        );
        break;
      case 'PRO':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0).withOpacity(0.4);
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: isSelected
              ? const LinearGradient(
            colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          )
              : null,
          color: isSelected ? null : const Color(0xFF0085FF).withOpacity(0.08),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF0085FF).withOpacity(0.5), blurRadius: 6)] : null,
        );
        break;
      case 'All':
      default:
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFFD05AFF).withOpacity(0.4);
        decoration = BoxDecoration(
          color: isSelected ? const Color(0xFFD05AFF) : const Color(0xFFD05AFF).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFD05AFF).withOpacity(0.5), blurRadius: 6)] : null,
        );
        break;
    }

    return GestureDetector(
      onTap: () => setState(() => _activeNotificationTab = tabName),
      child: Container(
        width: 73,
        height: 20,
        alignment: Alignment.center,
        decoration: decoration,
        child: Text(
          tabName,
          style: TextStyle(color: textColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 10, height: 1.0),
        ),
      ),
    );
  }
}