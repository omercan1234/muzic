import 'package:flutter/material.dart';
import 'package:muzik/models/music.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class MiniPlayer extends StatelessWidget {
  final Music? music;
  final YoutubePlayerController? controller;
  final bool isPlaying;
  final bool isPlayerReady;
  final bool isLiked;
  final Color? dominantColor;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onShowPlaylist;
  final VoidCallback onTap; // 🆕 Tıklama aksiyonu eklendi

  const MiniPlayer({
    Key? key,
    required this.music,
    required this.controller,
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.02, vertical: 4),
      child: GestureDetector(
        onTap: onTap, // 🆕 Üzerine basınca tam ekran açılsın
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: playerHeight,
            decoration: BoxDecoration(
              color: dominantColor ?? Colors.blueGrey[900],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            music!.image,
                            width: imageSize,
                            height: imageSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                music!.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                music!.desc,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: (controller != null && isPlayerReady)
                              ? onPlayPause
                              : null,
                        ),
                        AnimatedScale(
                          scale: isLiked ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: IconButton(
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.redAccent : Colors.white,
                              size: 24,
                            ),
                            onPressed: onLike,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.playlist_add,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: onShowPlaylist,
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                ),
                if (controller != null && isPlayerReady)
                  SizedBox(
                    height: 3,
                    child: ProgressBar(
                      controller: controller!,
                      isExpanded: true,
                      colors: const ProgressBarColors(
                        playedColor: Colors.white,
                        handleColor: Colors.transparent,
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.black26,
                      ),
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
