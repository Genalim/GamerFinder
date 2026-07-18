import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'api_service.dart';
import 'dart:math';
import 'custom_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'gamer_profile_screen.dart';
import 'user_session.dart';
import 'dart:ui';
import 'chat_add_friend_group_screen.dart';
import 'models.dart';
import 'services/chat_manager.dart';
import 'group_chat_room_screen.dart';

class ChatGroupInfoScreen extends StatefulWidget {
  final String chatId;

  const ChatGroupInfoScreen({super.key, required this.chatId});

  @override
  State<ChatGroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<ChatGroupInfoScreen> {
  Map<String, dynamic>? _groupData;
  bool _isLoading = true;
  final List<String> _backgrounds = ['1.webp', '2.webp', '3.webp'];
  late String _currentBg;
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isMuted = false;

  bool _isDialogVisible = false;
  String _dialogTitle = "";
  VoidCallback? _onConfirmDialog;

  List<FriendItem> _myFriends = [];



  bool isAdminMe(int memberId) {
    final myId = UserSession().currentUser?.id; // або твій спосіб отримати свій ID
    return memberId == myId;
  }

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _currentBg = _backgrounds[Random().nextInt(_backgrounds.length)];
    _fetchGroupInfo().then((_) {
      _nameController.text = _groupData?['name'] ?? "Group";
    });

    // Підписка через ChatManager
    ChatManager().socket?.on('user_left', _handleUserLeft);
  }

  void _handleUserLeft(dynamic data) {
    if (data['chat_id'] == widget.chatId) {
      debugPrint("DEBUG: Користувач вийшов, оновлюю список...");
      _fetchGroupInfo();
    }
  }

  @override
  void dispose() {
    // Відписка через ChatManager
    ChatManager().socket?.off('user_left', _handleUserLeft);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/friends/list'),
        headers: await ApiService.getHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _myFriends = data.map((f) => FriendItem.fromJson(f)).toList();
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження друзів: $e");
    }
  }

  Future<void> _fetchGroupInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/${widget.chatId}/info'),
        headers: await ApiService.getHeaders(),
      );
      if (response.statusCode == 200) {
        setState(() {
          _groupData = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження інфо: $e");
    }
  }

  Future<void> _deleteGroup() async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/group_chats/${widget.chatId}'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        // Повертаємось на головний екран чатів після видалення
        Navigator.of(context).pop(); // Закрити інфо
        Navigator.of(context).pop(); // Закрити чат
      } else {
        debugPrint("Помилка видалення: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Помилка при видаленні групи: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Color(0xFF0F0F13),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF00F5A0))));
    }

    // Фон тепер існує ВЗАГАЛІ без прив'язки до Scaffold
    return Stack(
      children: [
        // 1. ФОН (малюєтся один раз і не знає про існування клавіатури)
        Image.asset(
          'assets/ChatBackground/$_currentBg',
          fit: BoxFit.cover,
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
        ),
        Container(color: const Color(0xFF0F0F13).withOpacity(0.7)),

        // 2. SCUFFOLD (тепер це лише "прозора плівка" з контентом)
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            if (_isEditingName) setState(() => _isEditingName = false);
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildGroupAvatar(),
                  _buildActionIcons(),
                  const SizedBox(height: 20),
                  Expanded(child: _buildMembersList()),
                ],
              ),
            ),
          ),
        ),

        // 3. ДІАЛОГ
        if (_isDialogVisible)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.2),
                child: Center(child: _buildCustomDialog()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final int memberCount = _groupData!['members']?.length ?? 0;
    final bool isMeAdmin = _groupData!['is_me_admin'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(onTap: () => Navigator.pop(context), child: const ChatBackIcon(size: 24)),

          // Колонка з назвою
          Column(
            children: [
              GestureDetector(
                onTap: isMeAdmin ? () => setState(() => _isEditingName = true) : null,
                child: _isEditingName
                    ? SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    autofocus: true,
                    textAlign: TextAlign.center,
                    cursorColor: const Color(0xFF00F5A0), // Колір курсора
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00F5A0))),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) _updateGroupName(value);
                      setState(() => _isEditingName = false);
                    },
                  ),
                )
                    : Text(
                  _nameController.text,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Text("$memberCount members | 1 online", style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 12)),
            ],
          ),

          // Корзина
          GestureDetector(
            onTap: () {
              if (isMeAdmin) {
                setState(() {
                  _dialogTitle = "Are you sure you want to delete this group?";
                  _onConfirmDialog = () => _deleteGroup();
                  _isDialogVisible = true;
                });
              }
            },
            child: const SizedBox(
              width: 36, // Фіксований розмір контейнера
              height: 36,
              child: FittedBox(
                child: FigmaTrashIcon(size: 36, color: Color(0xFFFF6B6B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    final members = _groupData!['members'] as List<dynamic>;
    final adminId = _groupData!['admin_id'];

    return Column(
      children: [
        const Padding(padding: EdgeInsets.all(8.0), child: Text("Members", style: TextStyle(color: Colors.white))),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final bool isAdmin = member['is_admin'] == true;
              final String initial = (member['nickname']?.isNotEmpty ?? false)
                  ? member['nickname'][0].toUpperCase() : '?';

              return Container(
                height: 48,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF181826),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Аватарка
                    GestureDetector(
                      onTap: () => GamerProfileScreen.openFromId(context, member['id'].toString()),
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF00F5A0).withOpacity(0.4), width: 1)),
                        child: ClipOval(child: buildAvatar(member['avatar'], initial, 24)),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Нікнейм
                    Expanded(
                      child: GestureDetector(
                        onTap: () => GamerProfileScreen.openFromId(context, member['id'].toString()),
                        child: Text(member['nickname'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ),

                    // Напис "Admin" - завжди фіксований відступ
                    if (isAdmin)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("Admin", style: TextStyle(color: Color(0xFF00F5A0), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    // МЕНЮ - тепер доступне, якщо я адмін (навіть для себе, щоб змінити права іншим)
                    if (_groupData!['is_me_admin'])
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Color(0xFF8E8EA9), size: 20),
                        color: const Color(0xFF181826),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        // onSelected тепер може бути порожнім, якщо ми використовуємо onTap всередині
                        onSelected: (String action) {},
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          // 1. Опція Admin
                          PopupMenuItem<String>(
                            value: isAdmin ? 'remove_admin' : 'make_admin',
                            onTap: () => _handleAction(member['id'], isAdmin ? 'remove_admin' : 'make_admin'),
                            child: Text(
                              isAdmin ? "Remove Admin" : "Make Admin",
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          // 2. Опція видалення (з викликом діалогу)
                          PopupMenuItem<String>(
                            value: 'delete',
                            onTap: () {
                              setState(() {
                                _dialogTitle = "Are you sure you want to remove ${member['nickname']} from the group?";
                                _onConfirmDialog = () => _handleAction(member['id'], 'delete');
                                _isDialogVisible = true;
                              });
                            },
                            child: const Text(
                              "Remove Member",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdminOptions() {
    return Column(
      children: [
        const Divider(color: Color(0xFF2B2B3B)),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF00F5A0)),
          title: const Text("Change admin", style: TextStyle(color: Color(0xFF00F5A0))),
          onTap: () { /* логіка зміни адміна */ },
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text("Delete group", style: TextStyle(color: Colors.red)),
          onTap: () { /* логіка видалення групи */ },
        ),
      ],
    );
  }

  Widget buildAvatar(String? avatarUrl, String initial, double size) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildLetterAvatar(initial, size); // Тепер 2 аргументи!
    }

    if (avatarUrl.startsWith('http')) {
      return Image.network(
        avatarUrl,
        width: size, height: size,
        fit: BoxFit.cover, // <--- Це змушує картинку заповнити весь контейнер
        errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial, size),
      );
    }

    return Image.asset(
      avatarUrl,
      width: size, height: size,
      fit: BoxFit.cover, // <--- Це змушує картинку заповнити весь контейнер
      errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(initial, size),
    );
  }

  Widget _buildLetterAvatar(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Color(0xFF0F0F13), shape: BoxShape.circle),
      child: Center(
        child: Text(
            initial,
            style: TextStyle(
                fontFamily: 'Love Light',
                fontSize: size * 0.7, // <--- Тут головний секрет: шрифт стає пропорційним розміру!
                color: const Color(0xFF00F5A0)
            )
        ),
      ),
    );
  }

  Widget _buildGroupAvatar() {
    final members = _groupData!['members'] as List<dynamic>;
    final bool isMeAdmin = _groupData!['is_me_admin'] == true;
    final String? avatarUrl = _groupData!['avatar_url'];

    return GestureDetector(
      onTap: isMeAdmin ? _handleAvatarTap : null,
      child: Container(
        width: 100,
        height: 100,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          // Якщо є аватарка — просто показуємо її на весь розмір (100x100)
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? Image.network(avatarUrl, fit: BoxFit.cover)
              : _buildAvatarGrid(members.take(4).toList()),
        ),
      ),
    );
  }

  Widget _buildAvatarGrid(List<dynamic> members) {
    final displayMembers = members.take(4).toList();

    return Center(
      child: SizedBox(
        width: 90,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: displayMembers.map((m) {
            final String initial = (m['nickname']?.isNotEmpty ?? false) ? m['nickname'][0].toUpperCase() : '?';

            // Базовий розмір аватара
            final double avatarSize = displayMembers.length == 1 ? 80 : 38;
            // Контейнер з рамкою трохи більший за аватар
            final double containerSize = displayMembers.length == 1 ? 84 : 36;

            return Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00F5A0).withOpacity(0.4), width: 1.5),
              ),
              // Центруємо аватарку всередині
              alignment: Alignment.center,
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: ClipOval(
                  child: buildAvatar(m['avatar'], initial, avatarSize),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _handleAvatarTap() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        maxWidth: 512,
        maxHeight: 512,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Примусовий квадрат
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 70,
      );

      if (croppedFile != null) {
        _uploadAvatar(croppedFile);
      }
    }
  }

  Widget _buildActionIcons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isMuted = !_isMuted;
              });
            },
            child: _buildActionIcon(
              _isMuted ? Icons.mic_off : Icons.mic,
              _isMuted ? "Unmute" : "Mute",
              color: _isMuted ? const Color(0xFF8E8EA9) : const Color(0xFF00F5A0),
            ),
          ),
          GestureDetector(
            onTap: () {
              // Navigator.pop повертає результат 'open_search'
              Navigator.pop(context, 'open_search');
            },
            child: _buildActionIconWidget(const FigmaSearchIcon(), "Search", size: 45),
          ),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatAddFriendsGroupScreen(
                    onClose: () => Navigator.pop(context),
                    currentFriendName: UserSession().currentUser?.nickname ?? "ME",
                    friendsList: _myFriends, // <-- Тепер тут є дані!
                    chatId: widget.chatId,
                    existingMemberIds: (_groupData!['members'] as List)
                        .map((m) => m['id'] as int)
                        .toList(),
                  ),
                ),
              );
              if (result == true) _fetchGroupInfo();
            },
            child: _buildActionIconWidget(const ChatAddGroupIcon(), "Add friends", size: 45),
          ),
          // Тепер викликаємо універсальний діалог:
          GestureDetector(
            onTap: () {
              setState(() {
                _dialogTitle = "Are you sure you want to leave this group?";
                _onConfirmDialog = () => _leaveGroup();
                _isDialogVisible = true;
              });
            },
            child: _buildActionIconWidget(const FigmaExitIcon(), "Leave group", size: 45),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAvatar(CroppedFile croppedFile) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/group_chats/${widget.chatId}/avatar');
      var request = http.MultipartRequest('POST', uri);

      // Додаємо заголовки
      request.headers.addAll(await ApiService.getHeaders());

      // Додаємо файл
      request.files.add(await http.MultipartFile.fromPath('file', croppedFile.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        debugPrint("Аватар оновлено!");
        _fetchGroupInfo(); // Перезавантажуємо дані групи
      }
    } catch (e) {
      debugPrint("Помилка завантаження: $e");
    }
  }

  Future<void> _updateGroupName(String newName) async {
    try {
      // ЗМІНЕНО: тепер шлях /group_chats/
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/group_chats/${widget.chatId}/name'),
        headers: await ApiService.getHeaders(),
        body: json.encode({"name": newName}),
      );

      if (response.statusCode == 200) {
        debugPrint("Назву оновлено!");
        _fetchGroupInfo();
      }
    } catch (e) {
      debugPrint("Помилка зміни назви: $e");
    }
  }

  Widget _buildActionIcon(IconData icon, String label, {Color color = Colors.white}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 45), // Тепер колір динамічний
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12), // Текст також змінює колір
        ),
      ],
    );
  }

  Widget _buildActionIconWidget(Widget iconWidget, String label, {double size = 33.0}) {
    return Column(
        children: [
          // Тут ми використовуємо SizedBox для обмеження області
          // А iconWidget (твоя SVG) має бути "гнучкою"
          SizedBox(
            width: size,
            height: size,
            child: FittedBox( // FittedBox змусить SVG заповнити весь простір 50x50
              fit: BoxFit.contain,
              child: iconWidget,
            ),
          ),
          const SizedBox(height: 8), // Можна додати трохи відступу, якщо іконка велика
          Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12)
          )
        ]
    );
  }

  Future<void> _leaveGroup() async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/group_chats/${widget.chatId}/leave'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        // Повертаємось на головний екран чатів
        Navigator.of(context).pop(); // Закрити інфо
        Navigator.of(context).pop(); // Закрити чат
      }
    } catch (e) {
      debugPrint("Помилка при виході: $e");
    }
  }

  //Blur confirmation dialog.
  Future<void> _showConfirmDialog({
    required String title,
    required VoidCallback onConfirm,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Confirmation",
      // Змінюємо колір бар'єру на напівпрозорий чорний для "світлішого" ефекту
      barrierColor: Colors.black.withOpacity(0.3),
      pageBuilder: (context, _, __) {
        return BackdropFilter(
          // Зменшуємо sigma для менш інтенсивного блюру
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none, // Обов'язково для тексту в оверлеї
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00F5A0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("NO", style: TextStyle(color: Color(0xFF00F5A0))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onConfirm();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F5A0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("YES", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  Future<void> _handleAction(int memberId, String action) async {
    final headers = await ApiService.getHeaders();
    String url = '${ApiConfig.baseUrl}/group_chats/${widget.chatId}/members/$memberId';

    try {
      if (action == 'make_admin') {
        await http.post(Uri.parse('$url/admin'), headers: headers);
      } else if (action == 'remove_admin') {
        await http.delete(Uri.parse('$url/admin'), headers: headers);
      } else if (action == 'delete') {
        await http.delete(Uri.parse(url), headers: headers);
      }
      _fetchGroupInfo(); // Оновлюємо інтерфейс
    } catch (e) { debugPrint("Помилка: $e"); }
  }

  Widget _buildCustomDialog() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _dialogTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 16,
              height: 1.25,
              color: Colors.white,
              decoration: TextDecoration.none, // Обов'язково, щоб прибрати підкреслення тексту
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isDialogVisible = false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00F5A0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("NO", style: TextStyle(color: Color(0xFF00F5A0))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _isDialogVisible = false);
                    _onConfirmDialog?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F5A0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("YES", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}