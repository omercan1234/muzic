import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/music.dart';

class ShareSheet extends StatefulWidget {
  final Music music;

  const ShareSheet({super.key, required this.music});

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();

  // 🚀 Spotify Tarzı Paylaşım
  Future<void> _shareFinalTest() async {
    try {
      // 1. Kartın fotoğrafını çek
      final image = await _screenshotController.captureFromWidget(
        _buildShareCard(),
        delay: const Duration(milliseconds: 50),
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/share_${widget.music.youtubeId}.png').create();
      await imagePath.writeAsBytes(image);

      // 2. LİNKİ ÖNBELLEKTEN KURTARMA (Cache Busting)
      // Sonuna zaman damgası ekliyoruz ki Discord fotoğrafı yeniden çeksin
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String webLink = "https://muzic-2b00e.web.app/?id=${widget.music.youtubeId}&t=$timestamp";

      // Özel Uygulama Linki (Deep Link)
      final String deepLink = "muzikapp://music/${widget.music.youtubeId}";

      // 3. PAYLAŞ: Fotoğraf + Tıklanabilir Linkler
      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: "🎧 ${widget.music.name} - Muzik App'te Dinle!\n\n"
              "🔗 Uygulamada Aç: $deepLink\n"
              "🌐 Web Link: $webLink",
      );
    } catch (e) {
      debugPrint("Paylaşım hatası: $e");
    }
  }

  Widget _buildShareCard() {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF121212),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF282828), Colors.black],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.music_note, color: Color(0xFF1DB954), size: 18),
                SizedBox(width: 6),
                Text("MUZIK APP", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, decoration: TextDecoration.none)),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(widget.music.image, width: 220, height: 220, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),
            Text(widget.music.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(widget.music.desc, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.normal, decoration: TextDecoration.none), textAlign: TextAlign.center),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF1DB954), borderRadius: BorderRadius.circular(20)),
              child: const Text("MUZIK APP'TE DİNLE", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 25),

            _buildShareCard(),

            const SizedBox(height: 30),

            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const CircleAvatar(backgroundColor: Color(0xFF282828), child: Icon(Icons.link, color: Colors.white)),
              title: const Text("Linki kopyala", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: "https://muzic-2b00e.web.app/?id=${widget.music.youtubeId}"));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link kopyalandı")));
              },
            ),

            const Divider(color: Colors.white10, indent: 70),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 15, 20, 10),
              child: Align(alignment: Alignment.centerLeft, child: Text("Paylaş", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
            ),

            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _buildAppIcon("Instagram", Icons.camera_alt, Colors.pinkAccent, _shareFinalTest),
                  _buildAppIcon("WhatsApp", Icons.chat, Colors.green, _shareFinalTest),
                  _buildAppIcon("X", Icons.close, Colors.white, _shareFinalTest),
                  _buildAppIcon("Diğer", Icons.more_horiz, Colors.grey, _shareFinalTest),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(String name, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          children: [
            CircleAvatar(radius: 24, backgroundColor: const Color(0xFF282828), child: Icon(icon, color: color, size: 24)),
            const SizedBox(height: 6),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
