import 'dart:async';
import 'package:flutter/material.dart';
import 'package:muzik/screens/home.dart';
import 'package:muzik/screens/search.dart';
import 'package:muzik/screens/yourlibraray.dart';
import 'package:muzik/controllers/player_controller.dart';
import 'package:muzik/controllers/jam_controller.dart';
import 'package:muzik/widgets/mini_player/mini_player_widget.dart';
import 'package:muzik/widgets/common/heart_animation.dart';
import 'package:muzik/widgets/playlist/playlist_add_sheet.dart';
import 'package:muzik/screens/player.dart';
import 'package:muzik/services/music_oprations.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:muzik/services/audio_handler.dart';
import 'package:app_links/app_links.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final PlayerController _playerController = GetIt.instance<PlayerController>();
  final JamController _jamController = GetIt.instance<JamController>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  int currentIndex = 0;
  late List<Widget> Tabs;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    _playerController.addListener(_onControllerChange);
    _jamController.addListener(_onControllerChange);

    Tabs = [
      Home(onMiniPlayer: _playerController.onMusicSelect),
      Search(_playerController.onMusicSelect),
      const Yourlibraray(),
    ];
  }

  void _initAppLinks() {
    _appLinks = AppLinks();
    
    // ✅ getInitialAppLink() -> getInitialLink() olarak güncellendi
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingLink(uri);
    });

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    });
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.pathSegments.contains('song') || (uri.scheme == 'muzikapp' && uri.host == 'music')) {
      final String? songId = uri.pathSegments.last;
      if (songId != null) {
        final allSongs = MusicOperations.getMusic();
        final song = allSongs.firstWhere((s) => s.youtubeId == songId, orElse: () => allSongs.first);
        _playerController.onMusicSelect(song);
        _openFullPlayer();
      }
    }
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _playerController.removeListener(_onControllerChange);
    _jamController.removeListener(_onControllerChange);
    super.dispose();
  }

  void _showAddToPlaylistSheet() {
    if (_playerController.currentMusic == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaylistAddSheet(
        playerController: _playerController,
        currentMusic: _playerController.currentMusic!,
      ),
    );
  }

  void _openFullPlayer() {
    if (_playerController.currentMusic == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          musics: _playerController.currentPlaylist,
          initialIndex: _playerController.currentIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMusic = _playerController.currentMusic;

    return Scaffold(
      // Debug FAB: test MP3 çalma (sadece debug modunda görünür)
      floatingActionButton: kDebugMode
          ? FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white10,
              child: const Icon(Icons.bug_report, color: Colors.white),
              onPressed: () async {
                final scaffold = ScaffoldMessenger.of(context);
                scaffold.showSnackBar(const SnackBar(content: Text('Test müziği hazırlanıyor...')));
                try {
                  final handler = GetIt.instance<AudioHandler>() as MyAudioHandler;
                  await handler.setAudioSource(
                    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
                    const MediaItem(id: 'debug_test', title: 'Debug Test'),
                  );
                  await handler.play();
                  scaffold.showSnackBar(const SnackBar(content: Text('Test müziği çalıyor.')));
                } catch (e) {
                  scaffold.showSnackBar(SnackBar(content: Text('Test müziği oynatılamadı: $e')));
                }
              },
            )
          : null,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: Tabs,
          ),
          HeartAnimation(
            show: _playerController.showHeartExplosion,
            onEnd: _playerController.resetHeartExplosion,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentMusic != null)
              MiniPlayerWidget(
                music: currentMusic,
                isPlaying: _playerController.isPlaying,
                isPlayerReady: _playerController.isPlayerReady,
                isLiked: _playerController.isCurrentLiked(currentMusic.youtubeId),
                onPlayPause: _playerController.togglePlayPause,
                onLike: () => _playerController.toggleLike(currentMusic),
                dominantColor: _playerController.dominantColor,
                onShowPlaylist: _showAddToPlaylistSheet,
                onTap: _openFullPlayer,
              ),
            Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.black,
              ),
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (index) => setState(() => currentIndex = index),
                backgroundColor: Colors.black,
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Ana Sayfa'),
                  BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Arama'),
                  BottomNavigationBarItem(icon: Icon(Icons.library_music_outlined), activeIcon: Icon(Icons.library_music), label: 'Kitaplığın'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
