import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'custom_widgets.dart';
import 'api_config.dart';
import 'user_session.dart';

// Модель для збереження списку оцінок, отриманих від інших юзерів
class EvaluationModel {
  final String evaluatorNickname;
  final int stars;
  final String? evaluatorAvatar;

  EvaluationModel({
    required this.evaluatorNickname,
    required this.stars,
    this.evaluatorAvatar,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    return EvaluationModel(
      evaluatorNickname: json['evaluator_nickname'] ?? 'Gamer',
      stars: json['stars'] ?? 0,
      evaluatorAvatar: json['evaluator_avatar'],
    );
  }
}

class EditRatingScreen extends StatefulWidget {
  const EditRatingScreen({super.key});

  @override
  State<EditRatingScreen> createState() => _EditRatingScreenState();
}

class _EditRatingScreenState extends State<EditRatingScreen> {
  bool _isLoading = true;
  List<EvaluationModel> _evaluations = [];
  double _myRating = 0.0;
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _loadRatingsData();
  }

  Future<void> _loadRatingsData() async {
    final user = UserSession().currentUser;
    if (user == null) return;

    setState(() {
      _myRating = user.rating?.toDouble() ?? 0.0;
      _isPro = user.isPro;
    });

    try {
      final userId = await UserSession.getUserId();
      final token = await UserSession.getToken();

      // Ендпоінт для отримання списку оцінок вашого профілю (замініть на свій актуальний)
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/users/$userId/evaluations"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _evaluations = data.map((json) => EvaluationModel.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Помилка завантаження рейтингу: $e");
      setState(() => _isLoading = false);
    }
  }

  // Відмальовка статичних зірочок (без кліків) для кожної оцінки
  Widget _buildStarsDisplay(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 2.0),
          child: FigmaRatingStar(isFilled: index < count),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F0F13);
    const accentColor = Color(0xFF00F5A0);
    const cardColor = Color(0xFF181826);

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reputation & Evaluations',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Великий заголовок власного рейтингу
          // Великий заголовок власного рейтингу
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'My Global Rating',
                    style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 14, fontFamily: 'Inter', fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FigmaRatingStar(isFilled: true, size: 30.0,), // Зірочка перед цифрою
                      const SizedBox(width: 10),
                      Text(
                        '${_myRating.toStringAsFixed(1)} / 5.0', // Округлення до десятих
                        style: const TextStyle(color: accentColor, fontSize: 36, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Based on community evaluations',
                    style: TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // PRO-статус або плашка для розблокування
          if (!_isPro) ...[
            Card(
              color: const Color(0xFF0066FF).withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF0066FF), width: 1),
              ),
              child: const ListTile(
                leading: Icon(Icons.workspace_premium, color: Colors.blueAccent),
                title: Text('Go PRO to see evaluations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Upgrade to see who rated your profile and how.', style: TextStyle(color: Colors.white60, fontSize: 11)),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Список оцінщиків (заблюрений, якщо не PRO)
          const Text(
            'Evaluations Ledger',
            style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 8),

          // Застосовуємо фільтр блюру, якщо юзер не PRO
          ImageFiltered(
            imageFilter: _isPro
                ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                : ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: _evaluations.isEmpty
                ? const Card(
              color: cardColor,
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                    'No evaluations yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54)
                ),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _evaluations.length,
              itemBuilder: (context, index) {
                final eval = _evaluations[index];
                return Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0F0F1A),
                      child: Text(
                        eval.evaluatorNickname.isNotEmpty ? eval.evaluatorNickname[0].toUpperCase() : 'U',
                        style: const TextStyle(color: accentColor),
                      ),
                    ),
                    title: Text(eval.evaluatorNickname, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    trailing: _buildStarsDisplay(eval.stars),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}