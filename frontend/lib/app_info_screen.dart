import 'package:flutter/material.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F0F13);
    const accentColor = Color(0xFF00F5A0);
    const cardColor = Color(0xFF181826);
    const textColorMuted = Color(0xFF8E8EA9);

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Application Info',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Секція розробки та дизайну
          const Text(
            'CREDITS & TEAM',
            style: TextStyle(
              color: textColorMuted,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCreditRow(Icons.brush, 'Design', 'Lymarenko Viktoria', accentColor),
                  const Divider(color: Color(0xFF2B2B3B), height: 24),
                  _buildCreditRow(Icons.code, 'Development', 'Lymarenko Hennadiy', accentColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Секція баз даних та пошуку ігор
          const Text(
            'DATA SOURCES',
            style: TextStyle(
              color: textColorMuted,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sports_esports, color: accentColor, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Game Database & Search',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All game details, artwork, and searching features are powered by the IGDB (Internet Game Database) API.',
                          style: TextStyle(color: textColorMuted, fontSize: 13, fontFamily: 'Inter', height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Секція асетів та картинок (Freepik / Rawpixel)
          const Text(
            'ASSETS & IMAGES ATTRIBUTION',
            style: TextStyle(
              color: textColorMuted,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAssetSource('Images by @katemangostar', 'Freepik / Magnific'),
                  const Divider(color: Color(0xFF2B2B3B), height: 20),
                  _buildAssetSource('Images by @MARKOVKA', 'Freepik'),
                  const Divider(color: Color(0xFF2B2B3B), height: 20),
                  _buildAssetSource('Images by @gstudioimagen', 'Magnific.com'),
                  const Divider(color: Color(0xFF2B2B3B), height: 20),
                  _buildAssetSource('Images from rawpixel.com', 'Rawpixel'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Секція зв'язку (Contact Us)
          const Text(
            'CONTACT US',
            style: TextStyle(
              color: textColorMuted,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, color: accentColor, size: 22),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Support & Feedback',
                        style: TextStyle(color: Color(0xFF8E8EA9), fontSize: 12, fontFamily: 'Inter'),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'help@gamebuddy.com',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditRow(IconData icon, String title, String name, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF8E8EA9), fontSize: 12, fontFamily: 'Inter')),
            const SizedBox(height: 2),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
          ],
        ),
      ],
    );
  }

  Widget _buildAssetSource(String author, String platform) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            author,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          platform,
          style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 12, fontFamily: 'Inter'),
        ),
      ],
    );
  }
}