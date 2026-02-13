import 'package:equatable/equatable.dart';
import 'package:audio_service/audio_service.dart';

class Music extends Equatable {
  final String name;
  final String image;
  final String desc;
  final String youtubeId;
  final Duration? duration;

  const Music({
    required this.name,
    required this.image,
    required this.desc,
    required this.youtubeId,
    this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'image': image,
      'desc': desc,
      'youtubeId': youtubeId,
      'durationMs': duration?.inMilliseconds,
    };
  }

  factory Music.fromMap(Map<String, dynamic> map) {
    return Music(
      name: map['name'] ?? "",
      image: map['image'] ?? "",
      desc: map['desc'] ?? "",
      youtubeId: map['youtubeId'] ?? "",
      duration: map['durationMs'] != null ? Duration(milliseconds: map['durationMs']) : null,
    );
  }

  factory Music.fromMediaItem(MediaItem item) {
    return Music(
      name: item.title,
      image: item.artUri?.toString() ?? "",
      desc: item.artist ?? "",
      youtubeId: item.id,
      duration: item.duration,
    );
  }

  @override
  List<Object?> get props => [name, image, desc, youtubeId, duration];
}
