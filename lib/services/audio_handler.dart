import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const Map<String, String> _criticalHeaders = {
    'User-Agent': _userAgent,
    'Referer': 'https://www.youtube.com/',
    'Origin': 'https://www.youtube.com/',
  };

  final ja.AudioPlayer _player = ja.AudioPlayer();
  
  // Pozisyon verilerini birleştiren stream
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _initAudioSession();
  }

  void _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> stop() => _player.stop();

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> setAudioSource(String url, MediaItem item) async {
    try {
      final duration = await _player.setAudioSource(
        ja.AudioSource.uri(Uri.parse(url), headers: _criticalHeaders),
      );
      
      // Süreyi MediaItem'a ekleyip yayıyoruz
      mediaItem.add(item.copyWith(duration: duration));
    } catch (e) {
      print("❌ AudioHandler Hatası: $e");
      rethrow;
    }
  }

  PlaybackState _transformEvent(ja.PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ja.ProcessingState.idle: AudioProcessingState.idle,
        ja.ProcessingState.loading: AudioProcessingState.loading,
        ja.ProcessingState.buffering: AudioProcessingState.buffering,
        ja.ProcessingState.ready: AudioProcessingState.ready,
        ja.ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
