class FriendItem {
  final String name;
  final String status;
  final String initial;
  final bool isOnline;

  FriendItem({
    required this.name,
    required this.status,
    required this.initial,
    this.isOnline = false
  });
}