import 'package:flutter_test/flutter_test.dart';
import 'package:muzik/models/music.dart';

void main() {
  test('Music model fromMap test', () {
    final map = {
      'name': 'Test Song',
      'image': 'https://example.com/image.jpg',
      'desc': 'Test Artist',
      'youtubeId': 'abc123',
      'durationMs': 180000,
    };

    final music = Music.fromMap(map);

    expect(music.name, 'Test Song');
    expect(music.image, 'https://example.com/image.jpg');
    expect(music.desc, 'Test Artist');
    expect(music.youtubeId, 'abc123');
    expect(music.duration?.inMilliseconds, 180000);
  });
}
