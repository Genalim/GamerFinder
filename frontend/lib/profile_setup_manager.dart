class ProfileSetupManager {
  Set<String> selectedLanguages = {}; // Для збереження кодів обраних мов

  // Приватний конструктор та єдиний екземпляр (Синглтон)
  ProfileSetupManager._internal();
  static final ProfileSetupManager instance = ProfileSetupManager._internal();

  // === 1-2 КРОК: ІГРИ ===
  List<dynamic> savedGamesList = []; // Для збереження розширеного списку ігор з API
  Set<String> selectedGames = {};    // Для галочок на іграх

  // === 3 КРОК: ПЛАТФОРМИ ===
  Set<String> selectedPlatforms = {};

  // === 4-5 КРОК: СТИЛІ ТА ЧАС ===
  Set<String> selectedPlayStyles = {};
  Set<String> selectedTimes = {};

  // === 6 Голосовий чат ===
  bool useVoiceChat = false;

  // === 7-8 КРОК: ФІНАЛЬНИЙ СЕТАП ПРОФІЛЮ ===
  String nickname = '';
  String email = '';
  String password = '';
  String? selectedAvatarPath;

  // Метод для повного скидання даних при успішному завершенні
  void reset() {
    savedGamesList.clear();
    selectedGames.clear();
    selectedPlatforms.clear();
    selectedPlayStyles.clear();
    selectedTimes.clear();;
    nickname = '';
    email = '';
    password = '';
    selectedAvatarPath = null;
  }
}