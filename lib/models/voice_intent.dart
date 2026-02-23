import 'dart:convert';

enum IntentType {
  PLAY,
  PAUSE,
  NEXT,
  PREVIOUS,
  SEEK_FORWARD,
  SEEK_BACKWARD,
  PLAY_SONG,
  VOLUME_UP,
  VOLUME_DOWN,
  SET_VOLUME,
  UNKNOWN
}

class VoiceIntent {
  final IntentType intent;
  final int? seconds;
  final String? songName;
  final int? volume;

  VoiceIntent({
    required this.intent,
    this.seconds,
    this.songName,
    this.volume,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'intent': intent.name,
    };
    if (seconds != null) {
      data['seconds'] = seconds;
    }
    if (songName != null) {
      data['song_name'] = songName;
    }
    if (volume != null) {
      data['volume'] = volume;
    }
    return data;
  }

  factory VoiceIntent.fromJson(Map<String, dynamic> json) {
    return VoiceIntent(
      intent: IntentType.values.byName(json['intent']),
      seconds: json['seconds'],
      songName: json['song_name'],
      volume: json['volume'],
    );
  }

  @override
  String toString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceIntent &&
          runtimeType == other.runtimeType &&
          intent == other.intent &&
          seconds == other.seconds &&
          songName == other.songName &&
          volume == other.volume;

  @override
  int get hashCode =>
      intent.hashCode ^ seconds.hashCode ^ songName.hashCode ^ volume.hashCode;
}
