import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  // Звук для сповіщень / інвайтів
  static Future<void> playNotification() async {
    try {
      await _player.play(AssetSource('sounds/Notification.m4a'));
    } catch (e) {
      debugPrint("Помилка звуку Notification: $e");
    }
  }

  // Звук для вхідного повідомлення у будь-якому чаті
  static Future<void> playIncomingMessage() async {
    try {
      await _player.play(AssetSource('sounds/IncomingMessage.m4a'));
    } catch (e) {
      debugPrint("Помилка звуку IncomingMessage: $e");
    }
  }
}