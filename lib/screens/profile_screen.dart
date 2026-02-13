import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../controllers/player_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = GetIt.instance<PlayerController>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: playerController,
        builder: (context, _) {
          // ✅ Sadece "Profilde Göster" işaretli playlistleri filtrele
          final profilePlaylists = playerController.userPlaylists
              .where((p) => p.showOnProfile)
              .toList();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                backgroundColor: Colors.black,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFD81B60), Colors.black],
                        stops: [0.0, 0.9],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80, left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 70,
                                backgroundColor: const Color(0xFF282828),
                                backgroundImage: playerController.userProfileImage.isNotEmpty
                                    ? FileImage(File(playerController.userProfileImage)) as ImageProvider
                                    : null,
                                child: playerController.userProfileImage.isEmpty
                                    ? const Icon(Icons.person, size: 70, color: Colors.white24)
                                    : null,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      playerController.userName,
                                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "22 takipçi • 111 takip ediliyor",
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              _buildActionButton("Düzenle"),
                              const SizedBox(width: 15),
                              const Icon(Icons.settings_outlined, color: Colors.white70, size: 26),
                              const SizedBox(width: 20),
                              const Icon(Icons.more_vert, color: Colors.white70, size: 26),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 15),
                  child: Text("Çalma Listeleri", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),

              // ✅ Filtrelenmiş listeyi göster
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final playlist = profilePlaylists[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _buildPlaylistCover(playlist),
                      ),
                      title: Text(playlist.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text("${playlist.musics.length} kaydetme", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    );
                  },
                  childCount: profilePlaylists.length,
                ),
              ),

              if (profilePlaylists.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text("Profilinde gösterilen çalma listesi yok.", style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaylistCover(playlist) {
    String imagePath = playlist.image;
    if (imagePath.isEmpty && playlist.musics.isNotEmpty) {
      imagePath = playlist.musics.first.image;
    }

    if (imagePath.isEmpty) {
      return Container(width: 52, height: 52, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.white24));
    }

    return imagePath.startsWith('http')
        ? Image.network(imagePath, width: 52, height: 52, fit: BoxFit.cover)
        : Image.file(File(imagePath), width: 52, height: 52, fit: BoxFit.cover);
  }

  Widget _buildActionButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.white30), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
