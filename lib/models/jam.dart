import 'package:muzik/models/music.dart';

class Jam {
  final String id;
  final String hostId;
  final Music? currentMusic;
  final bool isPlaying;
  final int positionInSeconds;
  final Map<String, JamMember> members;
  final List<String> authorizedUserIds;

  Jam({
    required this.id,
    required this.hostId,
    this.currentMusic,
    this.isPlaying = false,
    this.positionInSeconds = 0,
    required this.members,
    required this.authorizedUserIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hostId': hostId,
      'currentMusic': currentMusic != null ? {
        'name': currentMusic!.name,
        'image': currentMusic!.image,
        'desc': currentMusic!.desc,
        'youtubeId': currentMusic!.youtubeId,
      } : null,
      'isPlaying': isPlaying,
      'positionInSeconds': positionInSeconds,
      'authorizedUserIds': authorizedUserIds,
      // ✅ MEMBERS EKLENDİ
      'members': members.map((key, value) => MapEntry(key, value.toMap())),
      'lastUpdate': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class JamMember {
  final String uid;
  final String name;
  final String pp;
  final bool isMuted;
  final bool isDeafened;

  JamMember({
    required this.uid,
    required this.name,
    required this.pp,
    this.isMuted = false,
    this.isDeafened = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'pp': pp,
      'isMuted': isMuted,
      'isDeafened': isDeafened,
    };
  }

  factory JamMember.fromMap(Map<String, dynamic> map) {
    return JamMember(
      uid: map['uid'] ?? "",
      name: map['name'] ?? "Anonim",
      pp: map['pp'] ?? "",
      isMuted: map['isMuted'] ?? false,
      isDeafened: map['isDeafened'] ?? false,
    );
  }
}
