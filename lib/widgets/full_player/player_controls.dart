import 'package:flutter/material.dart';
import '../../controllers/player_controller.dart';

class PlayerControls extends StatelessWidget {
  final PlayerController playerController;

  const PlayerControls({super.key, required this.playerController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.shuffle, 
              color: playerController.isShuffle ? const Color(0xFF1DB954) : Colors.white, 
              size: 28),
            onPressed: playerController.toggleShuffle,
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 45),
            onPressed: playerController.previousMusic,
          ),
          IconButton(
            icon: Icon(
              playerController.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.white,
              size: 85,
            ),
            onPressed: playerController.togglePlayPause,
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 45),
            onPressed: playerController.nextMusic,
          ),
          IconButton(
            icon: Icon(Icons.repeat, 
              color: playerController.isRepeat ? const Color(0xFF1DB954) : Colors.white, 
              size: 28),
            onPressed: playerController.toggleRepeat,
          ),
        ],
      ),
    );
  }
}
