import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'custom_widgets.dart';
import 'Welcome_screen.dart';
import 'Chose_your_platform.dart';

class GameModel {
  final String id;
  final String name;
  final String imageUrl;
  final List<String> genres;
  final bool isFromApi;

  GameModel({
    required this.id,
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
  // === IGDB CREDENTIALS ===
  final String _clientId = 'e8f46ha10ff5jvy6d0ysmgpw2kei32';
  final String _clientSecret = 'xwqcj3necpyerb7xxscnr227ekmqzj';
  String? _accessToken;

  final Set<String> _selectedGames = {};
  final List<String> _selectedGenres = [];
  final TextEditingController _searchController = TextEditingController();

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  bool _isFilterOpen = false;
  List<GameModel> _apiResults = [];
  bool _isLoadingApi = false;
  Timer? _debounce;

  final List<GameModel> _games = [
    GameModel(id: '1', name: 'Apex Legends', imageUrl: 'ApexLegends.png', genres: ['Shooter', 'Battle Royale']),
    GameModel(id: '5', name: 'CS:GO', imageUrl: 'CSGO.png', genres: ['Shooter']),
    GameModel(id: '13', name: 'League of Legends', imageUrl: 'LeagueofLegends.png', genres: ['MOBA']),
    GameModel(id: '19', name: 'Valorant', imageUrl: 'Valorant.png', genres: ['Shooter', 'Action']),
  ];

  final List<String> _genresList = [
    'Shooter', 'RPG', 'Strategy', 'Adventure', 'Action', 'Indie', 'RTS', 'TBS',
    'Card & Board', 'Tactical', 'Fighting', 'Simulator', 'Racing', 'Sport', 'Platform',
    'Horror', 'MOBA', 'Hack and slash', 'Arcade', 'Puzzle'];

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
    } catch (e) {
      debugPrint("Auth Error: $e");
    }
  }

  String _clean(String text) => text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  void _onSearchChanged(String query) {
    setState(() {}); // Для оновлення видимості хрестика

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.length <= 1) {
      _hideOverlay();
      return;
    }

    _showOverlay();

    _debounce = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      setState(() => _isLoadingApi = true);
      _updateOverlay();

      await _getAccessToken();
      if (_accessToken == null) {
        if (mounted) setState(() => _isLoadingApi = false);
        return;
      }

      try {
        final url = Uri.parse('https://api.igdb.com/v4/games');
        final body = 'search "$query"; fields name, cover.url, genres.name; where version_parent = null; limit 8;';

        final response = await http.post(
          url,
          headers: {
            'Client-ID': _clientId,
            'Authorization': 'Bearer $_accessToken',
          },
          body: body,
        );

        if (response.statusCode == 200 && mounted) {
          final List data = json.decode(response.body);
          setState(() {
            _apiResults = data.map((json) {
              String? coverUrl = json['cover']?['url'];
              if (coverUrl != null) {
                coverUrl = 'https:' + coverUrl.replaceAll('t_thumb', 't_cover_big');
              }

              return GameModel(
                id: json['id'].toString(),
                name: json['name'],
                imageUrl: coverUrl ?? '',
                genres: (json['genres'] as List?)?.map((g) => g['name'].toString()).toList() ?? [],
                isFromApi: true,
              );
            }).where((apiGame) {
              return !_games.any((local) => local.name.toLowerCase() == apiGame.name.toLowerCase());
            }).toList();
            _isLoadingApi = false;
          });
          _updateOverlay();
        }
      } catch (e) {
        debugPrint("API Error: $e");
        if (mounted) setState(() => _isLoadingApi = false);
      }
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _updateOverlay();
      return;
    }
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _apiResults = [];
        _isLoadingApi = false;
      });
    }
  }

  void _updateOverlay() => _overlayEntry?.markNeedsBuild();

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 360,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300, minHeight: 60),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00F5A0).withOpacity(0.4), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingApi)
                    const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Color(0xFF00F5A0), minHeight: 2),
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
                          onTap: () {
                            setState(() {
                              if (!_games.any((g) => g.name == game.name)) {
                                _games.insert(0, game);
                                _selectedGames.add(game.name);
                              }
                              _searchController.clear();
                            });
                            _hideOverlay();
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedSearch = _clean(_searchController.text);
    final filteredGames = _games.where((game) {
      final matchesSearch = _clean(game.name).contains(normalizedSearch);
      final matchesGenre = _selectedGenres.isEmpty ||
          _selectedGenres.any((selected) =>
              game.genres.any((gameGenre) =>
                  gameGenre.toLowerCase().contains(selected.toLowerCase())
              )
          );
      return matchesSearch && matchesGenre;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _hideOverlay();
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              _buildAppBar(),
              Center(
                  child: CompositedTransformTarget(
                      link: _layerLink,
                      child: _buildSearchInput()
                  )
              ),
              const SizedBox(height: 12),

              // Заголовок фільтра
              _buildFilterHeader(),

              // Жанри тепер з'являються тут і штовхають сітку вниз
              if (_isFilterOpen) _buildGenresOverlay(),

              // Сітка ігор займає весь вільний простір
              Expanded(
                child: _buildGamesGrid(filteredGames),
              ),

              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24), onPressed: () => Navigator.pop(context)),
          const Expanded(child: Text('Select your games', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
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
              keyboardType: TextInputType.visiblePassword,
              textAlign: TextAlign.center, // Текст по центру
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search in global library',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Хрестик для швидкого видалення
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _onSearchChanged('');
                _hideOverlay();
              },
              child: const Icon(Icons.close, color: Colors.white54, size: 20),
            )
          else
            const SizedBox(width: 20), // Заглушка, щоб текст не стрибав
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    bool hasActiveSelection = _selectedGenres.isNotEmpty && !_selectedGenres.contains('All');
    return Center(
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus(); // Закрити клавіатуру при відкритті меню
          setState(() => _isFilterOpen = !_isFilterOpen);
        },
        child: Container(
          width: 360, height: 48,
          decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              const Icon(Icons.filter_list, color: Color(0xFF00F5A0), size: 20),
              Expanded(
                child: Text(
                  hasActiveSelection ? _selectedGenres.join(', ') : 'Filter by genre',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: hasActiveSelection ? Colors.white : Colors.white38,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Хрестик для скидання жанрів (зліва від стрілки)
              if (hasActiveSelection)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGenres.clear();
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ),


              Transform.rotate(
                angle: _isFilterOpen ? 1.571 : 0.0, // 90 градусів (вниз) або 0 градусів (вправо)
                child: Icon(
                  Icons.play_arrow,
                  color: _isFilterOpen ? const Color(0xFF00F5A0) : Colors.white, size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenresOverlay() {
    // Видаляємо 'All' перед рендерингом, якщо він там є
    final displayGenres = _genresList.where((g) => g != 'All').toList();

    return Center(
      child: Container(
        width: 360, // Ширина як у кнопки фільтра
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Скрол не потрібен
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,       // 4 рівні колонки
            mainAxisSpacing: 8,      // Відступ між рядами
            crossAxisSpacing: 8,     // Відступ між кнопками
            childAspectRatio: 2.1,   // Пропорції кнопок
          ),
          itemCount: displayGenres.length,
          itemBuilder: (context, index) {
            final genre = displayGenres[index];
            final isSelected = _selectedGenres.contains(genre);

            return GestureDetector(
              onTap: () => setState(() {
                FocusScope.of(context).unfocus(); // Знімаємо клавіатуру при виборі жанру
                if (isSelected) {
                  _selectedGenres.remove(genre);
                } else {
                  _selectedGenres.add(genre);
                }
              }),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00F5A0).withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00F5A0) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    genre,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00F5A0) : Colors.white70,
                      fontSize: 9.5, // Оптимальний розмір для 4 колонок
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGamesGrid(List<GameModel> filteredGames) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        // Зменшуємо до 0.72, щоб вистачило висоти для назви та жанрів
        childAspectRatio: 0.79,
      ),
      itemCount: filteredGames.length,
      itemBuilder: (context, index) {
        final game = filteredGames[index];
        final isSelected = _selectedGames.contains(game.name);
        const accentColor = Color(0xFF00F5A0);

        return GestureDetector(
          onTap: () => setState(() => isSelected
              ? _selectedGames.remove(game.name)
              : _selectedGames.add(game.name)),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181826),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: accentColor, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // Зображення
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: game.isFromApi
                      ? Image.network(
                    game.imageUrl,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) =>
                    const Icon(Icons.gamepad, color: Colors.white24),
                  )
                      : Image.asset(
                    'assets/images/game_images/${game.imageUrl}',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) =>
                    const Icon(Icons.gamepad, color: Colors.white24),
                  ),
                ),

                // Назва
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 8, right: 8),
                  child: Text(
                    game.name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                      // Колір змінюється на зелений при виборі
                      color: isSelected ? accentColor : Colors.white,
                      // Ефект світіння при виборі
                      shadows: isSelected
                          ? [
                        Shadow(
                            color: accentColor.withOpacity(0.8),
                            blurRadius: 10),
                      ]
                          : null,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Жанр
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    game.genres.isNotEmpty ? game.genres.join(' / ') : 'Action',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                      // Колір змінюється на зелений при виборі, інакше білий 54%
                      color: isSelected ? accentColor : Colors.white54,
                      shadows: isSelected
                          ? [
                        Shadow(
                            color: accentColor.withOpacity(0.6),
                            blurRadius: 8),
                      ]
                          : null,
                    ),
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

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeonGameButton(
        isActive: _selectedGames.isNotEmpty,
        onTap: () {
          print("--- CURRENT GAMES IN RAM ---");
          for (var game in _games) {
            print("Name: ${game.name} | ID: ${game.id} | Genres: ${game.genres.join(', ')}");
          }
          print("-----------------------------");
          _hideOverlay();
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ChoosePlatformScreen()));
        },
      ),
    );
  }
}