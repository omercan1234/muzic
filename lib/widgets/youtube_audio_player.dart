import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouTubeAudioPlayer extends StatefulWidget {
  final String videoId;
  final String title;

  const YouTubeAudioPlayer({
    required this.videoId,
    required this.title,
    Key? key,
  }) : super(key: key);

  @override
  State<YouTubeAudioPlayer> createState() => _YouTubeAudioPlayerState();
}

class _YouTubeAudioPlayerState extends State<YouTubeAudioPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
  }

  @override
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
          progressColors: const ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
          ),
          onReady: () {
            print('✅ YouTube Player hazır: ${widget.title}');
          },
          onEnded: (metaData) {
            print('⏹️ Video bitti: $metaData');
          },
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
