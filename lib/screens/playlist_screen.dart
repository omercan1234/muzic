import 'dart:io';
import 'package:flutter/material.dart';
import 'package:muzik/models/playlist.dart';
import 'package:muzik/screens/player.dart';
import 'package:muzik/controllers/player_controller.dart';
import 'package:muzik/controllers/jam_controller.dart'; 
import 'package:muzik/screens/jam_screen.dart';
import 'package:muzik/screens/profile_screen.dart';
import 'package:muzik/screens/playlist_edit_screen.dart';
import 'package:muzik/widgets/playlist/playlist_add_sheet.dart'; 
import 'package:get_it/get_it.dart';
import 'package:palette_generator/palette_generator.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool isEditing = false;
  Color? dominantColor; 
  final playerController = GetIt.instance<PlayerController>();
  final jamController = GetIt.instance<JamController>(); 

  @override
  void initState() {
    super.initState();
    _updatePalette(); 
  }

  Future<void> _updatePalette() async {
    Playlist current;
    try {
      current = playerController.userPlaylists.firstWhere((p) => p.id == widget.playlist.id);
    } catch (e) {
      current = widget.playlist;
    }

    final String imagePath = current.image.isNotEmpty 
        ? current.image 
        : (current.musics.isNotEmpty ? current.musics.first.image : "");

    if (imagePath.isEmpty) return;

    try {
      final ImageProvider imageProvider = imagePath.startsWith('http')
          ? NetworkImage(imagePath)
          : FileImage(File(imagePath)) as ImageProvider;

      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(imageProvider);
      
      if (mounted) {
        setState(() {
          dominantColor = palette.vibrantColor?.color ?? palette.dominantColor?.color ?? Colors.blueGrey[900];
        });
      }
    } catch (e) {
      debugPrint("Renk analiz hatası: $e");
    }
  }

  void _showMenu(BuildContext context, Playlist currentPlaylist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            
            _buildMenuTile(Icons.speaker_group_outlined, "Jam başlat", () async {
              final navigator = Navigator.of(this.context); 
              Navigator.pop(context);
              
              final firstMusic = currentPlaylist.musics.isNotEmpty ? currentPlaylist.musics.first : null;
              
              await jamController.startJam(firstMusic);
              
              if (mounted) {
                navigator.push(MaterialPageRoute(builder: (context) => const JamScreen()));
              }
            }),

            _buildMenuTile(Icons.edit_note_outlined, "Adı ve ayrıntıları düzenle", () async {
              Navigator.pop(context);
              await Navigator.push(context, MaterialPageRoute(builder: (context) => PlaylistEditScreen(playlist: currentPlaylist)));
              _updatePalette();
            }),

            _buildMenuTile(
              currentPlaylist.showOnProfile ? Icons.person_remove_outlined : Icons.person_add_alt_1_outlined, 
              currentPlaylist.showOnProfile ? "Profilden kaldır" : "Profile ekle", 
              () {
                playerController.toggleShowOnProfile(currentPlaylist.id);
                Navigator.pop(context);
              }
            ),

            _buildMenuTile(Icons.swap_vert_outlined, "Şarkıların yerini değiştir / sil", () {
              Navigator.pop(context);
              setState(() => isEditing = true);
            }),

            _buildMenuTile(Icons.playlist_add, "Başka çalma listesine ekle", () {
              Navigator.pop(context);
              _showAddToPlaylistSheet(currentPlaylist);
            }),

            _buildMenuTile(Icons.delete_outline, "Çalma listesini sil", () {
              playerController.deletePlaylist(widget.playlist.id);
              Navigator.pop(context);
              Navigator.pop(context);
            }, isDestructive: true),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  void _showAddToPlaylistSheet(Playlist currentPlaylist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaylistAddSheet(
        playerController: playerController,
        allMusics: currentPlaylist.musics,
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white70),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontSize: 15)),
      onTap: onTap,
    );
  }

  Widget _buildPlaylistCover(String imagePath) {
    if (imagePath.isEmpty) {
      return Container(color: const Color(0xFF282828), child: const Icon(Icons.music_note, color: Colors.white24, size: 100));
    }
    if (imagePath.startsWith('http')) {
      return Image.network(imagePath, fit: BoxFit.cover);
    } else {
      return Image.file(File(imagePath), fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildPlaylistCover(""));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerController,
      builder: (context, _) {
        Playlist currentPlaylist;
        try {
          currentPlaylist = playerController.userPlaylists.firstWhere((p) => p.id == widget.playlist.id);
        } catch (e) {
          currentPlaylist = widget.playlist;
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: AnimatedContainer( 
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (dominantColor ?? Colors.blueGrey[900]!).withOpacity(0.7),
                  Colors.black,
                ],
                stops: const [0.0, 0.6],
              ),
            ),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: Icon(isEditing ? Icons.close : Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (isEditing) setState(() => isEditing = false);
                      else Navigator.pop(context);
                    },
                  ),
                  actions: [
                    if (isEditing)
                      TextButton(onPressed: () => setState(() => isEditing = false), child: const Text("BİTTİ", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                    else
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () => _showMenu(context, currentPlaylist),
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isEditing) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            width: 240, height: 240,
                            decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)]),
                            child: ClipRRect(borderRadius: BorderRadius.circular(4), child: _buildPlaylistCover(currentPlaylist.image)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentPlaylist.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              if (currentPlaylist.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(currentPlaylist.description, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
                                ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12, backgroundColor: const Color(0xFF282828),
                                      backgroundImage: currentPlaylist.ownerImage.isNotEmpty ? (currentPlaylist.ownerImage.startsWith('http') ? NetworkImage(currentPlaylist.ownerImage) : FileImage(File(currentPlaylist.ownerImage))) as ImageProvider : null,
                                      child: currentPlaylist.ownerImage.isEmpty ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(currentPlaylist.ownerName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text("${currentPlaylist.musics.length} şarkı", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white10),
                      ],
                    ],
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final music = currentPlaylist.musics[index];
                      if (isEditing) {
                        return ListTile(
                          key: ValueKey(music.youtubeId),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                          leading: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => playerController.removeMusicFromPlaylist(currentPlaylist.id, music.youtubeId)),
                          title: Text(music.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text(music.desc, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          trailing: const Icon(Icons.menu, color: Colors.white54),
                        );
                      }
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(music.image, width: 50, height: 50, fit: BoxFit.cover)),
                        title: Text(music.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(music.desc, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        trailing: const Icon(Icons.more_vert, color: Colors.grey),
                        onTap: () {
                          playerController.onMusicSelect(music, playlist: currentPlaylist.musics, index: index);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(musics: currentPlaylist.musics, initialIndex: index)));
                        },
                      );
                    },
                    childCount: currentPlaylist.musics.length,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
 }
