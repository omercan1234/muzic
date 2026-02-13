import 'package:http/http.dart' as http;
import 'dart:convert';

class MusicService {
  // Backend URL - Railway production URL
  static const String backendUrl = 'https://muzic-production-a4ca.up.railway.app';
  
  // URL cache (video ID -> {url,timestamp})
  final Map<String, CachedUrl> _urlCache = {};
  static const Duration _urlCacheDuration = Duration(hours: 6);

  /// Backend API'den YouTube ses URL'sini alır
  Future<String?> getAudioStreamUrl(String videoIdOrUrl) async {
    try {
      final videoId = _extractVideoId(videoIdOrUrl);
      if (videoId == null || videoId.isEmpty) {
        print('❌ Geçersiz video ID: $videoIdOrUrl');
        return null;
      }

      if (_urlCache.containsKey(videoId)) {
        final cached = _urlCache[videoId]!;
        if (DateTime.now().difference(cached.timestamp) < _urlCacheDuration) {
          print('✅ Cache\'den URL alındı: $videoId');
          return cached.url;
        }
        _urlCache.remove(videoId);
      }

      print('🔍 Backend\'den URL alınıyor (Railway): $videoId');
      
      final response = await http.get(
        Uri.parse('$backendUrl/api/music/$videoId'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'MuzikApp/1.0',
        },
      ).timeout(
        const Duration(seconds: 40),
        onTimeout: () {
          print('⏰ Zaman Aşımı: Railway sunucusu yanıt vermedi.');
          throw Exception('Backend bağlantı zaman aşımı (40s)');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final streamUrl = data['stream_url'] as String?;
        
        if (streamUrl == null || streamUrl.isEmpty) {
          throw Exception('Stream URL boş');
        }

        _urlCache[videoId] = CachedUrl(
          url: streamUrl,
          timestamp: DateTime.now(),
          title: data['title'] ?? 'Unknown',
        );
        
        print('✅ Stream URL alındı: $videoId');
        return streamUrl;
      } else {
        print('❌ Backend hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Hata: $e');
      return null;
    }
  }

  /// Şarkı sözlerini backend'den al
  Future<String?> getLyrics(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/lyrics/$videoId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['lyrics'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Şarkı sözü alınamadı: $e');
      return null;
    }
  }

  /// Video detaylarını backend'den al
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
      ).timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception('Arama zaman aşımı'),
      );

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
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  String? _extractVideoId(String input) {
    if (input.length == 11 && !input.contains('/')) return input;
    if (input.contains('watch?v=')) {
      final parts = input.split('watch?v=');
      if (parts.length > 1) return parts[1].split('&').first;
    }
    if (input.contains('youtu.be/')) {
      final parts = input.split('youtu.be/');
      if (parts.length > 1) return parts[1].split('?').first;
    }
    return null;
  }

  void dispose() {
    // Boş dispose metodu
  }
}

class CachedUrl {
  final String url;
  final DateTime timestamp;
  final String? title;

  CachedUrl({required this.url, required this.timestamp, this.title});
}

class SearchResult {
  final String videoId;
  final String title;
  final String uploader;
  final int duration;

  SearchResult({required this.videoId, required this.title, required this.uploader, required this.duration});
}