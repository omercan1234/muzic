import 'package:flutter/material.dart';
import 'package:muzik/models/music.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class Search extends StatefulWidget {
  final Function onMusicSelect;
  const Search(this.onMusicSelect, {Key? key}) : super(key: key);

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  List<Music> _searchResults = [];
  bool _isLoading = false;

  Future<void> _searchYouTube(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      // NewPipe Mantığı: Eğer girdi bir link ise direkt videoyu getir, değilse ara
      Video? directVideo;
      var videoId = VideoId.parseVideoId(query);
      if (videoId != null) {
        directVideo = await _yt.videos.get(videoId);
      }

      if (directVideo != null) {
        _searchResults = [
          Music(
            name: directVideo.title,
            image: directVideo.thumbnails.mediumResUrl,
            desc: directVideo.author,
            youtubeId: directVideo.id.value,
          )
        ];
      } else {
        // Normal arama işlemi
        var searchList = await _yt.search.search(query).timeout(const Duration(seconds: 15));
        
        _searchResults = searchList.map((video) => Music(
          name: video.title,
          image: video.thumbnails.mediumResUrl,
          desc: video.author,
          youtubeId: video.id.value,
        )).toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Arama başarısız: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _yt.close(); // Bellek sızıntısını önlemek için kapatıyoruz
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 40, 16, 20),
                child: Text(
                  "Ara",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _searchYouTube,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "Ne dinlemek istersin?",
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.black),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else if (_searchResults.isEmpty)
              SliverToBoxAdapter(child: _buildBrowseCategories())
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final music = _searchResults[index];
                    return ListTile(
                      onTap: () => widget.onMusicSelect(music),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          music.image,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                            Container(width: 50, height: 50, color: Colors.grey),
                        ),
                      ),
                      title: Text(
                        music.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        music.desc,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    );
                  }, childCount: _searchResults.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseCategories() {
    final List<Map<String, dynamic>> categories = [
      {"title": "Pop", "color": Colors.pink},
      {"title": "Rock", "color": Colors.red},
      {"title": "Hip-Hop", "color": Colors.orange},
      {"title": "Jazz", "color": Colors.blue},
      {"title": "Focus", "color": Colors.green},
      {"title": "Chill", "color": Colors.purple},
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Hepsine göz at",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: categories[index]["color"],
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(12),
                child: Text(
                  categories[index]["title"],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
