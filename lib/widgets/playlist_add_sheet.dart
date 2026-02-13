import 'package:flutter/material.dart';
import '../controllers/player_controller.dart';
import '../models/music.dart';
import '../models/playlist.dart';

enum SortOption { alphabetical, recentlyUpdated, recentlyAdded, recentlyPlayed }

class PlaylistAddSheet extends StatefulWidget {
  final PlayerController playerController;
  final Music currentMusic;

  const PlaylistAddSheet({
    super.key,
    required this.playerController,
    required this.currentMusic,
  });

  @override
  State<PlaylistAddSheet> createState() => _PlaylistAddSheetState();
}

class _PlaylistAddSheetState extends State<PlaylistAddSheet> {
  final TextEditingController _playlistNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  SortOption _selectedSort = SortOption.recentlyUpdated;

  late Set<String> _initialAddedIds;
  late bool _initialIsLiked;

  @override
  void initState() {
    super.initState();
    _initialAddedIds = widget.playerController.userPlaylists
        .where((p) => widget.playerController.isInPlaylist(p.id, widget.currentMusic))
        .map((p) => p.id)
        .toSet();

    // ✅ BURASI DÜZELTİLDİ: Fonksiyon olarak çağırıldı
    _initialIsLiked = widget.playerController.isCurrentLiked(widget.currentMusic.youtubeId);
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Text("Sıralama ölçütü", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          _buildSortTile(SortOption.recentlyUpdated, "Yakın zamanda güncellenenler"),
          _buildSortTile(SortOption.recentlyAdded, "Yeni eklenenler"),
          _buildSortTile(SortOption.alphabetical, "Alfabetik"),
          _buildSortTile(SortOption.recentlyPlayed, "Yakın zamanda çalanlar"),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSortTile(SortOption option, String title) {
    bool isSelected = _selectedSort == option;
    return ListTile(
      title: Text(title, style: TextStyle(color: isSelected ? const Color(0xFF1DB954) : Colors.white, fontSize: 14)),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF1DB954)) : null,
      onTap: () {
        setState(() => _selectedSort = option);
        Navigator.pop(context);
      },
    );
  }

  List<Playlist> _getSortedPlaylists(List<Playlist> list) {
    List<Playlist> sorted = List.from(list);
    switch (_selectedSort) {
      case SortOption.alphabetical:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.recentlyUpdated:
        sorted.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
        break;
      case SortOption.recentlyAdded:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.recentlyPlayed:
        sorted.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
        break;
    }
    return sorted;
  }

  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Yeni Çalma Listesi', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: _playlistNameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Çalma listesi adını girin',
            hintStyle: TextStyle(color: Colors.grey),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (_playlistNameController.text.isNotEmpty) {
                widget.playerController.createPlaylist(_playlistNameController.text);
                _playlistNameController.clear();
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
          final allPlaylists = widget.playerController.userPlaylists;
          final sortedAll = _getSortedPlaylists(allPlaylists);

          final topPlaylists = sortedAll.where((p) => _initialAddedIds.contains(p.id)).toList();
          final bottomPlaylists = sortedAll.where((p) => 
            !_initialAddedIds.contains(p.id) &&
            p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          return Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 35, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2))),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kaydedildiği çalma listesi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: _showCreatePlaylistDialog,
                      child: const Text('Yeni çalma listesi', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    if (_initialIsLiked)
                      _buildPlaylistTile(
                        title: 'Beğenilen Şarkılar',
                        isSpecial: true,
                        // ✅ DÜZELTİLDİ: Fonksiyon olarak çağırıldı
                        isAdded: widget.playerController.isCurrentLiked(widget.currentMusic.youtubeId),
                        // ✅ DÜZELTİLDİ: Music parametresi ile çağırıldı
                        onTap: () => widget.playerController.toggleLike(widget.currentMusic),
                      ),
                    
                    ...topPlaylists.map((playlist) => _buildPlaylistTile(
                      title: playlist.name,
                      imageUrl: playlist.image,
                      songCount: playlist.musics.length,
                      isAdded: widget.playerController.isInPlaylist(playlist.id, widget.currentMusic),
                      onTap: () => widget.playerController.toggleMusicInPlaylist(playlist.id, widget.currentMusic),
                    )),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
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
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _showSortMenu,
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(color: const Color(0xFF282828), borderRadius: BorderRadius.circular(4)),
                              alignment: Alignment.center,
                              child: const Text('Sırala', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!_initialIsLiked && 'beğenilen şarkılar'.contains(_searchQuery.toLowerCase()))
                      _buildPlaylistTile(
                        title: 'Beğenilen Şarkılar',
                        isSpecial: true,
                        // ✅ DÜZELTİLDİ
                        isAdded: widget.playerController.isCurrentLiked(widget.currentMusic.youtubeId),
                        // ✅ DÜZELTİLDİ
                        onTap: () => widget.playerController.toggleLike(widget.currentMusic),
                      ),

                    ...bottomPlaylists.map((playlist) => _buildPlaylistTile(
                      title: playlist.name,
                      imageUrl: playlist.image,
                      songCount: playlist.musics.length,
                      isAdded: widget.playerController.isInPlaylist(playlist.id, widget.currentMusic),
                      onTap: () => widget.playerController.toggleMusicInPlaylist(playlist.id, widget.currentMusic),
                    )),
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
    required String title,
    String? imageUrl,
    int songCount = 0,
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
      subtitle: isSpecial 
          ? null 
          : Text(songCount == 0 ? 'Boş' : '$songCount şarkı', style: const TextStyle(color: Colors.grey, fontSize: 13)),
      trailing: Icon(
        isAdded ? Icons.check_circle : Icons.add_circle_outline,
        color: isAdded ? Colors.green : Colors.grey[400],
        size: 28,
      ),
      onTap: onTap,
    );
  }
}
