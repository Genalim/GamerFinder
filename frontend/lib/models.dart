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
}