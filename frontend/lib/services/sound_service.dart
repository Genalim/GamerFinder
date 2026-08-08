import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  // Використовуємо окремі плеєри, щоб нотифікації та повідомлення не блокували одне одного
  static final AudioPlayer _notificationPlayer = AudioPlayer();
  static final AudioPlayer _messagePlayer = AudioPlayer();

  // Ініціалізація аудіоконтексту для примусового відтворення через медіа-канал
  static Future<void> init() async {
    try {
      final AudioContext audioContext = AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.media, // Примусово через медіа-канал (гучність завжди на максимум)
          audioFocus: AndroidAudioFocus.none, // Не забирати фокус у музики
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
        ),
      );

      await AudioPlayer.global.setAudioContext(audioContext);
    } catch (e) {
      debugPrint("Помилка ініціалізації аудіоконтексту: $e");
    }
  }

  // Звук для сповіщень / інвайтів
  static Future<void> playNotification() async {
    try {
      await _notificationPlayer.stop(); // Зупиняємо попередній, якщо грав
      await _notificationPlayer.play(AssetSource('sounds/Notification.m4a'));
      debugPrint("🔊 Звук Notification успішно запущено");
    } catch (e) {
      debugPrint("Помилка звуку Notification: $e");
    }
  }

  // Звук для вхідного повідомлення у будь-якому чаті
  static Future<void> playIncomingMessage() async {
    try {
      await _messagePlayer.stop(); // Зупиняємо попередній, якщо грав
      await _messagePlayer.play(AssetSource('sounds/IncomingMessage.m4a'));
      debugPrint("🔊 Звук IncomingMessage успішно запущено");
    } catch (e) {
      debugPrint("Помилка звуку IncomingMessage: $e");
    }
  }
}