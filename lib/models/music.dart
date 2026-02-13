import 'package:equatable/equatable.dart';
import 'package:audio_service/audio_service.dart';

class Music extends Equatable {
  final String name;
  final String image;
  final String desc;
  final String youtubeId;

  const Music({
    required this.name,
    required this.image,
    required this.desc,
    required this.youtubeId,
  });

  // ✅ Firebase/JSON kaydı için gerekli
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'image': image,
      'desc': desc,
      'youtubeId': youtubeId,
    };
  }

  // ✅ Firebase'den veri okumak için gerekli
  factory Music.fromMap(Map<String, dynamic> map) {
    return Music(
      name: map['name'] ?? "",
      image: map['image'] ?? "",
      desc: map['desc'] ?? "",
      youtubeId: map['youtubeId'] ?? "",
    );
  }

  factory Music.fromMediaItem(MediaItem item) {
    return Music(
      name: item.title,
      image: item.artUri?.toString() ?? "",
      desc: item.album ?? "",
      youtubeId: item.id,
    );
  }

  @override
  List<Object?> get props => [name, image, desc, youtubeId];
}
