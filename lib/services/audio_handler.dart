import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // ✅ YouTube CDN'nin en güvendiği tarayıcı kimliği (Chrome Masaüstü)
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // YouTube 403 hatası vermemek için MUTLAKA gerekli headers
  static const Map<String, String> _criticalHeaders = {
    'User-Agent': _userAgent,
    'Referer': 'https://www.youtube.com/',
    'Origin': 'https://www.youtube.com/',
    'Accept': '*/*',
    'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Sec-Fetch-Dest': 'audio',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'cross-site',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  final ja.AudioPlayer _player = ja.AudioPlayer();
  AudioSession? _session;

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _initAudioSession();

    _player.processingStateStream.listen((state) {
      if (state == ja.ProcessingState.completed) {
        stop();
      }
    });
  }

  void _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _session = session;
    } catch (e) {
      print('❗ AudioSession init failed: $e');
    }
  }

  @override
  Future<void> play() async {
    try {
      if (_session != null) await _session!.setActive(true);
      await _player.play();
    } catch (e) {
      print('❗ Play error: $e');
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } finally {
      if (_session != null) await _session!.setActive(false);
    }
  }

  Future<void> setAudioSource(String url, MediaItem item) async {
    try {
      print('ℹ️ Müzik hazırlanıyor: ${item.title}');
      
      // ✅ 403 Hatasını kalıcı olarak aşmak için MUTLAKA bu headers'ları kullan
      await _player.setAudioSource(
        ja.AudioSource.uri(
          Uri.parse(url),
          headers: _criticalHeaders,
        ),
      );

      mediaItem.add(item);
      print('✅ Music loaded to buffer: ${item.title}');
    } catch (e) {
      print("❌ AudioHandler Hatası: $e");
      rethrow;
    }
  }

  PlaybackState _transformEvent(ja.PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
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
