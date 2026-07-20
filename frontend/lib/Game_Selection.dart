import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'custom_widgets.dart';
import 'Choose_your_platform.dart';
import 'profile_setup_manager.dart';
import 'api_config.dart';

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

class GameSelectionScreen extends StatefulWidget {
  const GameSelectionScreen({super.key});

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> {
  // Змінна для контролю завантаження ігор на скрін з бази
  bool _isLoadingInitialGames = true;

  Future<void> _fetchGamesFromDB() async {
    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/games")); // Переконайся, що такий ендпоінт є на бекенді
      print("Статус код: ${response.statusCode}");
      print("Тіло відповіді: ${response.body}"); // <--- ЦЕ НАЙВАЖЛИВІШЕ

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print("Кількість отриманих ігор: ${data.length}"); // <--- Перевірка кількості
        setState(() {
          _games = data.map((json) {
            // Безпечне перетворення жанрів
            List<String> parsedGenres = [];
            try {
              var rawGenres = json['genres'];
              if (rawGenres != null) {
                if (rawGenres is String) {
                  String cleaned = rawGenres.trim();
                  if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
                    cleaned = cleaned.substring(1, cleaned.length - 1);
                    if (cleaned.isNotEmpty) {
                      parsedGenres = cleaned.split(',').map((e) {
                        return e.trim().replaceAll("'", "").replaceAll('"', "");
                      }).where((e) => e.isNotEmpty).toList();
                    }
                  } else {
                    var decoded = jsonDecode(cleaned);
                    if (decoded is List) {
                      parsedGenres = decoded.map((e) => e.toString()).toList();
                    }
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

          _isLoadingInitialGames = false;
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження ігор з бази: $e");
      setState(() => _isLoadingInitialGames = false);
    }
  }


  final _manager = ProfileSetupManager.instance;
  final String _clientId = 'e8f46ha10ff5jvy6d0ysmgpw2kei32';
  final String _clientSecret = 'xwqcj3necpyerb7xxscnr227ekmqzj';
  String? _accessToken;

  late Set<String> _selectedGames;
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
    _selectedGames = Set.from(_manager.selectedGames);
    _fetchGamesFromDB();
    //===Заглушки що тягнулись для тесту закоментовані, тепер з бази тягнемо ігри.
    //if (_manager.savedGamesList.isNotEmpty) {
     // _games = List<GameModel>.from(_manager.savedGamesList);
    //} else {
      //_games = [
       // GameModel(id: '1', name: 'Apex Legends', imageUrl: 'ApexLegends.png', genres: ['Shooter', 'Battle Royale']),
       // GameModel(id: '5', name: 'CS:GO', imageUrl: 'CSGO.png', genres: ['Shooter']),
      //  GameModel(id: '13', name: 'League of Legends', imageUrl: 'LeagueofLegends.png', genres: ['MOBA']),
      //  GameModel(id: '19', name: 'Valorant', imageUrl: 'Valorant.png', genres: ['Shooter', 'Action']),
     // ];
    //}
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

  void _saveCurrentStateToManager() {
    _manager.selectedGames = _selectedGames;
    _manager.savedGamesList = _games;
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveCurrentStateToManager();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { _closeSearchDropdown(); FocusScope.of(context).unfocus(); },
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // Якщо Landscape — даємо всьому екрану вільно скролитись і не утискати інтерфейс
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

                        const SizedBox(height: 12), // Оригінальний відступ 12
                        _buildFilterHeader(),
                        if (_isFilterOpen) _buildGenresOverlay(),

                        // Сітка з іграми
                        if (isLandscape)
                          _buildGamesGrid(filteredGames, accentColor, isLandscape)
                        else
                          SizedBox(
                            height: MediaQuery.of(context).size.height - 290,
                            child: _buildGamesGrid(filteredGames, accentColor, isLandscape),
                          ),

                        // У Landscape кнопка просто йде в кінці скролу екрана
                        if (isLandscape) ...[
                          const SizedBox(height: 24),
                          _buildBottomActionArea(),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
                // У Portrait кнопка залізно прикріплена до самого низу екрана поверх скролу
                if (!isLandscape)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildBottomActionArea(),
                  ),
              ],
            ),
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
                    final game = _apiResults[index]; // Це вибрана гра з API

                    try {
                      final response = await http.post(
                          Uri.parse("${ApiConfig.baseUrl}/ensure-game"),
                          headers: {"Content-Type": "application/json"},
                          body: json.encode({
                            "igdb_id": int.tryParse(game.id), // ID з IGDB
                            "name": game.name,
                            "image_url": game.imageUrl,
                            "genres": game.genres
                          })
                      );

                      if (response.statusCode == 200) {
                        final responseData = json.decode(response.body);
                        int gameId = responseData['id']; // ID, який дав бекенд

                        setState(() {
                          // Оновлюємо менеджер
                          if (!_manager.savedGameIds.contains(gameId)) {
                            _manager.savedGameIds.add(gameId);
                          }
                          // Оновлюємо UI
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
          debugPrint("Картинка для ${game.name}: ${game.imageUrl}");
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
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint("Помилка завантаження мережевої картинки: $error");
                            return const Icon(Icons.gamepad, color: Colors.white24, size: 24);
                          },
                        )
                            : Image.asset(
                          'assets/images/game_images/${game.imageUrl}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint("Помилка завантаження локальної картинки: $error");
                            return const Icon(Icons.gamepad, color: Colors.white24, size: 24);
                          },
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
                    onTap: () => setState(() => _selectedGames.remove(game.name)),
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
                _saveCurrentStateToManager();
                Navigator.pop(context);
              }
          ),
          const Expanded(child: Text('Select your games', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ПОВЕРНЕНО ОРИГІНАЛЬНУ ВИСОТУ ТА ШРИФТИ
  Widget _buildSearchInput() {
    return Container(
      width: 360, height: 48, // Повернено 48
      decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF00F5A0), size: 20), // Повернено 20
          Expanded(
            child: TextField(
              controller: _searchController,
              autocorrect: false,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14), // Повернено 14
              decoration: const InputDecoration(hintText: 'Search in global library', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
                onTap: () { _searchController.clear(); _onSearchChanged(''); _closeSearchDropdown(); },
                child: const Icon(Icons.close, color: Colors.white54, size: 20) // Повернено 20
            )
          else const SizedBox(width: 20),
        ],
      ),
    );
  }

  // ПОВЕРНЕНО ОРИГІНАЛЬНУ ВИСОТУ ТА ШРИФТИ
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

              // === ВИПРАВЛЕНО ТУТ ===
              // Тепер якщо фільтр відкритий (_isFilterOpen), стрілочка стає зеленою (accentColor)
              Transform.rotate(
                angle: _isFilterOpen ? 1.571 : 0.0,
                child: Icon(
                  Icons.play_arrow,
                  color: _isFilterOpen ? const Color(0xFF00F5A0) : Colors.white, // Динамічний колір
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              if (_selectedGames.contains(game.name)) {
                _selectedGames.remove(game.name);
                // Можна також видалити ID з менеджера, якщо треба
              } else {
                _selectedGames.add(game.name);
                // Додаємо ID в список, якщо його там ще немає
                if (game.id != null) {
                  int id = int.tryParse(game.id) ?? 0;
                  if (!_manager.savedGameIds.contains(id)) {
                    _manager.savedGameIds.add(id);
                  }
                }
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12), border: isSelected ? Border.all(color: accentColor, width: 2) : null),
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
                      errorBuilder: (c, e, s) => const Icon(Icons.gamepad, color: Colors.white24, size: 50)
                  )
                      : Image.asset(
                      'assets/images/game_images/${game.imageUrl}',
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.gamepad, color: Colors.white24, size: 50)
                  ),
                ),
                Padding(padding: const EdgeInsets.only(top: 10, left: 8, right: 8), child: Text(game.name, style: TextStyle(fontFamily: 'Poppins', fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 14, color: isSelected ? accentColor : Colors.white), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Padding(padding: const EdgeInsets.only(top: 4, left: 8, right: 8), child: Text(game.genres.isNotEmpty ? game.genres.join(' / ') : 'Action', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: isSelected ? accentColor : Colors.white54), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActionArea() {
    return Container(
      color: const Color(0xFF0F0F1A),
      padding: EdgeInsets.zero,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NeonGameButton(
                isActive: _selectedGames.isNotEmpty,
                onTap: () {
                  _saveCurrentStateToManager();
                  _closeSearchDropdown();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ChoosePlatformScreen()));
                },
              ),
              const SizedBox(height: 5),
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