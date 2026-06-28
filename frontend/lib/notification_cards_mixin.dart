import 'package:flutter/material.dart';
import 'notifications_overlay.dart';
import 'custom_widgets.dart';
import 'user_session.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';

mixin NotificationCardsMixin {

  String formatTime(DateTime time) {
    try {
      //print("DEBUG: Time in model is: $time");
      //print("DEBUG: Timezone offset is: ${time.timeZoneOffset}");
      // Форматуємо як dd-MM-yyyy HH:mm
      return DateFormat('dd-MM-yyyy HH:mm').format(time);
    } catch (e) {
      return time.toString();
    }
  }

  // Цей метод ми залишаємо, щоб у самому оверлеї було зручно викликати картки
  Widget buildFigmaCard(
      NotificationModel item, {
        required Function(NotificationModel) onAccept,
        required Function(String) onRemove,
        required Function(NotificationModel) onDecline,
        required Function(int) onProfileTap,
        required VoidCallback onUpdate,

      }) {
    if (item.state == NotificationState.accepted) return _buildChatAcceptedCard(item, onRemove, onProfileTap);
    if (item.state == NotificationState.declined) return _buildDeclinedCard(item, onRemove, onProfileTap);
    if (item.type == NotificationType.rating) return _buildRatingCard(item, onRemove, onUpdate);
    if (item.type == NotificationType.pro) return _buildProCard(item, onRemove);

    return _buildMatchInviteCard(
      item,
      isExpired: item.state == NotificationState.expired,
      onAccept: onAccept,
      onRemove: onRemove,
      onProfileTap: onProfileTap,
      onDecline: onDecline,
    );
  }

  // --- ВАШІ МЕТОДИ 1 В 1 ---

  Widget _buildMatchInviteCard(NotificationModel item, {required bool isExpired, required Function(NotificationModel) onAccept, required Function(String) onRemove, required Function(int) onProfileTap, required Function(NotificationModel) onDecline}) {
    final Color borderColor = isExpired ? const Color(0xFF8E8EA9) : const Color(0xFF00F5A0);
    final String statusText = item.isSenderOnline ? 'Online now' : 'Offline';
    final bool amIPro = UserSession().currentUser?.isPro ?? false;
    final String timeLabel = isExpired ? "Expired" : "Invite expires in 10 min";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF0F0F1A), border: Border.all(color: borderColor, width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.sports_esports, size: 14, color: borderColor),
              const SizedBox(width: 6),
              const Text('Play invite', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter')),
              const Spacer(),
              // Тепер час іде першим (ближче до центру)
              Text(formatTime(item.time), style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              // Хрестик тепер крайній справа
              FigmaCloseButton(onTap: () => onRemove(item.id)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GestureDetector(
                onTap: () => onProfileTap(int.parse(item.senderId)),
                child: Text('${item.userNickname} ', style: TextStyle(color: borderColor, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (amIPro) ...[
                if (item.senderRating > 0) ...[
                  const Icon(Icons.star, color: Colors.amber, size: 11),
                  Text('${item.senderRating.toStringAsFixed(1)} ', style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ] else ...[
                const Icon(Icons.star, color: Colors.amber, size: 11),
                const Text('PRO only ', style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 8, fontWeight: FontWeight.w700)),
              ],
              const Text('invited you to play ', style: TextStyle(color: Color(0xFFB8B8C6), fontSize: 13)),
              Text(item.game, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(statusText, style: TextStyle(color: item.isSenderOnline ? const Color(0xFF00F5A0) : const Color(0xFF8E8EA9), fontSize: 11)),
          const SizedBox(height: 10),
          Text(timeLabel, style: TextStyle(color: isExpired ? Colors.red : const Color(0xFF8E8EA9), fontSize: 11)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: isExpired ? null : () => onDecline(item), // Блокуємо натискання
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                      border: Border.all(color: isExpired ? const Color(0xFF3B3B4B) : borderColor),
                      borderRadius: BorderRadius.circular(10)
                  ),
                  alignment: Alignment.center,
                  child: Text('Decline', style: TextStyle(color: isExpired ? const Color(0xFF3B3B4B) : borderColor)),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ACCEPT (Accept стає неактивним, якщо isExpired)
            Expanded(
              child: GestureDetector(
                onTap: isExpired ? null : () => onAccept(item), // Блокуємо натискання
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                      color: isExpired ? const Color(0xFF3B3B4B) : borderColor,
                      borderRadius: BorderRadius.circular(10)
                  ),
                  alignment: Alignment.center,
                  child: const Text('Accept', style: TextStyle(color: Color(0xFF0F0F1A), fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ])
        ],
      ),
    );
  }

  Widget _buildChatAcceptedCard(
      NotificationModel item,
      Function(String) onRemove,
      Function(int) onProfileTap
      ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF00F5A0), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF00F5A0)),
              const SizedBox(width: 6),
              const Text('Your Play Invite was accepted', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(formatTime(item.time), style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => onRemove(item.id)),
            ],
          ),
          const SizedBox(height: 10),
          // Рядок з ніком та назвою гри
          GestureDetector(
            onTap: () => onProfileTap(int.parse(item.senderId)),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.0, // line-height 10px / font-size 12px приблизно 0.83, але для тексту краще 1.0 або 1.2
                  letterSpacing: 0.6, // 5% від 12px = 0.6
                ),
                children: [
                  TextSpan(
                      text: '${item.userNickname} ',
                      style: const TextStyle(
                          color: Color(0xFF00F5A0),
                          fontWeight: FontWeight.w600
                      )
                  ),
                  const TextSpan(
                      text: 'accepted your invitation to ',
                      style: TextStyle(
                          color: Color(0xFFB8B8C6), // Трохи світліше, щоб не зливався
                          fontWeight: FontWeight.w400
                      )
                  ),
                  TextSpan(
                      text: item.game,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600
                      )
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Кнопка Start Chat
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () { /* TODO: Логіка чату */ },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Start chat', style: TextStyle(color: Color.fromRGBO(0, 245, 160, 0.85), fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF00F5A0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclinedCard(
      NotificationModel item,
      Function(String) onRemove,
      Function(int) onProfileTap
      ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: const Color(0xFF00F5A0), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, size: 14, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 6),
              const Text('Your Play Invite was declined', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(formatTime(item.time), style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => onRemove(item.id)),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => onProfileTap(int.parse(item.senderId)),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.0,
                  letterSpacing: 0.6,
                ),
                children: [
                  TextSpan(
                      text: '${item.userNickname} ',
                      style: const TextStyle(
                          color: Color(0xFFFF6B6B), // Червоний акцент для Declined
                          fontWeight: FontWeight.w600
                      )
                  ),
                  const TextSpan(
                      text: 'declined your invite to ',
                      style: TextStyle(
                          color: Color(0xFFB8B8C6),
                          fontWeight: FontWeight.w400
                      )
                  ),
                  TextSpan(
                      text: item.game,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600
                      )
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(NotificationModel item, Function(String) onRemove, VoidCallback onUpdate) {
    // Використовуємо локальний стан об'єкта item
    Color buttonColor = (item.currentRating > 0 && !item.isRated) ? const Color(0xFF00F5A0) : const Color(0xFF6B6B80);
    String buttonText = item.isRated ? 'Rated' : 'Update rating';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border.all(color: item.isRated ? const Color(0xFF8E8EA9) : const Color(0xFFD8FF2C), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const FigmaRatingStar(isFilled: true, size: 14),
              const SizedBox(width: 6),
              const Text('Rate your last teammate', style: TextStyle(color: Colors.white, fontSize: 11)),
              const Spacer(),
              Text(formatTime(item.time), style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => onRemove(item.id)),
            ],
          ),
          const SizedBox(height: 8),
          Text('How was your game with ${item.userNickname}?', style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    // Якщо вже оцінено - нічого не робимо
                    onTap: item.isRated ? null : () {
                      item.currentRating = index + 1;
                      onUpdate(); // <--- Викликаємо колбек замість setState
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FigmaRatingStar(isFilled: index < item.currentRating),
                    ),
                  );
                }),
              ),
              GestureDetector(
                onTap: (item.currentRating > 0 && !item.isRated)
                    ? () async {
                  // 1. Зберігаємо ID і миттєво оновлюємо UI (оптимістично)
                  final String idToRemove = item.id;

                  // Тимчасово ставимо Rated = true, щоб кнопка змінилася миттєво
                  item.isRated = true;
                  onUpdate();

                  // 2. Відправляємо рейтинг
                  final success = await ApiService.rateUser(int.parse(item.senderId), item.currentRating);

                  if (success) {
                    await ApiService.deleteNotification(idToRemove);

                    // викликаємо он ремув з оверлею, в якому робимо оновлення екрану.
                    onRemove(idToRemove);
                  } else {
                    // Якщо сервер помилився, повертаємо назад
                    item.isRated = false;
                    onUpdate();
                  }
                }
                    : null,
                child: Container(
                  width: 100, height: 25,
                  decoration: BoxDecoration(
                    border: Border.all(color: buttonColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(buttonText, style: TextStyle(color: buttonColor, fontSize: 11)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProCard(NotificationModel item, Function(String) onRemove) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF0085FF)), borderRadius: BorderRadius.circular(12)), child: Row(children: [Text(item.message, style: const TextStyle(color: Colors.white)), const Spacer(), FigmaCloseButton(onTap: () => onRemove(item.id))]));
}