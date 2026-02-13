import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MusicService {
  static const String backendUrl = 'https://muzic-production-a4ca.up.railway.app';
  final Map<String, CachedUrl> _urlCache = {};
  static const Duration _urlCacheDuration = Duration(hours: 6);
  final YoutubeExplode _yt = YoutubeExplode();

  Future<String?> getAudioStreamUrl(String videoIdOrUrl) async {
    try {
      final videoId = _extractVideoId(videoIdOrUrl);
      if (videoId == null || videoId.isEmpty) return null;
      if (_urlCache.containsKey(videoId)) {
        final cached = _urlCache[videoId]!;
        if (DateTime.now().difference(cached.timestamp) < _urlCacheDuration) return cached.url;
        _urlCache.remove(videoId);
      }
      final response = await http.get(Uri.parse('$backendUrl/api/music/$videoId'), headers: {'Accept': 'application/json', 'User-Agent': 'MuzikApp/1.0'}).timeout(const Duration(seconds: 40));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final streamUrl = data['stream_url'] as String?;
        if (streamUrl != null) {
          _urlCache[videoId] = CachedUrl(url: streamUrl, timestamp: DateTime.now(), title: data['title'] ?? 'Unknown');
          return streamUrl;
        }
      }
      return null;
    } catch (e) { return null; }
  }

  /// ✅ KESİN ÇÖZÜM: Şarkı Sözü Arama Mantığı
  Future<String?> getLyrics(String title, String artist, {String? videoId}) async {
    try {
      // 1. YouTube kirliliğini temizle
      String query = _cleanName("$artist $title");
      
      // Eğer artist ve title birbirinin aynısıysa (genelde YouTube videolarında öyle olur), 
      // sorguyu sadece bir kez kullan.
      if (artist.trim() == title.trim() || title.contains(artist)) {
        query = _cleanName(title);
      }

      print("🔍 Şarkı sözü aranıyor: $query");

      // 2. LRCLIB Search API'sini kullan (En esnek yol)
      final searchUrl = 'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}';
      final response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          // En iyi eşleşen sonucun sözlerini al
          final bestMatch = results[0];
          return bestMatch['plainLyrics'] ?? bestMatch['syncedLyrics'] ?? bestMatch['instrumental'];
        }
      }

      // 3. Fallback: YouTube Altyazıları
      if (videoId != null) {
        return await _fetchYouTubeSubtitles(videoId);
      }
      
      return "Bu şarkı için henüz söz eklenmemiş.";
    } catch (e) {
      print("❌ Lyrics Error: $e");
      if (videoId != null) return await _fetchYouTubeSubtitles(videoId);
      return "Sözler yüklenirken bir sorun oluştu.";
    }
  }

  String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '') 
        .replaceAll(RegExp(r'\[.*?\]', caseSensitive: false), '') 
        .replaceAll(RegExp(r'official (video|audio|lyric|audio|clip|mv)', caseSensitive: false), '')
        .replaceAll(RegExp(r'lyric(s)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'ft\.|feat\.|featuring', caseSensitive: false), '')
        .replaceAll(RegExp(r'HD|4K|1080p|720p', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\s\-\u00C0-\u017F]', unicode: true), '') 
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<String?> _fetchYouTubeSubtitles(String videoId) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);
      final trackInfo = manifest.getByLanguage('tr').isNotEmpty ? manifest.getByLanguage('tr').first : (manifest.getByLanguage('en').isNotEmpty ? manifest.getByLanguage('en').first : null);
      if (trackInfo != null) {
        final track = await _yt.videos.closedCaptions.get(trackInfo);
        return track.captions.map((c) => c.text).join('\n');
      }
      return "Altyazı bulunamadı.";
    } catch (e) { return null; }
  }

  Future<Map<String, dynamic>?> getVideoDetails(String videoIdOrUrl) async {
    try {
      final videoId = _extractVideoId(videoIdOrUrl);
      if (videoId == null) return null;
      final response = await http.get(Uri.parse('$backendUrl/api/music/$videoId')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) { return null; }
  }

  Future<List<SearchResult>> searchMusic(String query) async {
    try {
      if (query.isEmpty) return [];
      final response = await http.post(Uri.parse('$backendUrl/api/search'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'query': query})).timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        return results.map((r) => SearchResult(videoId: r['video_id'] ?? '', title: r['title'] ?? 'Unknown', uploader: r['uploader'] ?? 'Unknown', duration: r['duration'] ?? 0)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  String? _extractVideoId(String input) {
    if (input.length == 11 && !input.contains('/')) return input;
    if (input.contains('watch?v=')) { final parts = input.split('watch?v='); if (parts.length > 1) return parts[1].split('&').first; }
    if (input.contains('youtu.be/')) { final parts = input.split('youtu.be/'); if (parts.length > 1) return parts[1].split('?').first; }
    return null;
  }

  void dispose() { _yt.close(); }
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