import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'user_session.dart';
import 'notification_cards_mixin.dart';
import 'notification_history_screen.dart';
import 'package:flutter/gestures.dart';

enum NotificationType { match, rating, pro }
enum NotificationState { pending, accepted, declined, expired, matched }

class NotificationModel {
  final String id;
  final String userNickname;
  final String message;
  final NotificationType type;
  NotificationState state;
  final String time;
  final String game;
  final String senderId;
  final bool isSenderOnline;
  final bool isSenderPro;
  final double senderRating;

  NotificationModel({
    required this.id,
    required this.userNickname,
    required this.message,
    required this.type,
    NotificationState? state,
    required this.time,
    required this.game,
    required this.senderId,
    required this.isSenderOnline,
    required this.isSenderPro,
    required this.senderRating,
  }) : state = state ?? NotificationState.pending;

  int currentRating = 0;
  bool isRated = false;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'].toString(),
      userNickname: json['user_nickname'] ?? 'Unknown',
      message: json['message'] ?? '',
      type: _parseNotificationType(json['type']),
      state: _parseNotificationState(json['state']),
      time: json['time'] ?? '',
      game: json['game'] ?? '',
      senderId: json['sender_id'].toString(),
      isSenderOnline: json['is_sender_online'] ?? false,
      isSenderPro: json['is_sender_pro'] ?? false,
      senderRating: (json['sender_rating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'match': return NotificationType.match;
      case 'rating': return NotificationType.rating;
      case 'pro': return NotificationType.pro;
      default: return NotificationType.match;
    }
  }

  static NotificationState _parseNotificationState(String? state) {
    switch (state) {
      case 'pending': return NotificationState.pending;
      case 'accepted': return NotificationState.accepted;
      case 'declined': return NotificationState.declined;
      case 'expired': return NotificationState.expired;
      case 'matched': return NotificationState.matched;
      default: return NotificationState.pending;
    }
  }
}

class NotificationsOverlay extends StatefulWidget {
  final List<NotificationModel> notifications;
  final VoidCallback onClose;
  final Function(NotificationModel) onAccept;
  final Function(String) onRemove;
  final Function() onArchiveAll;
  final String activeTab;
  final Function(String) onTabChange;
  final Function(int) onProfileTap;
  final Function(NotificationModel) onDecline;

  const NotificationsOverlay({
    super.key,
    required this.notifications,
    required this.onClose,
    required this.onAccept,
    required this.onRemove,
    required this.onArchiveAll,
    required this.activeTab,
    required this.onTabChange,
    required this.onProfileTap,
    required this.onDecline,
  });

  @override
  State<NotificationsOverlay> createState() => _NotificationsOverlayState();
}

class _NotificationsOverlayState extends State<NotificationsOverlay> with NotificationCardsMixin {
  bool _isArchiving = false;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.notifications.where((n) {
      if (widget.activeTab == 'All') return true;
      if (widget.activeTab == 'Match' && n.type == NotificationType.match) return true;
      if (widget.activeTab == 'Rating' && n.type == NotificationType.rating) return true;
      if (widget.activeTab == 'PRO' && n.type == NotificationType.pro) return true;
      return false;
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 730),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: Row(children: [const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter')), const Spacer(), FigmaCloseButton(onTap: widget.onClose)])),
          Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['Match', 'Rating', 'PRO', 'All'].map((t) => _buildFigmaTab(t)).toList())),
          const Divider(color: Color(0xFF2B2B3B), height: 1),
          Flexible(
            child: filtered.isEmpty
                ? _buildFigmaEmptyState(context)
                : ListView.builder(
                shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                itemCount: filtered.isNotEmpty ? filtered.length + 1 : filtered.length,
                itemBuilder: (context, index) {
                  if (filtered.isNotEmpty && index == filtered.length) {
                    return _buildArchiveAllButton(); // Показуємо лише якщо є що архівувати
                  }
                  return buildFigmaCard(
                    filtered[index],
                    onAccept: widget.onAccept,
                    onRemove: widget.onRemove,
                    onDecline: widget.onDecline,
                    onProfileTap: widget.onProfileTap,
                    onUpdate: () => setState(() {}),
                  );
                }
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
            onTap: () async {
              setState(() => _isArchiving = true);
              try {
                await widget.onArchiveAll();
              } catch (e) {
                // Обробка помилки, якщо сервер не відповів
                debugPrint("Помилка архівування: $e");
              } finally {
                // Скидаємо стан, щоб пташка не залишалася "затиснутою" назавжди
                if (mounted) {
                  setState(() => _isArchiving = false);
                }
              }
            },
            child: Row(
              children: [
                const Text('Archive all', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 11, fontFamily: 'Inter')),
                const SizedBox(width: 6),
                // Пташка тепер реагує на стан
                FigmaArchiveCheckbox(isChecked: _isArchiving),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFigmaTab(String tabName) {
    final isSelected = widget.activeTab == tabName;
    Decoration decoration;
    Color textColor;

    switch (tabName) {
      case 'Match':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0).withOpacity(0.4);
        decoration = BoxDecoration(
            color: isSelected ? const Color(0xFF00F5A0) : const Color(0xFF00F5A0).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8));
        break;
      case 'Rating':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFFD8FF2C).withOpacity(0.4);
        decoration = BoxDecoration(
            color: isSelected ? const Color(0xFFD8FF2C) : const Color(0xFFD8FF2C).withOpacity(0.06),
            borderRadius: BorderRadius.circular(8));
        break;
      case 'PRO':
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFF00F5A0).withOpacity(0.4);
        decoration = BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: isSelected ? const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0085FF)]) : null,
            color: isSelected ? null : const Color(0xFF0085FF).withOpacity(0.08));
        break;
      case 'All':
      default:
        textColor = isSelected ? const Color(0xFF0F0F1A) : const Color(0xFFD05AFF).withOpacity(0.4);
        decoration = BoxDecoration(
            color: isSelected ? const Color(0xFFD05AFF) : const Color(0xFFD05AFF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8));
        break;
    }

    return GestureDetector(
      onTap: () => widget.onTabChange(tabName),
      child: Container(
        width: 73,
        height: 20,
        alignment: Alignment.center,
        decoration: decoration,
        child: Text(
          tabName,
          style: TextStyle(
              color: textColor,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 10,
              height: 1.0
          ),
        ),
      ),
    );
  }


// Допоміжний метод для крапки між даними
  Widget _buildDot() => Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 6), decoration: const BoxDecoration(color: Color(0xFF3B3B4B), shape: BoxShape.circle));

  Widget _buildFigmaEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 126,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B2B3B), width: 0.5),
      ),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color.fromRGBO(255, 255, 255, 0.7),
            ),
            children: [
              const TextSpan(text: "Your recent notifications were moved to "),
              TextSpan(
                text: "History",
                style: const TextStyle(
                  color: Color(0xFF00F5A0), // Зелений колір як лінк
                  fontWeight: FontWeight.w600,
                  fontSize: 14, // Трохи більший розмір, як у вашому ТЗ
                ),
                // Обробка натискання на "History"
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HistoryScreen()),
                    );
                  },
              ),
            ],
          ),
        ),
      ),
    );
  }
}