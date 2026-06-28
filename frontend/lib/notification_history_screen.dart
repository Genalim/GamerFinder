import 'package:flutter/material.dart';
import 'notifications_overlay.dart'; // Щоб взяти NotificationModel
import 'api_service.dart';
import 'notification_cards_mixin.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with NotificationCardsMixin {
  List<NotificationModel> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    // В ApiService додайте метод getHistory()
    final data = await ApiService.getHistory();
    setState(() {
      _history = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('History', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w600,)),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiService.deleteAllHistory();
              _fetchHistory();
            },
            child: const Text('Delete All', style: TextStyle(color: Color(0xFFFF6B6B))),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F5A0)))
          : _history.isEmpty
          ? const Center(child: Text("History empty", style: TextStyle(color: Color(0xFF8E8EA9))))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          // Тут перевикористовуємо логіку з оверлею
          return _buildHistoryCard(item);
        },
      ),
    );
  }

  Widget _buildHistoryCard(NotificationModel item) {
    return buildFigmaCard(
      item,
      onAccept: (item) async {
        // Логіка прийняття (наприклад, перехід в чат)
        bool success = await ApiService.acceptGameInvite(item.id);
        if (success) _fetchHistory();
      },
      onRemove: (id) async {
        // АБО ApiService.deleteNotification(id) для повного видалення
        // АБО ApiService.archiveNotification(id), якщо ви хочете "подвійний архів"
        bool success = await ApiService.deleteNotification(id);
        if (success) _fetchHistory();
      },
      onDecline: (item) async {
        bool success = await ApiService.updateNotificationStatus(item.id, "declined");
        if (success) _fetchHistory();
      },
      onProfileTap: (int gamerId) {
        // Навігація до профілю
      },

      onUpdate: () {
          // В історії нам не обов'язково щось оновлювати UI,
          // бо картки там статичні, але колбек має бути переданий.
        if (mounted) setState(() {});}
    );
  }
}