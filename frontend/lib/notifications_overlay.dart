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
  final DateTime time;
  final String game;
  final String senderId;
  final bool isSenderOnline;
  final bool isSenderPro;
  final double senderRating;
  final String recipientId;

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
    required this.recipientId,
  }) : state = state ?? NotificationState.pending;

  int currentRating = 0;
  bool isRated = false;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // 1. Отримуємо рядок з JSON
    String timeString = json['time'] ?? DateTime.now().toUtc().toIso8601String();

    // 2. Якщо в рядку немає 'Z' і немає '+', додаємо 'Z', щоб Dart сприйняв це як UTC
    if (!timeString.contains('Z') && !timeString.contains('+')) {
      timeString += 'Z';
    }

    // 3. Парсимо та переводимо в локальний час
    DateTime utcTime = DateTime.parse(timeString).toLocal();

    return NotificationModel(
      id: json['id'].toString(),
      userNickname: json['user_nickname'] ?? 'Unknown',
      message: json['message'] ?? '',
      type: _parseNotificationType(json['type']),
      state: _parseNotificationState(json['state']),
      time: utcTime,
      game: json['game'] ?? '',
      senderId: json['sender_id'].toString(),
      isSenderOnline: json['is_sender_online'] ?? false,
      isSenderPro: json['is_sender_pro'] ?? false,
      senderRating: (json['sender_rating'] as num?)?.toDouble() ?? 0.0,
      recipientId: (json['recipient_id'] ?? '0').toString(),
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
  final Function(List<String> ids, String tabName) onArchiveAll;
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
        mainAxisSize: MainAxisSize.min, // Колонка тепер стискається до вмісту
        children: [
          Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                  children: [
                    const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                    const Spacer(),
                    FigmaCloseButton(onTap: widget.onClose)
                  ]
              )
          ),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['Match', 'Rating', 'PRO', 'All'].map((t) => _buildFigmaTab(t)).toList()
              )
          ),
          const Divider(color: Color(0xFF2B2B3B), height: 1),

          // Тепер контент не розтягується примусово
          if (filtered.isEmpty)
            SizedBox(
              height: 146,
              child: Center(child: _buildFigmaEmptyState(context)),
            )
          else
            Flexible(
              child: ListView.builder(
                  shrinkWrap: true, // Дозволяє списку займати лише необхідну висоту
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return buildFigmaCard(
                      filtered[index],
                      context: context,
                      onAccept: widget.onAccept,
                      onRemove: (String id) async {
                        final item = widget.notifications.firstWhere((n) => n.id == id);

                        if (item.type == NotificationType.rating) {
                          // Просто видаляємо з UI (використовуємо твій метод, який ти вже створив)
                          _deleteRatingLocally(id);
                        } else {
                          // Стандартна логіка для матчів (викликаємо те, що прийшло з батька)
                          widget.onRemove(id);
                        }
                      },
                      onDecline: widget.onDecline,
                      onProfileTap: widget.onProfileTap,
                      onUpdate: () => setState(() {}),
                    );
                  }
              ),
            ),

          _buildArchiveAllButton(filtered),
        ],
      ),
    );
  }

  void _deleteRatingLocally(String id) {
    setState(() {
      widget.notifications.removeWhere((n) => n.id == id);
    });
  }

  Widget _buildArchiveAllButton(List<NotificationModel> filtered) {
    bool isListEmpty = filtered.isEmpty;
    bool isChecked = isListEmpty || _isArchiving;
    String text = isListEmpty ? 'Archived' : 'Archive all';

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10, right: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: isListEmpty ? null : () async {
              final List<String> idsToArchive = filtered.map((n) => n.id).toList();

              setState(() {
                _isArchiving = true;
                widget.notifications.removeWhere((n) => idsToArchive.contains(n.id));
              });

              try {
                // ПЕРЕДАЄМО ids ТА activeTab
                await widget.onArchiveAll(idsToArchive, widget.activeTab);
              } catch (e) {
                debugPrint("Помилка архівування: $e");
              } finally {
                if (mounted) setState(() => _isArchiving = false);
              }
            },
            child: Row(
              children: [
                Text(text, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 11)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 24, // Ставимо 24, бо твій новий SVG 24x24
                  height: 24,
                  child: Center(child: FigmaArchiveCheckbox(isChecked: isChecked)),
                ),
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
      height: 146,
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