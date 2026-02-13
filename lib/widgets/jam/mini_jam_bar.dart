import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../controllers/jam_controller.dart';
import '../../screens/jam_screen.dart';
import '../../services/navigation_service.dart';

class MiniJamBar extends StatelessWidget {
  const MiniJamBar({super.key});

  @override
  Widget build(BuildContext context) {
    final jamController = GetIt.instance<JamController>();

    return ListenableBuilder(
      listenable: jamController,
      builder: (context, _) {
        if (jamController.currentJam == null || !jamController.isMinimized) {
          return const SizedBox.shrink();
        }

        final jam = jamController.currentJam!;
        final activeMember = jam.members[jam.hostId] ?? jam.members.values.first;
        
        // ✅ KONUŞAN KİŞİYİ BUL (Eğer host konuşmuyorsa konuşan ilk kişiyi göster)
        var speakerUid = jam.hostId;
        if (jamController.activeSpeakers.isNotEmpty) {
          speakerUid = jamController.activeSpeakers.keys.first;
        }
        final speaker = jam.members[speakerUid] ?? activeMember;
        final isSpeaking = jamController.activeSpeakers.containsKey(speakerUid);

        return Positioned(
          left: jamController.overlayPosition.dx,
          top: jamController.overlayPosition.dy,
          child: Draggable(
            feedback: _buildDiscordBubble(speaker, isSpeaking: isSpeaking, isDragging: true),
            childWhenDragging: const SizedBox.shrink(),
            onDragEnd: (details) {
              jamController.updatePosition(details.offset);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                jamController.setMinimized(false);
                NavigationService.navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (context) => const JamScreen())
                );
              },
              child: _buildDiscordBubble(speaker, isSpeaking: isSpeaking),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscordBubble(dynamic member, {bool isSpeaking = false, bool isDragging = false}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 85,
        height: 85,
        decoration: BoxDecoration(
          color: const Color(0xFF36393F), 
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSpeaking 
                ? const Color(0xFF1DB954).withOpacity(0.4) 
                : Colors.black.withOpacity(isDragging ? 0.6 : 0.4),
              blurRadius: isSpeaking ? 20 : 15,
              spreadRadius: isSpeaking ? 4 : 2,
            )
          ],
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 55, height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSpeaking ? const Color(0xFF1DB954) : Colors.transparent, 
                width: 3
              ),
            ),
            child: ClipOval(
              child: (member.pp != null && member.pp.isNotEmpty)
                  ? (member.pp.startsWith('http') 
                      ? Image.network(member.pp, fit: BoxFit.cover)
                      : Image.file(File(member.pp), fit: BoxFit.cover))
                  : Container(
                      color: const Color(0xFF2F3136),
                      child: const Icon(Icons.person, color: Colors.white54, size: 30),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
