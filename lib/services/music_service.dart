import 'package:http/http.dart' as http;
import 'dart:convert';

class MusicService {
  // Backend URL - Replace with your laptop IP (e.g., 192.168.1.111)
  static const String backendUrl = 'http://192.168.1.111:5000';
  
  // URL cache (video ID -> {url,timestamp})
  final Map<String, CachedUrl> _urlCache = {};
  static const Duration _urlCacheDuration = Duration(hours: 6);

  /// Backend API'den YouTube ses URL'sini alır
  Future<String?> getAudioStreamUrl(String videoIdOrUrl) async {
    try {
      // Video ID'yi çıkart (tam URL veya kısa ID)
      final videoId = _extractVideoId(videoIdOrUrl);
      if (videoId == null || videoId.isEmpty) {
        print('❌ Geçersiz video ID: $videoIdOrUrl');
        return null;
      }

      // Cache'den kontrol et (6 saat geçerli)
      if (_urlCache.containsKey(videoId)) {
        final cached = _urlCache[videoId]!;
        if (DateTime.now().difference(cached.timestamp) < _urlCacheDuration) {
          print('✅ Cache\'den URL alındı: $videoId');
          return cached.url;
        }
        _urlCache.remove(videoId);
      }

      print('🔍 Backend\'den URL alınıyor: $videoId');
      
      final response = await http.get(
        Uri.parse('$backendUrl/api/music/$videoId'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'MuzikApp/1.0',
        },
      ).timeout(
        const Duration(seconds: 60),  // yt-dlp needs 10-20 seconds to extract
        onTimeout: () => throw Exception('Backend bağlantı zaman aşımı'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final streamUrl = data['stream_url'] as String?;
        
        if (streamUrl == null || streamUrl.isEmpty) {
          throw Exception('Stream URL boş');
        }

        // Cache'le (6 saat - yt-dlp URL'leri çok daha uzun geçerli)
        _urlCache[videoId] = CachedUrl(
          url: streamUrl,
          timestamp: DateTime.now(),
          title: data['title'] ?? 'Unknown',
        );
        
        print('✅ Stream URL alındı: $videoId');
        return streamUrl;
      } else {
        print('❌ Backend hatası: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Backend hatası: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Hata: $e');
      return null;
    }
  }

  /// Video detaylarını backend'den al (opsiyonel)
  Future<Map<String, dynamic>?> getVideoDetails(String videoIdOrUrl) async {
    try {
      final videoId = _extractVideoId(videoIdOrUrl);
      if (videoId == null) return null;

      final response = await http.get(
        Uri.parse('$backendUrl/api/music/$videoId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Detay alınamadı: $e');
      return null;
    }
  }

  /// YouTube'da şarkı ara
  Future<List<SearchResult>> searchMusic(String query) async {
    try {
      if (query.isEmpty) return [];

      print('🔍 Aranıyor: $query');

      final response = await http.post(
        Uri.parse('$backendUrl/api/search'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        return results
            .map((r) => SearchResult(
              videoId: r['video_id'] ?? '',
              title: r['title'] ?? 'Unknown',
              uploader: r['uploader'] ?? 'Unknown',
              duration: r['duration'] ?? 0,
            ))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Arama hatası: $e');
      return [];
    }
  }

  /// Backend sağlığını kontrol et
  Future<bool> checkBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/status'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Backend bağlanılamıyor: $e');
      return false;
    }
  }

  /// Video ID'yi çıkart (https://youtube.com/watch?v=ID veya sadece ID)
  String? _extractVideoId(String input) {
    if (input.length == 11 && !input.contains('/')) {
      return input; // Zaten ID
    }
    // URL'den ID çıkart
    if (input.contains('watch?v=')) {
      final parts = input.split('watch?v=');
      if (parts.length > 1) {
        return parts[1].split('&').first;
      }
    }
    if (input.contains('youtu.be/')) {
      final parts = input.split('youtu.be/');
      if (parts.length > 1) {
        return parts[1].split('?').first;
      }
    }
    return null;
  }

  void dispose() {
    // HTTP istemcisi otomatik temizlenir
  }
}
/// URL cache modeli
class CachedUrl {
  final String url;
  final DateTime timestamp;
  final String? title;

  CachedUrl({
    required this.url,
    required this.timestamp,
    this.title,
  });
}

/// YouTube arama sonucu
class SearchResult {
  final String videoId;
  final String title;
  final String uploader;
  final int duration;

  SearchResult({
    required this.videoId,
    required this.title,
    required this.uploader,
    required this.duration,
  });
}