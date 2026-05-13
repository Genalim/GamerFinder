import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'Welcome_screen.dart';

class GameSelectionScreen extends StatefulWidget {
  const GameSelectionScreen({super.key});

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> {
  final Set<String> _selectedGames = {};
  final List<String> _selectedGenres = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isFilterOpen = false;

  final List<Map<String, String>> _games = [
    {'name': 'Apex Legends', 'img': 'ApexLegends.png', 'genre': 'Shooter, Battle Royale'},
    {'name': 'Apex Mobile', 'img': 'ApexMobile.png', 'genre': 'Shooter'},
    {'name': 'Arena Valor', 'img': 'ArenaValor.png', 'genre': 'MOBA'},
    {'name': 'Call of Duty: WarZone', 'img': 'CallofDutyWarZone.png', 'genre': 'Shooter'},
    {'name': 'CS:GO', 'img': 'CSGO.png', 'genre': 'Shooter'},
    {'name': 'CS:GO 2', 'img': 'CSGO2.png', 'genre': 'Shooter'},
    {'name': 'Destiny 2', 'img': 'Destiny2.png', 'genre': 'Shooter, RPG'},
    {'name': 'Final Fantasy 14', 'img': 'FinalFantasy14.png', 'genre': 'RPG, MMO'},
    {'name': 'Fortnite', 'img': 'Fortnite.png', 'genre': 'Battle Royale, Shooter'},
    {'name': 'Free Fire', 'img': 'FreeFire.png', 'genre': 'Shooter'},
    {'name': 'Genshin Impact', 'img': 'GenshinImpact.png', 'genre': 'RPG, Action'},
    {'name': 'Heroes of the Storm', 'img': 'HeroesofTheStorm.png', 'genre': 'MOBA'},
    {'name': 'League of Legends', 'img': 'LeagueofLegends.png', 'genre': 'MOBA'},
    {'name': 'Lost Ark', 'img': 'LostArk.png', 'genre': 'RPG, MMO'},
    {'name': 'Mobile Legends', 'img': 'MobileLegends.png', 'genre': 'MOBA'},
    {'name': 'Naraka: Bladepoint', 'img': 'Bladepoint.png', 'genre': 'Action, Battle Royale'},
    {'name': 'PUBG: Battlegrounds', 'img': 'PUBGButtlegrounds.png', 'genre': 'Shooter, Battle Royale'},
    {'name': 'Rainbow Six: Siege', 'img': 'RainbowSixSiege.png', 'genre': 'Shooter, Tactical/RTS'},
    {'name': 'Valorant', 'img': 'Valorant.png', 'genre': 'Shooter, Action'},
  ];

  final List<String> _genresList = [
    'All', 'Shooter', 'Co-op', 'Open World', 'Strategy',
    'Card', 'Indie', 'Puzzle', 'Adventure', 'Battle Royale',
    'MOBA', 'Survival', 'Horror', 'Story Rich', 'Tactical/RTS',
    '4X', 'Casual', 'Fighting', 'Simulation', 'Platformer',
    'RPG', 'Sports', 'Sandbox', 'Free to Play', 'Souls-like',
    'MMO', 'Racing', 'Action', 'Early Access', 'Roguelike'
  ];

  @override
  Widget build(BuildContext context) {
    final filteredGames = _games.where((game) {
      final matchesSearch = game['name']!.toLowerCase().contains(_searchController.text.toLowerCase());
      final matchesGenre = _selectedGenres.isEmpty ||
          _selectedGenres.contains('All') ||
          _selectedGenres.any((g) => game['genre']!.contains(g));
      return matchesSearch && matchesGenre;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildSearchSection(filteredGames),
            const SizedBox(height: 12),
            _buildFilterHeader(),
            Expanded(
              child: Stack(
                children: [
                  _buildGamesGrid(filteredGames),
                  if (_isFilterOpen) _buildGenresOverlay(),
                ],
              ),
            ),
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Select your games', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSearchSection(List filtered) {
    return Column(
      children: [
        Container(
          width: 327, height: 48,
          decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF00F5A0), size: 20),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.center,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search games',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(() {}),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _searchController.clear()),
                  child: const Icon(Icons.close, color: Colors.white54, size: 20),
                )
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
        if (_searchController.text.isNotEmpty && !filtered.any((g) => g['name'] == _searchController.text))
          Container(
            width: 327,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: const Color(0xFF1F1F30), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: filtered.take(3).map((game) => ListTile(
                dense: true,
                title: Text(game['name']!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () => setState(() => _searchController.text = game['name']!),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterHeader() {
    bool hasActiveSelection = _selectedGenres.isNotEmpty && !_selectedGenres.contains('All');

    return GestureDetector(
      onTap: () => setState(() => _isFilterOpen = !_isFilterOpen),
      child: Container(
        width: 327, height: 48,
        decoration: BoxDecoration(color: const Color(0xFF181826), borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            const Icon(Icons.filter_list, color: Color(0xFF00F5A0), size: 20),
            Expanded(
              child: Text(
                hasActiveSelection ? _selectedGenres.join(', ') : 'Filter by game genre',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: hasActiveSelection ? Colors.white : Colors.white38,
                    fontSize: 14,
                    fontFamily: 'Poppins'
                ),
              ),
            ),
            if (hasActiveSelection)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGenres.clear();
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.close, color: Colors.white54, size: 20),
                ),
              ),
            AnimatedRotation(
              turns: _isFilterOpen ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.play_arrow,
                color: _isFilterOpen ? const Color(0xFF00F5A0) : Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenresOverlay() {
    // Розбиваємо список на рядки по 5 елементів
    List<List<String>> rows = [];
    for (var i = 0; i < _genresList.length; i += 5) {
      rows.add(_genresList.sublist(i, i + 5 > _genresList.length ? _genresList.length : i + 5));
    }

    return Container(
      color: const Color(0xFF0F0F1A),
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: SizedBox(
          width: 311, // Ширина з Figma
          child: Table(
            // Встановлюємо точну ширину колонок.
            // 5-ту колонку збільшуємо, щоб текст вліз і був правіше
            columnWidths: const {
              0: FixedColumnWidth(45),
              1: FixedColumnWidth(54),
              2: FixedColumnWidth(59),
              3: FixedColumnWidth(77), // Для довгих назв на кшталт "Open World"
              4: FixedColumnWidth(76), // 5-та колонка
            },
            children: rows.map((row) {
              return TableRow(
                children: row.map((genre) {
                  final isSelected = _selectedGenres.contains(genre) || (_selectedGenres.isEmpty && genre == 'All');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (genre == 'All') {
                            _selectedGenres.clear();
                          } else {
                            if (isSelected) {
                              _selectedGenres.remove(genre);
                            } else {
                              _selectedGenres.add(genre);
                            }
                          }
                        });
                      },
                      child: Text(
                        genre,
                        textAlign: TextAlign.left, // Всі по лівому краю
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          height: 1.5,
                          color: isSelected ? const Color(0xFF00F5A0) : const Color(0xFFA3A3B5),
                          shadows: isSelected ? [
                            const Shadow(offset: Offset(0, 4), blurRadius: 4, color: Color.fromRGBO(0, 0, 0, 0.25))
                          ] : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildGamesGrid(List filteredGames) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 20, childAspectRatio: 0.8,
      ),
      itemCount: filteredGames.length,
      itemBuilder: (context, index) {
        final game = filteredGames[index];
        final isSelected = _selectedGames.contains(game['name']);
        return GestureDetector(
          onTap: () => setState(() => isSelected ? _selectedGames.remove(game['name']) : _selectedGames.add(game['name']!)),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181826),
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? Border.all(color: const Color(0xFF00F5A0), width: 2) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/game_images/${game['img']}',
                    width: 120, height: 90, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_esports, color: Colors.white24, size: 40),
                  ),
                ),
                const SizedBox(height: 8),
                Text(game['name']!, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins')),
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
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WelcomeScreen())),
      ),
    );
  }
}