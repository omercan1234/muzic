import 'package:flutter/material.dart';
import 'package:muzik/models/music.dart';
import 'package:get_it/get_it.dart';
import 'package:audio_service/audio_service.dart';
import 'package:muzik/controllers/player_controller.dart';

class MiniPlayerWidget extends StatelessWidget {
  final Music? music;
  final bool isPlaying;
  final bool isPlayerReady;
  final bool isLiked;
  final Color? dominantColor;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onShowPlaylist;
  final VoidCallback onTap;

  const MiniPlayerWidget({
    Key? key,
    required this.music,
    required this.isPlaying,
    required this.isPlayerReady,
    required this.isLiked,
    required this.dominantColor,
    required this.onPlayPause,
    required this.onLike,
    required this.onShowPlaylist,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (music == null) return const SizedBox();

    final size = MediaQuery.of(context).size;
    final playerHeight = (size.height * 0.085).clamp(68.0, 85.0);
    final imageSize = playerHeight * 0.6;
    final PlayerController playerController = GetIt.instance<PlayerController>();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.02, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: playerHeight,
            decoration: BoxDecoration(
              color: dominantColor ?? Colors.blueGrey[900],
            ),
            child: Stack(
              children: [
                // Ana İçerik
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          music!.image,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: imageSize,
                            height: imageSize,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              music!.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              music!.desc,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!isPlayerReady)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        )
                      else
                        IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 28),
                          onPressed: onPlayPause,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.redAccent : Colors.white, size: 24),
                        onPressed: onLike,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_add, color: Colors.white, size: 24),
                        onPressed: onShowPlaylist,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                // Spotify Tarzı Alt Progress Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: StreamBuilder<PlaybackState>(
                    stream: playerController.audioHandler.playbackState,
                    builder: (context, snapshot) {
                      final playbackState = snapshot.data;
                      final position = playbackState?.position ?? Duration.zero;
                      final duration = playerController.audioHandler.mediaItem.value?.duration ?? Duration.zero;

                      double progress = 0.0;
                      if (duration.inMilliseconds > 0) {
                        progress = position.inMilliseconds / duration.inMilliseconds;
                      }

                      return Container(
                        height: 2,
                        width: double.infinity,
                        color: Colors.white.withOpacity(0.1),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
