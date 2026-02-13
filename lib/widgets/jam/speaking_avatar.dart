import 'dart:io';
import 'package:flutter/material.dart';

class SpeakingAvatar extends StatefulWidget {
  final String name;
  final String imageUrl;
  final bool isSpeaking;
  final bool isMe;
  final double radius;
  final bool isHost;

  const SpeakingAvatar({
    super.key, 
    required this.name,
    required this.imageUrl, 
    required this.isSpeaking, 
    required this.isMe,
    this.radius = 35,
    this.isHost = false,
  });

  @override
  State<SpeakingAvatar> createState() => _SpeakingAvatarState();
}

class _SpeakingAvatarState extends State<SpeakingAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.isSpeaking) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SpeakingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSpeaking && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isSpeaking)
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: widget.radius * 2,
                  height: widget.radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.4), width: 2),
                  ),
                ),
              ),
            
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isSpeaking ? const Color(0xFF1DB954) : Colors.transparent, 
                  width: 3
                ),
              ),
              child: CircleAvatar(
                radius: widget.radius,
                backgroundColor: const Color(0xFF282828),
                backgroundImage: (widget.imageUrl.isNotEmpty)
                    ? (widget.imageUrl.startsWith('http') ? NetworkImage(widget.imageUrl) : FileImage(File(widget.imageUrl))) as ImageProvider
                    : null,
                child: widget.imageUrl.isEmpty ? Icon(Icons.person, color: Colors.white24, size: widget.radius * 0.8) : null,
              ),
            ),

            if (widget.isHost)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                  child: const Icon(Icons.star, size: 10, color: Colors.black),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.isMe ? "${widget.name} (Siz)" : widget.name,
          style: TextStyle(
            color: widget.isSpeaking ? const Color(0xFF1DB954) : Colors.white70,
            fontSize: 12,
            fontWeight: widget.isSpeaking ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
