import 'package:flutter/material.dart';
import 'package:muzik/models/music.dart';
import 'package:muzik/controllers/player_controller.dart';
import 'package:muzik/widgets/full_player/player_controls.dart';
import 'package:muzik/widgets/playlist/playlist_add_sheet.dart';
import 'package:get_it/get_it.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:muzik/services/audio_handler.dart';
import 'package:muzik/services/music_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final MusicService _musicService = MusicService();
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    _commentController.dispose();
    super.dispose();
  }

  // --- Yorum Gönderme ---
  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _playerController.currentMusic == null) return;
    try {
      await _firestore.collection('comments').doc(_playerController.currentMusic!.youtubeId).collection('messages').add({
        'senderId': _auth.currentUser?.uid ?? 'anonim',
        'senderName': _playerController.userName,
        'senderPP': _playerController.userProfileImage,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _commentController.clear();
    } catch (e) {}
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const Padding(padding: EdgeInsets.all(16.0), child: Text("Yorumlar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('comments').doc(_playerController.currentMusic!.youtubeId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white24));
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(backgroundImage: data['senderPP'] != null && data['senderPP'] != "" ? NetworkImage(data['senderPP']) : null, child: data['senderPP'] == "" ? const Icon(Icons.person) : null),
                        title: Text(data['senderName'] ?? "Kullanıcı", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text(data['text'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 8),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _commentController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Yorum ekle...", hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)))),
                  const SizedBox(width: 10),
                  GestureDetector(onTap: _sendComment, child: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.send, color: Colors.white, size: 20))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Şarkı Sözleri (LRCLIB + YouTube Fallback) ---
  void _showLyrics() {
    final music = _playerController.currentMusic!;
    showModalBottomSheet(
      context: context,
      backgroundColor: (_playerController.dominantColor ?? Colors.blueGrey[900]!).withOpacity(0.95),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 30),
              Text(music.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              Text(music.desc, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18)),
              const SizedBox(height: 30),
              Expanded(
                child: FutureBuilder<String?>(
                  future: _musicService.getLyrics(music.name, music.desc, videoId: music.youtubeId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white70));
                    return SingleChildScrollView(
                      child: Text(
                        snapshot.data ?? "Sözler bulunamadı.",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, height: 1.6),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [(_playerController.dominantColor ?? Colors.blueGrey[900]!).withOpacity(0.8), Colors.black])),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 35), onPressed: () => Navigator.pop(context)),
                    const Text("ŞİMDİ OYNATILIYOR", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
                  ],
                ),
                const Spacer(),
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(currentMusic.image, fit: BoxFit.cover, width: MediaQuery.of(context).size.width * 0.85, height: MediaQuery.of(context).size.width * 0.85)),
                const Spacer(),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(currentMusic.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), Text(currentMusic.desc, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16), overflow: TextOverflow.ellipsis)])),
                    IconButton(icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.greenAccent[700] : Colors.white, size: 30), onPressed: () => _playerController.toggleLike(currentMusic)),
                  ],
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_ActionButton(icon: Icons.comment_outlined, label: "Yorumlar", onTap: _showComments), const SizedBox(width: 8), _ActionButton(icon: Icons.lyrics_outlined, label: "Sözler", onTap: _showLyrics), const SizedBox(width: 8), _ActionButton(icon: Icons.playlist_add, label: "Kaydet", onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => PlaylistAddSheet(playerController: _playerController, currentMusic: currentMusic))), const SizedBox(width: 8), _ActionButton(icon: Icons.share_outlined, label: "Paylaş", onTap: () {})])),
                const SizedBox(height: 25),
                StreamBuilder<PositionData>(
                  stream: _positionDataStream,
                  builder: (context, snapshot) {
                    final positionData = snapshot.data;
                    return ProgressBar(progress: positionData?.position ?? Duration.zero, buffered: positionData?.bufferedPosition ?? Duration.zero, total: positionData?.duration ?? Duration.zero, onSeek: _playerController.audioHandler.seek, barHeight: 4.0, baseBarColor: Colors.white.withOpacity(0.1), progressBarColor: Colors.white, bufferedBarColor: Colors.white.withOpacity(0.05), thumbColor: Colors.white, thumbRadius: 6.0, timeLabelTextStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12));
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))])));
  }
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}
