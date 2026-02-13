import '../models/playlist.dart';
import '../models/music.dart';

class PlaylistOperation {
  static List<Playlist> getPlaylists() {
    return [
      Playlist(
        id: '1',
        name: 'Chill Vibes',
        image: 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?q=80&w=2070&auto=format&fit=crop',
        musics: [
          const Music(
            name: 'Lofi Beats - Radio',
            image: 'https://i.ytimg.com/vi/jfKfPfyJRdk/maxresdefault.jpg',
            desc: 'Relaxing lo-fi beats',
            youtubeId: 'jfKfPfyJRdk',
          ),
          const Music(
            name: 'Rainy Night in Tokyo',
            image: 'https://i.ytimg.com/vi/5Wn_vYcl-A0/maxresdefault.jpg',
            desc: 'Ambient Lo-fi',
            youtubeId: '5Wn_vYcl-A0',
          ),
        ],
      ),
      Playlist(
        id: '2',
        name: 'Workout Energy',
        image: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=2070&auto=format&fit=crop',
        musics: [
          const Music(
            name: 'Coffee Shop Blues',
            image: 'https://i.ytimg.com/vi/h2vW-rr9Uls/maxresdefault.jpg',
            desc: 'Smooth Jazz Music',
            youtubeId: 'h2vW-rr9Uls',
          ),
        ],
      ),
    ];
  }
}
