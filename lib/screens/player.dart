import 'package:flutter/material.dart';
import 'package:muzik/models/music.dart';
import 'package:muzik/controllers/player_controller.dart';
import 'package:muzik/widgets/full_player/player_controls.dart';
import 'package:muzik/widgets/playlist/playlist_add_sheet.dart';
import 'package:muzik/widgets/full_player/share_sheet.dart';
import 'package:muzik/widgets/youtube_audio_player.dart';
import 'package:get_it/get_it.dart';

class PlayerScreen extends StatefulWidget {
  final List<Music> musics;
  final int initialIndex;

  const PlayerScreen({
    super.key,
    required this.musics,
    required this.initialIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final PlayerController _playerController = GetIt.instance<PlayerController>();

  @override
  void initState() {
    super.initState();
    // Eğer mevcut şarkı aynı değilse, yeni seçileni oynat
    if (_playerController.currentMusic?.youtubeId != widget.musics[widget.initialIndex].youtubeId) {
      _playerController.onMusicSelect(
        widget.musics[widget.initialIndex],
        playlist: widget.musics,
        index: widget.initialIndex,
      );
    }
    _playerController.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _playerController.removeListener(_onControllerChange);
    super.dispose();
  }

  void _showPlaylistSheet() {
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

  void _showShareSheet() {
    if (_playerController.currentMusic == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareSheet(music: _playerController.currentMusic!),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white70),
              title: const Text("Paylaş", style: TextStyle(color: Colors.white, fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                _showShareSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_outlined, color: Colors.white70),
              title: const Text("Çalma sırasını düzenle", style: TextStyle(color: Colors.white, fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMusic = _playerController.currentMusic;
    if (currentMusic == null) return const Scaffold(backgroundColor: Colors.black);

    final bool isLiked = _playerController.isCurrentLiked(currentMusic.youtubeId);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (_playerController.dominantColor ?? Colors.blueGrey[900]!).withOpacity(0.8),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 35),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(), // Boşluk bırak
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: _showOptionsMenu,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: YouTubeAudioPlayer(
                  videoId: currentMusic.youtubeId,
                  title: currentMusic.name,
                ),
              ),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currentMusic.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          Text(currentMusic.desc, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.redAccent : Colors.white,
                        size: 32,
                      ),
                      onPressed: () => _playerController.toggleLike(currentMusic),
                    ),
                    IconButton(
                      icon: const Icon(Icons.playlist_add, color: Colors.white, size: 32),
                      onPressed: _showPlaylistSheet,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // ✅ YouTube embedded player'ın yerleşik kontrolleri vardır
              // PlayerControls devre dışı bırakıldı - embedded YouTube player kullanılıyor
              // Eskileri (next/prev) mini-player'da gösterilecek
            ],
          ),
        ),
      ),
    );
  }
}
