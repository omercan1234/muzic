import 'music.dart';

class Playlist {
  final String id;
  String name;
  String image;
  String description;
  bool isPrivate;
  bool showOnProfile; // 🆕 Profilde gösterilsin mi?
  final String ownerName;
  final String ownerImage;
  final List<Music> musics;
  final DateTime createdAt;
  DateTime lastUpdatedAt;
  DateTime lastPlayedAt;

  Playlist({
    required this.id,
    required this.name,
    required this.image,
    this.description = "",
    this.isPrivate = false,
    this.showOnProfile = true, // Varsayılan olarak açık
    this.ownerName = "Kullanıcı",
    this.ownerImage = "",
    List<Music>? musics,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    DateTime? lastPlayedAt,
  })  : musics = musics ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastUpdatedAt = lastUpdatedAt ?? DateTime.now(),
        lastPlayedAt = lastPlayedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'description': description,
      'isPrivate': isPrivate,
      'showOnProfile': showOnProfile,
      'ownerName': ownerName,
      'ownerImage': ownerImage,
      'musics': musics.map((m) => {
        'name': m.name,
        'image': m.image,
        'desc': m.desc,
        'youtubeId': m.youtubeId,
      }).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'],
      name: map['name'],
      image: map['image'],
      description: map['description'] ?? "",
      isPrivate: map['isPrivate'] ?? false,
      showOnProfile: map['showOnProfile'] ?? true,
      ownerName: map['ownerName'] ?? "Kullanıcı",
      ownerImage: map['ownerImage'] ?? "",
      musics: (map['musics'] as List).map((m) => Music(
        name: m['name'],
        image: m['image'],
        desc: m['desc'],
        youtubeId: m['youtubeId'],
      )).toList(),
      createdAt: DateTime.parse(map['createdAt']),
      lastUpdatedAt: DateTime.parse(map['lastUpdatedAt']),
      lastPlayedAt: DateTime.parse(map['lastPlayedAt']),
    );
  }
}
