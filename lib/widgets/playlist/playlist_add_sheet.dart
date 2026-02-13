import 'dart:io';
import 'package:flutter/material.dart';
import '../../controllers/player_controller.dart';
import '../../models/music.dart';
import '../../models/playlist.dart';


class PlaylistAddSheet extends StatefulWidget {
  final PlayerController playerController;
  final Music? currentMusic;
  final List<Music>? allMusics;

  const PlaylistAddSheet({
    super.key,
    required this.playerController,
    this.currentMusic,
    this.allMusics,
  });

  @override
  State<PlaylistAddSheet> createState() => _PlaylistAddSheetState();
}

class _PlaylistAddSheetState extends State<PlaylistAddSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  // 📌 Ekran ilk açıldığında ekli olanların ID'lerini burada saklayacağız
  late Set<String> _initiallyAddedPlaylistIds;

  @override
  void initState() {
    super.initState();
    _initInitiallyAddedIds();
  }

  void _initInitiallyAddedIds() {
    final playlists = widget.playerController.userPlaylists;
    _initiallyAddedPlaylistIds = playlists.where((p) {
      if (widget.allMusics != null) {
        return widget.allMusics!.every((m) => p.musics.any((target) => target.youtubeId == m.youtubeId));
      } else if (widget.currentMusic != null) {
        return widget.playerController.isInPlaylist(p.id, widget.currentMusic!);
      }
      return false;
    }).map((p) => p.id).toSet();
  }

  void _handleAction(Playlist playlist) {
    if (widget.allMusics != null) {
      bool allAlreadyExist = widget.allMusics!.every(
        (m) => playlist.musics.any((target) => target.youtubeId == m.youtubeId)
      );

      if (allAlreadyExist) {
        widget.playerController.removeAllMusicsFromPlaylist(playlist.id, widget.allMusics!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Şarkılar ${playlist.name} listesinden kaldırıldı."), duration: const Duration(milliseconds: 800), backgroundColor: Colors.redAccent)
        );
      } else {
        widget.playerController.addAllMusicsToPlaylist(playlist.id, widget.allMusics!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tüm şarkılar ${playlist.name} listesine eklendi."), duration: const Duration(milliseconds: 800), backgroundColor: Colors.green)
        );
      }
    } else if (widget.currentMusic != null) {
      widget.playerController.toggleMusicInPlaylist(playlist.id, widget.currentMusic!);
    }
  }

  void _showCreatePlaylistDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Yeni Çalma Listesi', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Liste adını girin',
            hintStyle: TextStyle(color: Colors.grey),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                widget.playerController.createPlaylist(nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('OLUŞTUR', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: ListenableBuilder(
        listenable: widget.playerController,
        builder: (context, _) {
          final playlists = widget.playerController.userPlaylists;
          
          // 🚀 SABİT ÜST LİSTE: Sadece ekran ilk açıldığında ekli olanlar
          final topSection = playlists.where((p) => _initiallyAddedPlaylistIds.contains(p.id)).toList();

          // 🔍 DİĞERLERİ: Geri kalan ve arama sorgusuna uyanlar
          final bottomSection = playlists.where((p) => 
            !_initiallyAddedPlaylistIds.contains(p.id) && 
            p.name.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

          return Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 35, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.allMusics != null ? 'Hangi listeye kopyalansın?' : 'Kaydedildiği çalma listesi', 
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: _showCreatePlaylistDialog,
                      child: const Text('Yeni çalma listesi', 
                        style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // 📌 ÜST BÖLÜM: Zaten ekli olanlar (Zıplamayı önlemek için initState'e bağlı)
              if (topSection.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.25),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: topSection.length,
                    itemBuilder: (context, index) {
                      final p = topSection[index];
                      // Tik durumu her zaman gerçek veriyi gösterir
                      bool isCurrentlyIn = false;
                      if (widget.allMusics != null) {
                        isCurrentlyIn = widget.allMusics!.every((m) => p.musics.any((target) => target.youtubeId == m.youtubeId));
                      } else if (widget.currentMusic != null) {
                        isCurrentlyIn = widget.playerController.isInPlaylist(p.id, widget.currentMusic!);
                      }

                      return _buildPlaylistTile(
                        context: context,
                        title: p.name,
                        imageUrl: p.image,
                        songCount: p.musics.length,
                        ownerName: (p.ownerName == "Kullanıcı" || p.ownerName.isEmpty) ? widget.playerController.userName : p.ownerName,
                        ownerImage: p.ownerImage.isEmpty ? widget.playerController.userProfileImage : p.ownerImage,
                        isAdded: isCurrentlyIn,
                        onTap: () => _handleAction(p),
                      );
                    },
                  ),
                ),

              // 🔍 Arama Çubuğu ve BİTTİ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFF282828), borderRadius: BorderRadius.circular(4)),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Çalma listesi bul',
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('BİTTİ', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // 📌 ALT BÖLÜM: Diğer Playlistler
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  children: [
                    if (widget.currentMusic != null && !_initiallyAddedPlaylistIds.contains('liked_songs') && 'beğenilen şarkılar'.contains(_searchQuery.toLowerCase()))
                      _buildPlaylistTile(
                        context: context,
                        title: 'Beğenilen Şarkılar',
                        isSpecial: true,
                        isAdded: widget.playerController.isCurrentLiked(widget.currentMusic!.youtubeId),
                        ownerName: widget.playerController.userName,
                        ownerImage: widget.playerController.userProfileImage,
                        onTap: () => widget.playerController.toggleLike(widget.currentMusic!),
                      ),

                    ...bottomSection.map((p) {
                      bool isCurrentlyIn = false;
                      if (widget.allMusics != null) {
                        isCurrentlyIn = widget.allMusics!.every((m) => p.musics.any((target) => target.youtubeId == m.youtubeId));
                      } else if (widget.currentMusic != null) {
                        isCurrentlyIn = widget.playerController.isInPlaylist(p.id, widget.currentMusic!);
                      }

                      return _buildPlaylistTile(
                        context: context,
                        title: p.name,
                        imageUrl: p.image,
                        songCount: p.musics.length,
                        ownerName: (p.ownerName == "Kullanıcı" || p.ownerName.isEmpty) ? widget.playerController.userName : p.ownerName,
                        ownerImage: p.ownerImage.isEmpty ? widget.playerController.userProfileImage : p.ownerImage,
                        isAdded: isCurrentlyIn,
                        onTap: () => _handleAction(p),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaylistTile({
    required BuildContext context,
    required String title,
    String? imageUrl,
    int songCount = 0,
    String? ownerName,
    String? ownerImage,
    bool isSpecial = false,
    required bool isAdded,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: isSpecial
          ? Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
                ),
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 24),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(imageUrl!, width: 52, height: 52, fit: BoxFit.cover, 
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.white24))),
            ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Row(
        children: [
          if (ownerImage != null && ownerImage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 9,
                backgroundColor: const Color(0xFF282828),
                backgroundImage: ownerImage.startsWith('http')
                    ? NetworkImage(ownerImage)
                    : FileImage(File(ownerImage)) as ImageProvider,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 9,
                backgroundColor: Color(0xFF282828),
                child: Icon(Icons.person, size: 10, color: Colors.white54),
              ),
            ),
          Text(
            isSpecial ? "Çalma listesi • $ownerName" : (ownerName ?? "Kullanıcı"), 
            style: const TextStyle(color: Colors.grey, fontSize: 12)
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          isAdded ? Icons.check_circle : Icons.add_circle_outline,
          color: isAdded ? const Color(0xFF1DB954) : Colors.white54,
          size: 28,
        ),
        onPressed: onTap,
      ),
      onTap: onTap,
    );
  }
}
