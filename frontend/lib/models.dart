class FriendItem {
  final int id;
  final String name;
  final String status;
  final String initial;
  final bool isOnline;
  final String? avatarUrl;

  FriendItem({
    required this.id,
    required this.name,
    required this.status,
    required this.initial,
    this.isOnline = false,
    this.avatarUrl,
  });

  factory FriendItem.fromJson(Map<String, dynamic> json) {
    // Вкажіть ключі (наприклад, 'nickname', 'is_online'),
    // які реально приходять з вашого бекенду
    String name = json['nickname'] ?? 'User';

    return FriendItem(
      id: json['id'] ?? 0,
      name: name,
      status: json['status'] ?? '',
      initial: name.isNotEmpty ? name[0].toUpperCase() : '?',
      isOnline: json['is_online'] ?? false,
      avatarUrl: json['avatar'],
    );
  }

}