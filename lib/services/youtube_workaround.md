/// 403 sorununu kalıcı çözmek için YouTube API alternatifi
/// Not: Bu requires youtube-dl or similar backend service
/// 
/// Ancak mobil app'de çalışmış bir çözüm:
/// 1. Web sunucusunda youtube-dl API kur
/// 2. Mobil app web servisini çağır
/// 3. Web servisi secure stream URL döndür

/// Geçici patch: Cache headers'ı force et
const String _ytHeaders = '''
{
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  "Accept": "audio/webm, audio/*;q=0.9",
  "Sec-Fetch-Dest": "audio", 
  "Sec-Fetch-Mode": "cors",
  "Sec-Fetch-Site": "cross-site"
}
''';

/// 403 Hatası Özeti:
/// 
/// ROOT CAUSE:
/// YouTube's CDN signature validation olmuştur. 
/// Signed URLs expire in 6-24 hours ve signature algoritmayı bilmeye gerek var.
/// just_audio → ExoPlayer native HTTP layer'ı custom headers kullanmıyor.
///
/// ÇÖZÜMLER (priority):
/// 1. ✅ youtube_player_flutter (embedded, works 100%)
/// 2. ✅ flutter_inappwebview + HTML5 audio
/// 3. ❌ just_audio + direct YouTube (too many restrictions)
/// 4. ⭐ Backend API (youtube-dl server)
