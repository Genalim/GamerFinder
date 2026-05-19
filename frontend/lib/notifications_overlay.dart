import 'package:flutter/material.dart';
import 'custom_widgets.dart'; // Наш файл з усіма кастомними SVG та іконками

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
  bool _allArchived = false;

  final List<NotificationModel> _notifications = [
    // Матчі (6 шт)
    NotificationModel(id: '1', userNickname: 'NOVA', message: 'invited you to play Valorant', type: NotificationType.match, state: NotificationState.pending, time: '5s ago', game: 'Valorant'),
    NotificationModel(id: '6', userNickname: 'NOVA', message: 'You matched with', type: NotificationType.match, state: NotificationState.pending, time: '15m ago', game: 'Valorant'),
    NotificationModel(id: '2', userNickname: 'MMA_boxer', message: 'has accepted your invitation to', type: NotificationType.match, state: NotificationState.pending, time: '15m ago', game: 'Dota 2'),
    NotificationModel(id: '3', userNickname: 'NOVA', message: 'How was your game with NOVA?', type: NotificationType.rating, state: NotificationState.pending, time: '5s ago'),
    NotificationModel(id: '4', userNickname: 'Mario_gamer', message: 'has declined your invitation to', type: NotificationType.match, state: NotificationState.pending, time: '22 Feb 2026', game: 'SMITE'),
    NotificationModel(id: '5', userNickname: 'NOVA', message: 'The invitation has expired.', type: NotificationType.match, state: NotificationState.pending, time: '5m ago', game: 'Valorant'),

    // PRO (5 шт) з унікальними ID
    NotificationModel(id: 'pro_1', message: 'Try PRO for free for 7 days!', type: NotificationType.pro, state: NotificationState.pending, time: '5 sec ago'),
    NotificationModel(id: 'pro_2', message: 'Your PRO plan expires in 2 days!', type: NotificationType.pro, state: NotificationState.pending, time: '18h ago'),
    NotificationModel(id: 'pro_3', message: 'Your PRO subscription could not be renewed.', type: NotificationType.pro, state: NotificationState.pending, time: '5 days ago'),
    NotificationModel(id: 'pro_4', message: 'Welcome to PRO!', type: NotificationType.pro, state: NotificationState.pending, time: '2h ago'),
    NotificationModel(id: 'pro_5', message: 'Sorry... Your PRO subscription has ended.', type: NotificationType.pro, state: NotificationState.pending, time: '5 sec ago'),
  ];



  void _removeNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    const double maxOverlayHeight = 730.0;

    final filtered = _allArchived
        ? <NotificationModel>[]
        : _notifications.where((n) {
      // Якщо статус НЕ pending (тобто declined або accepted), картка зникає зі списку
      if (n.state != NotificationState.pending) return false;

      if (_activeNotificationTab == 'All') return true;
      if (_activeNotificationTab == 'Match' && n.type == NotificationType.match) return true;
      if (_activeNotificationTab == 'Rating' && n.type == NotificationType.rating) return true;
      if (_activeNotificationTab == 'PRO' && n.type == NotificationType.pro) return true;
      return false;
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: maxOverlayHeight),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFigmaTab('Match'),
                const SizedBox(width: 8),
                _buildFigmaTab('Rating'),
                const SizedBox(width: 8),
                _buildFigmaTab('PRO'),
                const SizedBox(width: 8),
                _buildFigmaTab('All'),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2B2B3B), height: 1),

          Flexible(
            child: _allArchived
                ? _buildFigmaEmptyState()
                : filtered.isEmpty
                ? _buildSimpleEmptyState()
                : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
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
          Positioned(
            right: 12,
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Inbox cleared',
                  style: TextStyle(color: Color(0xFF8E8EA9), fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6), // Зробили відступ трішки компактнішим

                // НАША НОВА ОФІЦІЙНА SVG ІКОНКА З FIGMA
                const FigmaInboxClearedIcon(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleEmptyState() {
    return Container(
      width: double.infinity,
      height: 126,
      margin: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 0.5),
      ),
      child: const Center(
        child: Text(
          'No notifications found',
          style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildArchiveAllButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8, right: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: [
          GestureDetector(
            onTap: () => setState(() => _allArchived = !_allArchived), // Перемикаємо стан для тесту
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                    'Archive all',
                    style: TextStyle(
                        color: Color(0xFF8E8EA9),
                        fontSize: 11,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500
                    )
                ),
                const SizedBox(width: 6),

                // Викликаємо наш красивий SVG-чекбокс з файлу custom_widgets.dart
                FigmaArchiveCheckbox(
                  isChecked: _allArchived, // Передаємо поточний стан (true/false)
                ),
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
  // ВКЛАДКА PRO (ОПТИМІЗОВАНА ВИСОТА ТА КОЛЬОРИ ДНІВ)
  // =========================================================================

  // 1. PRO trial is available
  Widget _buildProTrialAvailableCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Притиснув висоту
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF0085FF), width: 0.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const RadialGradient(
                  colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                ).createShader(bounds),
                child: const Icon(Icons.star_rounded, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 4),
              const Text(
                'PRO trial is available',
                style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 6, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)), // Повернув кастомний хрестик
            ],
          ),
          const SizedBox(height: 0), // Менше відступ
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w400),
              children: [
                TextSpan(text: 'Try PRO for free for ', style: TextStyle(color: Color(0xFFB8B8C6))),
                TextSpan(text: '7 days!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), // Дні білі
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Unlock advanced filters and unlimited matches.',
            style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w400),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8), // Менше відступ
          GestureDetector(
            onTap: () => print('Activate PRO Trial'),
            child: Container(
              width: 145,
              height: 25,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Activate',
                style: TextStyle(color: Color(0xFF0F0F1A), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. PRO trial expires in 2 days
  Widget _buildProExpiringCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6), // Компактний відступ
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), // Компактна висота
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
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Icon(Icons.hourglass_bottom_rounded, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 6),
              const Text(
                'Subscription expiring',
                style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 6, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)),
            ],
          ),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w400),
              children: [
                TextSpan(text: 'Your PRO plan expires in ', style: TextStyle(color: Color(0xFFB8B8C6))),
                TextSpan(text: '2 days!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // КНОПКА З ГРАДІЄНТНОЮ РАМКОЮ
          GestureDetector(
            onTap: () => print('Renew subscription'),
            child: Container(
              width: 145,
              height: 25,
              padding: const EdgeInsets.all(0.5), // Товщина рамки (0.5px як у Figma)
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF181826), // Внутрішній фон картки, що перекриває градієнт
                  borderRadius: BorderRadius.circular(9.5), // Трохи менший радіус для внутрішнього шару
                ),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                  ).createShader(bounds),
                  child: const Text(
                    'Renew subscription',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Payment failed
  Widget _buildPaymentFailedCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFFFF6B6B), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 6),
              const Text(
                'Payment failed',
                style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 6, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)), // Кастомний хрестик
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Your PRO subscription could not be renewed.',
            style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w400),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => print('Update payment method'),
            child: Container(
              width: 145,
              height: 25,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFF6B6B), width: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Update payment method',
                style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w500, letterSpacing: -0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. PRO activated
  Widget _buildProActivatedCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
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
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Icon(Icons.thumb_up_outlined, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 6),
              const Text(
                'PRO activated',
                style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 6, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)), // Кастомний хрестик
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to ',
                style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w400),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0066FF), Color(0xFF00F5A0)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w700, height: 0.8),
                ),
              ),
              const Text(
                ' ! Enjoy advanced filters.',
                style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 5. PRO expired
  Widget _buildProExpiredCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Притиснув висоту
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
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00F5A0), Color(0xFF0085FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Icon(Icons.electric_bolt_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 6),
              const Text(
                'PRO expired',
                style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 6, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)), // Кастомний хрестик
            ],
          ),
          const SizedBox(height: 0),
          const Text(
            'Sorry... Your PRO subscription has ended.',
            style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w400),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => print('Reactivate PRO'),
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
              child: const Text(
                'Activate',
                style: TextStyle(color: Color(0xFF0F0F1A), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // СТАРІ КАРТКИ (ОПТИМІЗОВАНІ ТА ВИПРАВЛЕНІ)
  // =========================================================================

  // КАРТКА MATCH: PLAY INVITE (Виправлено колір тексту)
  Widget _buildMatchInviteCard(NotificationModel item, {required bool isExpired}) {
    final Color borderColor = isExpired ? const Color(0xFF8E8EA9) : const Color(0xFF00F5A0);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6), // Зменшили простір між картками (було 12)
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Компактніші відступи (було 12)
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
              FigmaCloseButton(onTap: () => _removeNotification(item.id)), // Кастомний хрестик
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
                // ТУТ ЗМІНА: Додали клікабельність для Decline
                Expanded(
                  child: GestureDetector(
                    onTap: isExpired
                        ? null
                        : () {
                      setState(() {
                        final index = _notifications.indexWhere((n) => n.id == item.id);
                        if (index != -1) {
                          _notifications[index] = NotificationModel(
                            id: item.id,
                            userNickname: item.userNickname,
                            message: item.message,
                            type: item.type,
                            state: NotificationState.declined, // Тихо відправляємо в історію
                            time: item.time,
                            game: item.game,
                            platform: item.platform,
                            mode: item.mode,
                            language: item.language,
                          );
                        }
                      });
                      print('Notification ${item.id} declined silently');
                    },
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

  // КАРТКА RATING (Виправлено відступи та колір гравця)
  Widget _buildRatingCard(NotificationModel item) {
    Color buttonColor = (item.isRated || item.currentRating > 0) ? const Color(0xFFD8FF2C) : const Color(0xFF6B6B80);
    String buttonText = item.isRated ? 'Rated' : 'Rate now';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ТУТ ЗМІНА: Притиснув паддінги
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFFD8FF2C), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const FigmaRatingStar(isFilled: true, size: 11),
              const SizedBox(width: 6),
              const Text('Rate your last teammate', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)), // Кастомний хрестик
            ],
          ),
          const SizedBox(height: 6), // ТУТ ЗМІНА: Менший відступ
          // ТУТ ЗМІНА: Розбив на RichText, щоб підсвітити NOVA неоновим зеленим
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
              children: [
                const TextSpan(text: 'How was your game with ', style: TextStyle(color: Color(0xFFB8B8C6))),
                TextSpan(text: '${item.userNickname}?', style: const TextStyle(color: Color(0xFF00F5A0), fontWeight: FontWeight.w600)), // Неоновий зелений
              ],
            ),
          ),
          const SizedBox(height: 8), // ТУТ ЗМІНА: Менший відступ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: item.isRated ? null : () => setState(() => item.currentRating = index + 1),
                    child: Padding(padding: const EdgeInsets.only(right: 4.0), child: FigmaRatingStar(isFilled: index < item.currentRating)),
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

  // КАРТКА MATCH: MATCH FOUND
  Widget _buildMutualMatchCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      height: 70,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF00F5A0), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_border, size: 12, color: Color(0xFF00F5A0)),
              const SizedBox(width: 6),
              const Text('Match found', style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: TextStyle(color: const Color(0xFF8E8EA9).withOpacity(0.75), fontSize: 9, fontFamily: 'Inter')),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)), // Кастомний хрестик
            ],
          ),
          Align(
            alignment: const Alignment(0.0, 0.2),
            child: RichText(
              text: TextSpan(children: [
                const TextSpan(text: 'You matched with ', style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 12, fontFamily: 'Inter')),
                TextSpan(text: item.userNickname, style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const Align(alignment: Alignment.bottomRight, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Start chat ', style: TextStyle(color: Color(0xDA00F5A0), fontSize: 12, fontWeight: FontWeight.w600)), FigmaArrowIcon()])),
        ],
      ),
    );
  }

  // КАРТКА MATCH: INVITE ACCEPTED
  Widget _buildChatAcceptedCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF00F5A0), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sentiment_satisfied, size: 14, color: Color(0xFF00F5A0)),
              const SizedBox(width: 6),
              const Text('Your play invite was accepted!', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)), // Кастомний хрестик
            ],
          ),
          const SizedBox(height: 10),
          RichText(text: TextSpan(children: [
            TextSpan(text: '${item.userNickname} ', style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 13, fontWeight: FontWeight.w600)),
            TextSpan(text: '${item.message.replaceAll(' ${item.game}', '')} ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            TextSpan(text: item.game, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.bottomRight, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Start chat ', style: TextStyle(color: Color(0xDA00F5A0), fontSize: 13, fontWeight: FontWeight.w600)), FigmaArrowIcon()]))
        ],
      ),
    );
  }

  // КАРТКА MATCH: INVITE DECLINED
  Widget _buildDeclinedCard(NotificationModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF00F5A0), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sentiment_very_dissatisfied, size: 14, color: const Color(0xFF00F5A0).withOpacity(0.7)),
              const SizedBox(width: 6),
              const Text('Your play invite was declined', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(item.time, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => _removeNotification(item.id)), // Кастомний хрестик
            ],
          ),
          const SizedBox(height: 10),
          RichText(text: TextSpan(children: [
            TextSpan(text: '${item.userNickname} ', style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 13, fontWeight: FontWeight.w600)),
            TextSpan(text: '${item.message.replaceAll(' ${item.game}', '')} ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            TextSpan(text: item.game, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
        ],
      ),
    );
  }

  Widget _buildDot() => Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 6), decoration: const BoxDecoration(color: Color(0xFFD9D9D9), shape: BoxShape.circle));

  Widget _buildHugeiconCheckmark() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00F5A0).withOpacity(0.7), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 2, top: 1),
              child: Icon(Icons.check, size: 14, color: const Color(0xFF00F5A0).withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaTab(String tabName) {
    final isSelected = _activeNotificationTab == tabName;
    Decoration decoration; Color textColor;
    switch (tabName) {
      case 'Match':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0).withOpacity(0.4);
        decoration = BoxDecoration(color: isSelected ? const Color(0xFF00F5A0) : const Color(0xFF00F5A0).withOpacity(0.08), borderRadius: BorderRadius.circular(8), boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF00F5A0).withOpacity(0.5), blurRadius: 6)] : null);
        break;
      case 'Rating':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFFD8FF2C).withOpacity(0.4);
        decoration = BoxDecoration(color: isSelected ? const Color(0xFFD8FF2C) : const Color(0xFFD8FF2C).withOpacity(0.06), borderRadius: BorderRadius.circular(8), boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFD8FF2C).withOpacity(0.5), blurRadius: 6)] : null);
        break;
      case 'PRO':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0).withOpacity(0.4);
        decoration = BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: isSelected ? const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0085FF)], begin: Alignment.centerRight, end: Alignment.centerLeft) : null, color: isSelected ? null : const Color(0xFF0085FF).withOpacity(0.08), boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF0085FF).withOpacity(0.5), blurRadius: 6)] : null);
        break;
      case 'All':
      default:
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFFD05AFF).withOpacity(0.4);
        decoration = BoxDecoration(color: isSelected ? const Color(0xFFD05AFF) : const Color(0xFFD05AFF).withOpacity(0.08), borderRadius: BorderRadius.circular(8), boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFD05AFF).withOpacity(0.5), blurRadius: 6)] : null);
        break;
    }
    return GestureDetector(
      onTap: () => setState(() => _activeNotificationTab = tabName),
      child: Container(width: 73, height: 20, alignment: Alignment.center, decoration: decoration, child: Text(tabName, style: TextStyle(color: textColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 10, height: 1.0))),
    );
  }
}