import 'package:flutter/material.dart';

class PlayerModeSelector extends StatelessWidget {
  final bool isAudioMode;
  final Function(bool) onModeChanged;

  const PlayerModeSelector({
    super.key,
    required this.isAudioMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildModeButton("Ses", isAudioMode),
          _buildModeButton("Video", !isAudioMode),
        ],
      ),
    );
  }

  Widget _buildModeButton(String text, bool isActive) {
    return GestureDetector(
      onTap: () => onModeChanged(text == "Ses"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: isActive ? Colors.grey[800] : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
