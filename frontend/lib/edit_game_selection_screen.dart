import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'custom_widgets.dart';
import 'api_config.dart';
import 'user_session.dart';
import 'Home_Feed_screen.dart';

class GameModel {
  final String id;
  final String? igdbId;
  final String name;
  final String imageUrl;
  final List<String> genres;
  final bool isFromApi;

  GameModel({
    required this.id,
    this.igdbId,
    required this.name,
    required this.imageUrl,
    required this.genres,
    this.isFromApi = false,
  });
}

class EditGameSelectionScreen extends StatefulWidget { // <--- Змінили назву
  const EditGameSelectionScreen({super.key});

  @override
  State<EditGameSelectionScreen> createState() => _EditGameSelectionScreenState(); // <--- І тут оновиться
}

class _EditGameSelectionScreenState extends State<EditGameSelectionScreen> {
  bool _isLoadingInitialGames = true;

  Future<void> _fetchGamesFromDB() async {
    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/games"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _games = data.map((json) {
            List<String> parsedGenres = [];
            try {
              var rawGenres = json['genres'];
              if (rawGenres != null) {
                if (rawGenres is String) {
                  // Декодуємо рядок у масив
                  var decoded = jsonDecode(rawGenres);
                  if (decoded is List) {
                    parsedGenres = decoded.map((e) => e.toString()).toList();
                  }
                } else if (rawGenres is List) {
                  parsedGenres = rawGenres.map((e) => e.toString()).toList();
                }
              }
            } catch (e) {
              debugPrint("Помилка парсингу жанрів для гри ${json['name']}: $e");
            }

            return GameModel(
              id: json['id'].toString(),
              igdbId: json['igdb_id']?.toString(),
              name: json['name'],
              imageUrl: json['image_url'] ?? '',
              genres: parsedGenres,
              isFromApi: false,
            );
          }).toList();

          _selectedGameIds = _games
              .where((g) => _selectedGames.contains(g.name))
              .map((g) => int.tryParse(g.id) ?? 0)
              .where((id) => id > 0)
              .toSet();

          _isLoadingInitialGames = false;
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження ігор з бази: $e");
      setState(() => _isLoadingInitialGames = false);
    }
  }

  final String _clientId = 'e8f46ha10ff5jvy6d0ysmgpw2kei32';
  final String _clientSecret = 'xwqcj3necpyerb7xxscnr227ekmqzj';
  String? _accessToken;

  late Set<String> _selectedGames;
  // Зберігаємо ID ігор, які вже є в базі або які вибираємо для бекенду
  late Set<int> _selectedGameIds;

  final List<String> _selectedGenres = [];
  final TextEditingController _searchController = TextEditingController();

  bool _isSearchDropdownOpen = false;
  bool _isFilterOpen = false;
  List<GameModel> _apiResults = [];
  bool _isLoadingApi = false;
  Timer? _debounce;

  List<GameModel> _games = [];

  final List<String> _genresList = [
    'Shooter', 'RPG', 'Strategy', 'Adventure', 'Action', 'Indie', 'RTS', 'TBS',
    'Card & Board', 'Tactical', 'Fighting', 'Simulator', 'Racing', 'Sport', 'Platform',
    'Horror', 'MOBA', 'Hack and slash', 'Arcade', 'Puzzle'];

  @override
  void initState() {
    super.initState();

    // 1. Ініціалізуємо вибрані ігри з поточної сесії юзера (щоб вони підсвітились)
    final currentUserGames = UserSession().currentUser?.gamesWithDetails ?? [];
    _selectedGames = currentUserGames.map((g) => g['name'] ?? '').where((n) => n.isNotEmpty).toSet();

    // 2. Також підтягуємо початкові ID ігор сесії
    final currentUserGameIds = currentUserGames.map((g) => int.tryParse(g['id'] ?? '0') ?? 0).where((id) => id > 0).toList();
    _selectedGameIds = Set<int>.from(currentUserGameIds);

    _fetchGamesFromDB();
  }

  Future<void> _getAccessToken() async {
    if (_accessToken != null) return;
    final url = Uri.parse('https://id.twitch.tv/oauth2/token'
        '?client_id=$_clientId'
        '&client_secret=$_clientSecret'
        '&grant_type=client_credentials');
    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
      }
    } catch (e) { debugPrint("Auth Error: $e"); }
  }

  String _clean(String text) => text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  void _onSearchChanged(String query) {
    setState(() {});
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.length <= 1) { _closeSearchDropdown(); return; }

    setState(() {
      _isSearchDropdownOpen = true;
    });

    _debounce = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      setState(() => _isLoadingApi = true);
      await _getAccessToken();
      if (_accessToken == null) { if (mounted) setState(() => _isLoadingApi = false); return; }
      try {
        final url = Uri.parse('https://api.igdb.com/v4/games');
        final body = 'search "$query"; fields name, cover.url, genres.name; where version_parent = null; limit 10;';
        final response = await http.post(url, headers: {'Client-ID': _clientId, 'Authorization': 'Bearer $_accessToken'}, body: body);
        if (response.statusCode == 200 && mounted) {
          final List data = json.decode(response.body);
          setState(() {
            _apiResults = data.map((json) {
              String? coverUrl = json['cover']?['url'];
              if (coverUrl != null) coverUrl = 'https:' + coverUrl.replaceAll('t_thumb', 't_cover_big');
              return GameModel(id: json['id'].toString(), name: json['name'], imageUrl: coverUrl ?? '', genres: (json['genres'] as List?)?.map((g) => g['name'].toString()).toList() ?? [], isFromApi: true);
            }).where((apiGame) => !_games.any((local) => local.name.toLowerCase() == apiGame.name.toLowerCase())).toList();
            _isLoadingApi = false;
          });
        }
      } catch (e) { debugPrint("API Error: $e"); if (mounted) setState(() => _isLoadingApi = false); }
    });
  }

  void _closeSearchDropdown() {
    if (mounted) {
      setState(() {
        _isSearchDropdownOpen = false;
        _apiResults = [];
        _isLoadingApi = false;
      });
    }
  }

  // Метод відправки оновлених ігор на бекенд
  Future<void> _applyChanges() async {
    try {
      final userId = await UserSession.getUserId();
      final token = await UserSession.getToken();
      if (userId == null) return;
      print("ОБРАНІ ID ІГОР ПЕРЕД ВІДПРАВКОЮ: $_selectedGameIds");

      // Збираємо список ID для відправки
      final List<int> gameIdsToSend = _selectedGameIds.toList();

      // Замість /register робимо запит на оновлення (наприклад, PUT /users/{id}/games або PATCH)
      // Вкажіть свій актуальний ендпоін для оновлення списку ігор юзера:
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/users/$userId/games"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: json.encode(_selectedGameIds.toList()),
      );

      if (response.statusCode == 200) {
        // Опціонально: оновлюємо локальний кеш профілю
        final updatedProfileResponse = await http.get(
          Uri.parse("${ApiConfig.baseUrl}/users/$userId"),
          headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
        );
        if (updatedProfileResponse.statusCode == 200) {
          final data = json.decode(updatedProfileResponse.body);
          setState(() {
            UserSession().currentUser = GamerProfile.fromJson(data);
          });
        }

        Navigator.pop(context); // Повертаємось на SettingsScreen після успішного збереження
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Не вдалося оновити ігри")),
        );
      }
    } catch (e) {
      debugPrint("Помилка збереження ігор: $e");
    }
  }

  @override
  void dispose() { _searchController.dispose(); _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00F5A0);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final normalizedSearch = _clean(_searchController.text);
    final filteredGames = _games.where((game) {
      final matchesSearch = _clean(game.name).contains(normalizedSearch);
      final matchesGenre = _selectedGenres.isEmpty || _selectedGenres.any((selected) => game.genres.any((gameGenre) => gameGenre.toLowerCase().contains(selected.toLowerCase())));
      return matchesSearch && matchesGenre;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { _closeSearchDropdown(); FocusScope.of(context).unfocus(); },
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: isLandscape ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAppBar(),
                      _buildSquadBar(accentColor),

                      const SizedBox(height: 2),
                      _buildSearchInput(),

                      if (_isSearchDropdownOpen) _buildSearchDropdownInline(),

                      const SizedBox(height: 12),
                      _buildFilterHeader(),
                      if (_isFilterOpen) _buildGenresOverlay(),

                      if (isLandscape)
                        _buildGamesGrid(filteredGames, accentColor, isLandscape)
                      else
                        SizedBox(
                          height: MediaQuery.of(context).size.height - 290,
                          child: _buildGamesGrid(filteredGames, accentColor, isLandscape),
                        ),

                      if (isLandscape) ...[
                        const SizedBox(height: 24),
                        _buildApplyButton(),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
              if (!isLandscape)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildApplyButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchDropdownInline() {
    return Container(
      width: 360,
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 160, minHeight: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00F5A0).withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoadingApi) const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Color(0xFF00F5A0), minHeight: 2),
          Flexible(
            child: _apiResults.isEmpty && !_isLoadingApi
                ? const Padding(padding: EdgeInsets.all(15), child: Text("No games found", style: TextStyle(color: Colors.white54)))
                : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _apiResults.length,
              separatorBuilder: (c, i) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final game = _apiResults[index];
                return ListTile(
                  leading: const Icon(Icons.public, color: Color(0xFF00F5A0), size: 18),
                  title: Text(game.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  onTap: () async {
                    final game = _apiResults[index];

                    try {
                      final response = await http.post(
                          Uri.parse("${ApiConfig.baseUrl}/ensure-game"),
                          headers: {"Content-Type": "application/json"},
                          body: json.encode({
                            "igdb_id": int.tryParse(game.id),
                            "name": game.name,
                            "image_url": game.imageUrl,
                            "genres": game.genres
                          })
                      );

                      if (response.statusCode == 200) {
                        final responseData = json.decode(response.body);
                        int gameId = responseData['id'];

                        setState(() {
                          if (!_selectedGameIds.contains(gameId)) {
                            _selectedGameIds.add(gameId);
                          }
                          if (!_games.any((g) => g.name == game.name)) {
                            _games.insert(0, game);
                            _selectedGames.add(game.name);
                          }
                          _searchController.clear();
                        });
                        _closeSearchDropdown();
                        FocusScope.of(context).unfocus();
                      }
                    } catch (e) {
                      debugPrint("Помилка: $e");
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadBar(Color accentColor) {
    if (_selectedGames.isEmpty) {
      return const SizedBox(height: 88, child: Center(child: Text("Your squad is empty. Add games!", style: TextStyle(color: Colors.white54, fontSize: 11))));
    }

    final List<GameModel> squad = _games.where((g) => _selectedGames.contains(g.name)).toList();

    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: squad.length,
        itemBuilder: (context, index) {
          final game = squad[index];
          return Container(
            margin: const EdgeInsets.only(right: 14),
            width: 64,
            child: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accentColor, width: 1.5)),
                      child: ClipOval(
                        child: (game.imageUrl.isNotEmpty && game.imageUrl.contains('http'))
                            ? Image.network(
                          game.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.gamepad, color: Colors.white24, size: 24),
                        )
                            : Image.asset(
                          'assets/images/game_images/${game.imageUrl}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.gamepad, color: Colors.white24, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 8.5)),
                  ],
                ),
                Positioned(
                  right: 0, top: 0,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedGames.remove(game.name);
                      int? gameId = int.tryParse(game.id);
                      if (gameId != null) _selectedGameIds.remove(gameId);
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(color: Color(0xFFFF3B5C), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 11),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 2),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
              onPressed: () {
                Navigator.pop(context); // Працює як Cancel, нічого не зберігаючи
              }
          ),
          const Expanded(child: Text('Edit Game Selection', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      width: 360, height: 48,
      decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF00F5A0), size: 20),
          Expanded(
            child: TextField(
              controller: _searchController,
              autocorrect: false,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(hintText: 'Search in global library', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
                onTap: () { _searchController.clear(); _onSearchChanged(''); _closeSearchDropdown(); },
                child: const Icon(Icons.close, color: Colors.white54, size: 20)
            )
          else const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    bool hasActiveSelection = _selectedGenres.isNotEmpty && !_selectedGenres.contains('All');
    return Center(
      child: GestureDetector(
        onTap: () {
          _closeSearchDropdown();
          FocusScope.of(context).unfocus();
          setState(() => _isFilterOpen = !_isFilterOpen);
        },
        child: Container(
          width: 360,
          height: 48,
          decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              const Icon(Icons.filter_list, color: Color(0xFF00F5A0), size: 20),
              Expanded(child: Text(hasActiveSelection ? _selectedGenres.join(', ') : 'Filter by genre', textAlign: TextAlign.center, style: TextStyle(color: hasActiveSelection ? Colors.white : Colors.white38, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (hasActiveSelection) GestureDetector(onTap: () { setState(() => _selectedGenres.clear()); }, child: const Icon(Icons.close, color: Colors.white54, size: 20)),

              Transform.rotate(
                angle: _isFilterOpen ? 1.571 : 0.0,
                child: Icon(
                  Icons.play_arrow,
                  color: _isFilterOpen ? const Color(0xFF00F5A0) : Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool hasSelectionStr(bool val) => val;

  Widget _buildGenresOverlay() {
    final displayGenres = _genresList.where((g) => g != 'All').toList();
    return Container(
      width: 360, padding: const EdgeInsets.symmetric(vertical: 4),
      child: GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 2.3),
        itemCount: displayGenres.length,
        itemBuilder: (context, index) {
          final genre = displayGenres[index];
          final isSelected = _selectedGenres.contains(genre);
          return GestureDetector(
            onTap: () => setState(() { if (isSelected) _selectedGenres.remove(genre); else _selectedGenres.add(genre); }),
            child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: isSelected ? const Color(0xFF00F5A0).withOpacity(0.2) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? const Color(0xFF00F5A0) : Colors.transparent)), child: Text(genre, style: TextStyle(color: isSelected ? const Color(0xFF00F5A0) : Colors.white70, fontSize: 9))),
          );
        },
      ),
    );
  }

  Widget _buildGamesGrid(List<GameModel> filteredGames, Color accentColor, bool isLandscape) {
    return GridView.builder(
      shrinkWrap: isLandscape,
      physics: isLandscape ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(26, 10, 26, isLandscape ? 10 : 140),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.79),
      itemCount: filteredGames.length,
      itemBuilder: (context, index) {
        final game = filteredGames[index];
        final isSelected = _selectedGames.contains(game.name);
        return GestureDetector(
          onTap: () {
            setState(() {
              final int? gameId = int.tryParse(game.id);
              if (gameId == null) return;

              if (_selectedGameIds.contains(gameId)) {
                // Знімаємо вибір
                _selectedGameIds.remove(gameId);
                _selectedGames.remove(game.name);
              } else {
                // Додаємо вибір
                _selectedGameIds.add(gameId);
                _selectedGames.add(game.name);
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181826),
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: accentColor, width: 2) : null,
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: game.imageUrl.startsWith('http')
                      ? Image.network(
                    game.imageUrl,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.gamepad, color: Colors.white24, size: 50),
                  )
                      : Image.asset(
                    'assets/images/game_images/${game.imageUrl}',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.gamepad, color: Colors.white24, size: 50),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 8, right: 8),
                  child: Text(
                    game.name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                      color: isSelected ? accentColor : Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    game.genres.isNotEmpty ? game.genres.join(' / ') : 'Action',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: isSelected ? accentColor : Colors.white54),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Кнопка застосування змін (Зберегти) замість переходу далі
  Widget _buildApplyButton() {
    return Container(
      color: const Color(0xFF0F0F1A),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F5A0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _selectedGameIds.isEmpty ? null : _applyChanges,
                  child: const Text(
                    'APPLY CHANGES',
                    style: TextStyle(
                      color: Color(0xFF0F0F13),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Data provided by IGDB.com',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}