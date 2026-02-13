import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../controllers/player_controller.dart';
import 'playlist_screen.dart';
import '../models/playlist.dart';

class Yourlibraray extends StatelessWidget {
  const Yourlibraray({super.key});

  // ✅ KAPAK RESMİNİ ÇÖZEN AKILLI FONKSİYON
  Widget _buildPlaylistImage(String imagePath, List musics) {
    String finalPath = imagePath;
    
    // Eğer özel kapak yoksa ama şarkı varsa, ilk şarkının resmini al
    if (finalPath.isEmpty || finalPath.contains('unsplash')) { // Varsayılan unsplash resmini de boş sayalım
      if (musics.isNotEmpty) {
        finalPath = musics.first.image;
      }
    }

    if (finalPath.isEmpty) {
      return Container(color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.white24));
    }

    if (finalPath.startsWith('http')) {
      return Image.network(finalPath, width: 64, height: 64, fit: BoxFit.cover);
    } else {
      return Image.file(File(finalPath), width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildPlaylistImage("", []));
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerController = GetIt.instance<PlayerController>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Kitaplığın", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: ListenableBuilder(
        listenable: playerController,
        builder: (context, _) {
          final playlists = playerController.userPlaylists;
          final likedSongs = playerController.likedMusicsList;

          return ListView(
            children: [
              // ❤️ BEĞENİLEN ŞARKILAR
              _buildLikedSongsTile(context, likedSongs.length, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaylistScreen(
                      playlist: Playlist(
                        id: 'liked_songs',
                        name: 'Beğenilen Şarkılar',
                        image: 'https://t.scdn.co/images/3099b38030514068962f34821f4e921e.png',
                        musics: likedSongs,
                      ),
                    ),
                  ),
                );
              }),

              // 📂 KULLANICI PLAYLISTLERİ (Yeni Akıllı Kapak Sistemi)
              ...playlists.map((playlist) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _buildPlaylistImage(playlist.image, playlist.musics), // ✅ AKILLI KAPAK
                ),
                title: Text(playlist.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text("Çalma listesi • ${playlist.musics.length} şarkı", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: playlist)),
                  );
                },
              )),

              if (playlists.isEmpty && likedSongs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Text("Kendi çalma listelerini oluşturmaya başla.", style: TextStyle(color: Colors.white54)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLikedSongsTile(BuildContext context, int count, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
          ),
        ),
        child: const Icon(Icons.favorite, color: Colors.white, size: 28),
      ),
      title: const Text("Beğenilen Şarkılar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text("Çalma listesi • $count şarkı", style: const TextStyle(color: Colors.grey, fontSize: 13)),
      onTap: onTap,
    );
  }
}
