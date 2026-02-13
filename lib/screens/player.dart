import 'package:flutter/material.dart';
import 'package:muzik/models/music.dart';
import 'package:muzik/controllers/player_controller.dart';
import 'package:muzik/widgets/full_player/player_controls.dart';
import 'package:get_it/get_it.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:muzik/services/audio_handler.dart';
import 'package:rxdart/rxdart.dart';

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

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        (_playerController.audioHandler as MyAudioHandler).positionStream,
        (_playerController.audioHandler as MyAudioHandler).playbackState.map((state) => state.bufferedPosition),
        (_playerController.audioHandler as MyAudioHandler).durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      );

  @override
  void initState() {
    super.initState();
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

  // Şarkı sözlerini gösteren bottom sheet
  void _showLyrics() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Şarkı Sözleri", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const Expanded(
              child: Center(
                child: Text("Sözler YouTube'dan çekiliyor...", style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                // --- Üst Bar ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 35),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text("ŞİMDİ OYNATILIYOR", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
                const Spacer(flex: 1),
                // --- Albüm Kapak ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    currentMusic.image,
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: MediaQuery.of(context).size.width * 0.85,
                  ),
                ),
                const Spacer(flex: 1),
                // --- Başlık ve Sanatçı ---
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currentMusic.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          Text(currentMusic.desc, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.greenAccent[700] : Colors.white, size: 30),
                      onPressed: () => _playerController.toggleLike(currentMusic),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // --- Yeni Aksiyon Butonları (Yorum, Kaydet, Paylaş, İndir) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ActionButton(icon: Icons.comment_outlined, label: "2,9 B", onTap: _showLyrics),
                    _ActionButton(icon: Icons.playlist_add, label: "Kaydet", onTap: () {}),
                    _ActionButton(icon: Icons.share_outlined, label: "Paylaş", onTap: () {}),
                    _ActionButton(icon: Icons.download_for_offline_outlined, label: "İndir", onTap: () {}),
                  ],
                ),
                const SizedBox(height: 25),
                // --- Progress Bar ---
                StreamBuilder<PositionData>(
                  stream: _positionDataStream,
                  builder: (context, snapshot) {
                    final positionData = snapshot.data;
                    return ProgressBar(
                      progress: positionData?.position ?? Duration.zero,
                      buffered: positionData?.bufferedPosition ?? Duration.zero,
                      total: positionData?.duration ?? Duration.zero,
                      onSeek: _playerController.audioHandler.seek,
                      barHeight: 4.0,
                      baseBarColor: Colors.white.withOpacity(0.1),
                      progressBarColor: Colors.white,
                      bufferedBarColor: Colors.white.withOpacity(0.05),
                      thumbColor: Colors.white,
                      thumbRadius: 6.0,
                      timeLabelTextStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    );
                  },
                ),
                const SizedBox(height: 10),
                PlayerControls(playerController: _playerController),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Özel Aksiyon Butonu Widget'ı
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}
