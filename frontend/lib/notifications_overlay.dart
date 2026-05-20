import 'package:flutter/material.dart';
import 'custom_widgets.dart'; // Наш файл з усіма кастомними SVG та іконками

enum NotificationType { match, rating, pro }
enum NotificationState { pending, accepted, declined, expired, matched }

class NotificationModel {
  final String id;
  final String userNickname;
  final String message;
  final NotificationType type;
  NotificationState state; // Змінено на non-final для можливості оновлення стану
  final String time;
  final String game;
  final String platform;
  final String mode;
  final String language;
  int currentRating;
  bool isRated;

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
    this.currentRating = 0,
    this.isRated = false,
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

  // Мокані дані з ПРАВИЛЬНИМИ початковими статусами відповідно до дизайнів карток
  final List<NotificationModel> _notifications = [
    // Вкладка Match
    NotificationModel(id: '1', userNickname: 'NOVA', message: 'invited you to play Valorant', type: NotificationType.match, state: NotificationState.pending, time: '5s ago', game: 'Valorant'),
    NotificationModel(id: '6', userNickname: 'NOVA', message: 'You matched with', type: NotificationType.match, state: NotificationState.matched, time: '15m ago', game: 'Valorant'),
    NotificationModel(id: '2', userNickname: 'MMA_boxer', message: 'has accepted your invitation to', type: NotificationType.match, state: NotificationState.accepted, time: '15m ago', game: 'Dota 2'),
    NotificationModel(id: '4', userNickname: 'Mario_gamer', message: 'has declined your invitation to', type: NotificationType.match, state: NotificationState.declined, time: '22 Feb 2026', game: 'SMITE'),
    NotificationModel(id: '5', userNickname: 'NOVA', message: 'The invitation has expired.', type: NotificationType.match, state: NotificationState.expired, time: '5m ago', game: 'Valorant'),

    // Вкладка Rating
    NotificationModel(id: '3', userNickname: 'NOVA', message: 'How was your game with ', type: NotificationType.rating, state: NotificationState.pending, time: '5s ago'),

    // Вкладка PRO (Кожній картці свій унікальний статус для мапінгу віджетів)
    NotificationModel(id: 'pro_1', message: 'Try PRO for free for 7 days!', type: NotificationType.pro, state: NotificationState.pending, time: '5 sec ago'),
    NotificationModel(id: 'pro_2', message: 'Your PRO plan expires in 2 days!', type: NotificationType.pro, state: NotificationState.matched, time: '18h ago'),
    NotificationModel(id: 'pro_3', message: 'Your PRO subscription could not be renewed.', type: NotificationType.pro, state: NotificationState.declined, time: '5 days ago'),
    NotificationModel(id: 'pro_4', message: 'Welcome to PRO!', type: NotificationType.pro, state: NotificationState.accepted, time: '2h ago'),
    NotificationModel(id: 'pro_5', message: 'Sorry... Your PRO subscription has ended.', type: NotificationType.pro, state: NotificationState.expired, time: '5 sec ago'),
  ];

  void _removeNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  // Реальна логіка "Archive all" відповідно до обраного таба
  void _archiveCurrentTab() {
    setState(() {
      if (_activeNotificationTab == 'All') {
        _notifications.clear();
      } else {
        NotificationType? typeToClear;
        if (_activeNotificationTab == 'Match') typeToClear = NotificationType.match;
        if (_activeNotificationTab == 'Rating') typeToClear = NotificationType.rating;
        if (_activeNotificationTab == 'PRO') typeToClear = NotificationType.pro;

        if (typeToClear != null) {
          _notifications.removeWhere((n) => n.type == typeToClear);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const double maxOverlayHeight = 730.0;

    // Справжній фільтр без використання штучного прапорця _allArchived
    final filtered = _notifications.where((n) {
      if (_activeNotificationTab == 'All') return true;
      if (_activeNotificationTab == 'Match' && n.type == NotificationType.match) return true;
      if (_activeNotificationTab == 'Rating' && n.type == NotificationType.rating) return true;
      if (_activeNotificationTab == 'PRO' && n.type == NotificationType.pro) return true;
      return false;
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: maxOverlayHeight),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A), // Оригінальний темний фон плашки з Figma
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ПОСУНУТА НАЗАД ШАПКА ОВЕРЛЕЮ (Зникла у попередній версії)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                ),
                const Spacer(),
                FigmaCloseButton(onTap: widget.onClose),
              ],
            ),
          ),

          // Рядок табів (Селектори категорій)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFigmaTab('Match'),
                _buildFigmaTab('Rating'),
                _buildFigmaTab('PRO'),
                _buildFigmaTab('All'),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2B2B3B), height: 1),

          // Список сповіщень або Empty State
          Flexible(
            child: filtered.isEmpty
                ? _buildFigmaEmptyState()
                : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
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

  Widget _buildFigmaEmptyState() {
    return Container(
      width: double.infinity,
      height: 126,
      margin: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 0.5),
      ),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400, height: 1.1),
                  children: [
                    TextSpan(
                      text: 'Your recent notifications were moved to ',
                      style: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.7)),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => print('Navigate to History page'),
                        child: const Text(
                          'History',
                          style: TextStyle(color: Color(0xFF00F5A0), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            right: 12,
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Inbox cleared',
                  style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 6),
                FigmaInboxClearedIcon(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveAllButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10, right: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _archiveCurrentTab,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Archive all',
                  style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 6),
                FigmaArchiveCheckbox(isChecked: false), // Відображається статично як елемент дій
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaCard(NotificationModel item) {
    if (item.type == NotificationType.rating) return _buildRatingCard(item);

    if (item.type == NotificationType.pro) {
      switch (item.state) {
        case NotificationState.pending: return _buildProTrialAvailableCard(item);
        case NotificationState.matched: return _buildProExpiringCard(item);
        case NotificationState.declined: return _buildPaymentFailedCard(item);
        case NotificationState.accepted: return _buildProActivatedCard(item);
        case NotificationState.expired: return _buildProExpiredCard(item);
      }
    }

    switch (item.state) {
      case NotificationState.pending: return _buildMatchInviteCard(item, isExpired: false);
      case NotificationState.expired: return _buildMatchInviteCard(item, isExpired: true);
      case NotificationState.accepted: return _buildChatAcceptedCard(item);
      case NotificationState.declined: return _buildDeclinedCard(item);
      case NotificationState.matched: return _buildMutualMatchCard(item);
    }
  }

  // =========================================================================
  // ВКЛАДКА MATCH КАРТКИ
  // =========================================================================

  Widget _buildMatchInviteCard(NotificationModel item, {required bool isExpired}) {
    final Color borderColor = isExpired ? const Color(0xFF8E8EA9) : const Color(0xFF00F5A0);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFF181826),
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(12)
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.sports_esports, size: 14, color: borderColor),
              const SizedBox(width: 6),
              const Text('Play invite', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${item.userNickname} ', style: TextStyle(color: isExpired ? const Color(0xFF8E8EA9) : const Color(0xFF00F5A0), fontSize: 13, fontWeight: FontWeight.w600)),
              const Icon(Icons.star, color: Colors.amber, size: 11),
              const Text('PRO only ', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 8, fontWeight: FontWeight.w700)),
              Flexible(child: Text(isExpired ? 'The invitation has expired.' : 'invited you to play ${item.game}', style: const TextStyle(color: Color(0xFFB8B8C6), fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.platform, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              _buildDot(),
              Text(item.mode, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              _buildDot(),
              Text(item.language, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              _buildDot(),
              const Text('Online now', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          if (!isExpired) ...[const Text('Invite expires in 5 min', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 11)), const SizedBox(height: 10)],
          Opacity(
            opacity: isExpired ? 0.3 : 1.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isExpired ? null : () => _removeNotification(item.id),
                    child: Container(
                        height: 30,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(border: Border.all(color: borderColor, width: 0.5), borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Text('Decline', style: TextStyle(color: borderColor, fontSize: 12))
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: isExpired ? null : () => print('Accept clicked'),
                    child: Container(
                        height: 30,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: const Text('Accept', style: TextStyle(color: Color(0xFF0F0F1A), fontSize: 12, fontWeight: FontWeight.w600))
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ВКЛАДКА RATING КАРТКА
  // =========================================================================

  Widget _buildRatingCard(NotificationModel item) {
    Color buttonColor = (item.isRated || item.currentRating > 0) ? const Color(0xFFD8FF2C) : const Color(0xFF6B6B80);
    String buttonText = item.isRated ? 'Rated' : 'Rate now';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFFD8FF2C), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const FigmaRatingStar(isFilled: true),
              const SizedBox(width: 6),
              const Text('Rate your last teammate', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
              children: [
                const TextSpan(text: 'How was your game with ', style: TextStyle(color: Color(0xFFB8B8C6))),
                TextSpan(text: '${item.userNickname}?', style: const TextStyle(color: Color(0xFF00F5A0), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: item.isRated ? null : () => setState(() => item.currentRating = index + 1),
                    child: Padding(padding: const EdgeInsets.only(right: 6.0), child: FigmaRatingStar(isFilled: index < item.currentRating)),
                  );
                }),
              ),
              GestureDetector(
                onTap: (item.currentRating > 0 && !item.isRated) ? () => setState(() => item.isRated = true) : null,
                child: Container(
                  width: 145, height: 25,
                  decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: buttonColor, width: 0.5), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(buttonText, style: TextStyle(color: buttonColor, fontSize: 12, fontWeight: FontWeight.w500, height: 1.17)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // =========================================================================
  // ВКЛАДКА PRO КАРТКИ
  // =========================================================================

  Widget _buildProTrialAvailableCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF0085FF), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const RadialGradient(colors: [Color(0xFF00F5A0), Color(0xFF0085FF)]).createShader(bounds),
                child: const Icon(Icons.star_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 6),
              const Text('PRO trial is available', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w400),
              children: [
                TextSpan(text: 'Try PRO for free for ', style: TextStyle(color: Color(0xFFB8B8C6))),
                TextSpan(text: '7 days!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text('Unlock advanced filters and unlimited matches.', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 11, fontFamily: 'Inter'), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => print('Activate PRO Trial'),
            child: Container(
              width: 145, height: 25,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0085FF)]),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text('Activate', style: TextStyle(color: Color(0xFF0F0F1A), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProExpiringCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF0085FF), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom_rounded, size: 14, color: Color(0xFF0085FF)),
              const SizedBox(width: 6),
              const Text('Subscription expiring', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 13, fontFamily: 'Inter'),
              children: [
                TextSpan(text: 'Your PRO plan expires in ', style: TextStyle(color: Color(0xFFB8B8C6))),
                TextSpan(text: '2 days!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => print('Renew subscription'),
            child: Container(
              width: 145, height: 25, padding: const EdgeInsets.all(0.5),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0085FF)]), borderRadius: BorderRadius.circular(10)),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(9.5)),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0085FF)]).createShader(bounds),
                  child: const Text('Renew subscription', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentFailedCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFFFF6B6B), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 6),
              const Text('Payment failed', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Your PRO subscription could not be renewed.', style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => print('Update payment'),
            child: Container(
              width: 160, height: 25,
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF6B6B), width: 0.5), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: const Text('Update payment method', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProActivatedCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        // Фірмовий синій колір бордера для активованого стану
        border: Border.all(color: const Color(0xFF0085FF), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, // Вирівнювання елементів по лівому краю
        children: [
          // ВЕРХНІЙ РЯДОК: Іконка + Напис + Час + Хрестик
          Row(
            children: [
              // Тонка лінійна іконка «палець вгору» з градієнтом
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Icon(Icons.thumb_up_outlined, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 6),
              // Той самий напис зверху зліва, якого не вистачало!
              const Text(
                'PRO activated',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                item.time,
                style: const TextStyle(
                  color: Color(0xFF8E8EA9),
                  fontSize: 6,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),

          const SizedBox(height: 8), // Простір між заголовком і контентом

          // НИЖНІЙ РЯДОК: Основне повідомлення з кастомним бейджем PRO всередині рядка
          Row(
            children: [
              const Text(
                'Welcome to ',
                style: TextStyle(
                  color: Color(0xFFB8B8C6),
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
              ),
              // Кастомний градієнтний бейдж PRO з Figma
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Color(0xFF0F0F1A), // Темний колір тексту всередині неонового бейджа
                    fontSize: 10,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  '! Enjoy your advanced filters.',
                  style: TextStyle(
                    color: Color(0xFFB8B8C6),
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProExpiredCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        // 1) Повертаємо кольорову синю рамку, як у інших PRO повідомлень
        border: Border.all(color: const Color(0xFF0085FF), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const FigmaLightningIcon(size: 16),
              const SizedBox(width: 8),
              const Text(
                'PRO expired',
                style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                item.time,
                style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9, fontFamily: 'Inter'),
              ),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Sorry... Your PRO subscription has ended.',
            style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 13, fontFamily: 'Inter'),
            textAlign: TextAlign.center,
          ),
          // 3) Зменшили висоту відступу з 10 до 6, щоб трішки підняти кнопку
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => print('Activate PRO'),
            child: Container(
              width: 145,
              height: 25,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              // 2) Змінено текст з 'Reactivate' на 'Activate'
              child: const Text(
                'Activate',
                style: TextStyle(color: Color(0xFF0F0F1A), fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Допоміжні методи для взаємних статусів Match
  Widget _buildMutualMatchCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF00F5A0), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.favorite_border, size: 14, color: Color(0xFF00F5A0)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(children: [
                const TextSpan(text: 'You matched with ', style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 13, fontFamily: 'Inter')),
                TextSpan(text: item.userNickname, style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const Row(children: [Text('Chat ', style: TextStyle(color: Color(0xFF00F5A0), fontSize: 12, fontWeight: FontWeight.w600)), FigmaArrowIcon()]),
        ],
      ),
    );
  }

  Widget _buildChatAcceptedCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF00F5A0), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF00F5A0)),
              const SizedBox(width: 6),
              const Text('Invite accepted', style: TextStyle(color: Colors.white, fontSize: 11)),
              const Spacer(),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${item.userNickname} accepted your invitation to ${item.game}!', style: const TextStyle(color: Color(0xFFB8B8C6), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDeclinedCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFFFF6B6B), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.block, size: 14, color: Color(0xFFFF6B6B)),
          const SizedBox(width: 8),
          Expanded(child: Text('${item.userNickname} declined your invite.', style: const TextStyle(color: Color(0xFFB8B8C6), fontSize: 13))),
          FigmaCloseButton(onTap: () => _removeNotification(item.id)),
        ],
      ),
    );
  }

  Widget _buildDot() => Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 6), decoration: const BoxDecoration(color: Color(0xFF3B3B4B), shape: BoxShape.circle));

  Widget _buildFigmaTab(String tabName) {
    final isSelected = _activeNotificationTab == tabName;
    Decoration decoration; Color textColor;
    switch (tabName) {
      case 'Match':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0).withOpacity(0.4);
        decoration = BoxDecoration(color: isSelected ? const Color(0xFF00F5A0) : const Color(0xFF00F5A0).withOpacity(0.08), borderRadius: BorderRadius.circular(8));
        break;
      case 'Rating':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFFD8FF2C).withOpacity(0.4);
        decoration = BoxDecoration(color: isSelected ? const Color(0xFFD8FF2C) : const Color(0xFFD8FF2C).withOpacity(0.06), borderRadius: BorderRadius.circular(8));
        break;
      case 'PRO':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0).withOpacity(0.4);
        decoration = BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: isSelected ? const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0085FF)]) : null, color: isSelected ? null : const Color(0xFF0085FF).withOpacity(0.08));
        break;
      case 'All':
      default:
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFFD05AFF).withOpacity(0.4);
        decoration = BoxDecoration(color: isSelected ? const Color(0xFFD05AFF) : const Color(0xFFD05AFF).withOpacity(0.08), borderRadius: BorderRadius.circular(8));
        break;
    }
    return GestureDetector(
      onTap: () => setState(() => _activeNotificationTab = tabName),
      child: Container(width: 73, height: 20, alignment: Alignment.center, decoration: decoration, child: Text(tabName, style: TextStyle(color: textColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 10, height: 1.0))),
    );
  }
}