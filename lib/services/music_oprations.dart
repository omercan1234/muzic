import 'package:audio_service/audio_service.dart';
import 'package:muzik/services/audio_handler.dart';
import 'package:muzik/services/music_service.dart';
import 'package:muzik/models/music.dart';
import 'package:muzik/data/fake_music_data.dart';

class MusicOperations {
  final MusicService _musicService;
  final MyAudioHandler _audioHandler;

  MusicOperations(this._musicService, this._audioHandler);

  /// Ana sayfada gösterilecek müzik listesini döndürür
  static List<Music> getMusic() {
    return FakeMusicData.musicList;
  }

  /// YouTube URL'sini alır, ses akışına çevirir ve çalmaya başlar.
  Future<void> playYoutubeVideo(String videoUrl) async {
    try {
      final videoDetails = await _musicService.getVideoDetails(videoUrl);
      if (videoDetails == null) return;

      final String? streamUrl = await _musicService.getAudioStreamUrl(videoUrl);
      if (streamUrl == null) return;

      final title = videoDetails['title'] ?? 'Unknown';
      final duration = videoDetails['duration'] == null 
          ? null 
          : Duration(seconds: videoDetails['duration'] as int);
      final thumbnail = videoDetails['thumbnail'] ?? '';

      final mediaItem = MediaItem(
        id: videoUrl,
        title: title,
        artist: 'YouTube',
        album: 'YouTube',
        duration: duration,
        artUri: thumbnail.isNotEmpty ? Uri.parse(thumbnail) : null,
      );

      await _audioHandler.setAudioSource(streamUrl, mediaItem);
      await _audioHandler.play();

    } catch (e) {
      print("Oynatma hatası: $e");
    }
  }
}
