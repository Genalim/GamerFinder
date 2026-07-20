import 'package:flutter/material.dart';
import 'notifications_overlay.dart';
import 'custom_widgets.dart';
import 'user_session.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // Для json
import 'package:http/http.dart' as http; // Для http
import 'api_config.dart'; // Для ApiConfig
import 'new_chat_room_screen.dart';
import 'api_service.dart';
import 'subscription_screen.dart';
import 'Home_Feed_screen.dart';

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
        required BuildContext context,
        required Function(NotificationModel) onAccept,
        required Function(String) onRemove,
        required Function(NotificationModel) onDecline,
        required Function(int) onProfileTap,
        required VoidCallback onUpdate,

      }) {
    if (item.state == NotificationState.accepted) return _buildChatAcceptedCard(item, onRemove, onProfileTap, context);
    if (item.state == NotificationState.declined) return _buildDeclinedCard(item, onRemove, onProfileTap);
    if (item.type == NotificationType.rating) return _buildRatingCard(item, onRemove, onUpdate);
    if (item.type == NotificationType.pro) return _buildProCard(item, onRemove, context);

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
      Function(int) onProfileTap,
      BuildContext context,
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
              onTap: () async {
                // 1. Отримуємо ID поточного користувача
                final String myId = UserSession().currentUser?.id.toString() ?? '0';

                // 2. Логіка вибору:
                // Якщо senderId — це я, то ціль — recipientId.
                // АЛЕ якщо recipientId прийшов "0" (порожній), значить треба взяти senderId.
                String targetUserId = item.recipientId;
                if (targetUserId == "0" || targetUserId == "null") {
                  targetUserId = item.senderId;
                }

                // 3. ЗАХИСТ: якщо ми все ще намагаємося чатитись з самим собою — зупиняємось
                if (targetUserId == myId) {
                  print("ПОМИЛКА: Неможливо почати чат з самим собою (myId: $myId)");
                  return;
                }

                // 4. Тепер відправляємо запит з валідним ID
                final url = Uri.parse('${ApiConfig.baseUrl}/chats/get-or-create?recipient_id=$targetUserId');

                final response = await http.post(
                  url,
                  headers: await ApiService.getHeaders(),
                );

                if (response.statusCode == 200 && context.mounted) {
                  final data = json.decode(response.body);
                  final String chatId = data['chat_id'];

                  // 3. Перехід у чат
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        friendName: item.userNickname,
                        chatId: chatId,
                        friendId: targetUserId, // Передаємо правильний ID
                        onBack: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                } else {
                  print("Помилка чату: ${response.statusCode} - ${response.body}");
                }
              },
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
  // =========================================================================
  // ВКЛАДКА PRO КАРТКИ
  // =========================================================================

  Widget _buildProCard(NotificationModel item, Function(String) onRemove, BuildContext context) {
    switch (item.game) {
      case 'trial_available': return _buildProTrialAvailableCard(item, onRemove);
      case 'expiring': return _buildProExpiringCard(item, onRemove, context);
      case 'payment_failed': return _buildPaymentFailedCard(item, onRemove);
      case 'activated': return _buildProActivatedCard(item, onRemove);
      case 'expired': return _buildProExpiredCard(item, onRemove, context);
      default: return _buildDefaultProCard(item, onRemove);
    }
  }

  Widget _buildDefaultProCard(NotificationModel item, Function(String) onRemove) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF0085FF)), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text(item.message, style: const TextStyle(color: Colors.white)),
        const Spacer(),
        FigmaCloseButton(onTap: () => onRemove(item.id))
      ]),
    );
  }

  Widget _buildProTrialAvailableCard(NotificationModel item, Function(String) onRemove) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF181826), border: Border.all(color: const Color(0xFF0085FF), width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFF00F5A0)),
              const SizedBox(width: 6),
              const Text('PRO trial is available', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(formatTime(item.time), style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              // Хрестик для тріалу — одразу видаляє нотифікацію з бази і списку
              FigmaCloseButton(onTap: () async {
                final success = await ApiService.deleteNotification(item.id);
                if (success) {
                  onRemove(item.id);
                }
              }),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Try PRO for free for 7 days!', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _activateProTrial(item.id, onRemove),
            child: Container(
              width: 145, height: 25,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00F5A0), Color(0xFF0085FF)]), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: const Text('Activate', style: TextStyle(color: Color(0xFF0F0F1A), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProExpiringCard(NotificationModel item, Function(String) onRemove, BuildContext context) {
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
              const Icon(Icons.hourglass_bottom_rounded, size: 14, color: Color(0xFF0085FF)),
              const SizedBox(width: 6),
              const Text('Subscription expiring', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(formatTime(item.time), style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => onRemove(item.id)),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
              );
            },
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

  Widget _buildPaymentFailedCard(NotificationModel item, Function(String) onRemove) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
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
              const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 6),
              const Text('Payment failed', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(formatTime(item.time), style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9)),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => onRemove(item.id)),
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

  Widget _buildProActivatedCard(NotificationModel item, Function(String) onRemove) {
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
              // Той самий напис зверху зліва
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
                formatTime(item.time),
                style: const TextStyle(
                  color: Color(0xFF8E8EA9),
                  fontSize: 6,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              FigmaCloseButton(onTap: () => onRemove(item.id)),
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

  Widget _buildProExpiredCard(NotificationModel item, Function(String) onRemove, BuildContext context) {
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
                formatTime(item.time),
                style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 9, fontFamily: 'Inter'),
              ),
              const SizedBox(width: 8),
              FigmaCloseButton(onTap: () => onRemove(item.id)),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
              );
            },
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

  Future<void> _activateProTrial(String notificationId, Function(String) onRemove) async {
    try {
      final token = await UserSession.getToken();
      if (token == null) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/pro/activate');
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({"trial": true}),
      );

      if (response.statusCode == 200) {
        print("SUCCESS: PRO тріал активовано успішно!");

        // 1. Видаляємо картку тріалу зі списку сповіщень
        await ApiService.deleteNotification(notificationId);
        onRemove(notificationId);

        // 2. ПРАВИЛЬНЕ ОНОВЛЕННЯ: затягуємо свіжий профіль з сервера,
        // де бекенд вже встановив is_pro = true
        final userId = await UserSession.getUserId();
        if (userId != null) {
          final profileResponse = await http.get(
            Uri.parse("${ApiConfig.baseUrl}/users/$userId"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
          );

          if (profileResponse.statusCode == 200) {
            final data = json.decode(profileResponse.body);
            // Оновлюємо глобальну сесію свіжими даними з бази
            UserSession().currentUser = GamerProfile.fromJson(data);
          }
        }
      } else {
        print("ПОМИЛКА активації: ${response.body}");
      }
    } catch (e) {
      print("Помилка мережі при активації PRO: $e");
    }
  }

}