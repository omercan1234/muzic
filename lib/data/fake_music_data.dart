import 'package:muzik/models/music.dart';

class FakeMusicData {
  static final List<Music> musicList = [
    const Music(
      name: 'Lofi Girl - Radio',
      desc: 'Beats to relax/study',
      image: 'https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg',
      youtubeId: 'jfKfPfyJRdk',
    ),
    const Music(
      name: 'Coffee Shop Blues',
      desc: 'Smooth Jazz Music',
      image: 'https://i.ytimg.com/vi/h2vW-rr9Uls/hqdefault.jpg',
      youtubeId: 'h2vW-rr9Uls',
    ),
    const Music(
      name: 'Rainy Night in Tokyo',
      desc: 'Ambient Lo-fi',
      image: 'https://i.ytimg.com/vi/5Wn_vYcl-A0/hqdefault.jpg',
      youtubeId: '5Wn_vYcl-A0',
    ),
  ];
}
