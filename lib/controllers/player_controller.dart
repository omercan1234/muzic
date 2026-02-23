import 'dart:async';
import 'package:flutter/material.dart';
import 'package:muzik/models/music.dart';
import 'package:muzik/models/playlist.dart' as model;
import 'package:palette_generator/palette_generator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../services/music_service.dart';
import 'package:muzik/services/voice_assistant_service.dart';
import 'package:muzik/models/voice_intent.dart';
import 'jam_controller.dart';

class PlayerController extends ChangeNotifier {
  final VoiceAssistantService _voiceAssistantService = VoiceAssistantService();
  final MyAudioHandler _audioHandler = GetIt.instance<MyAudioHandler>();
  final MusicService _musicService = MusicService();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String userName = "Kullanıcı";
  String userProfileImage = "";
  double musicVolume = 100;

  String? get currentUserUid => _auth.currentUser?.uid;
  AudioHandler get audioHandler => _audioHandler;

  final List<Music> likedMusicsList = []; 
  final List<model.Playlist> userPlaylists = [];

  // Mevcut yükleme işlemini takip etmek için
  String? _loadingVideoId;

  PlayerController() {
    _auth.authStateChanges().listen((user) {
      if (user != null) { _loadDataFromFirebase(); } else { _clearLocalData(); }
    });
    
    _audioHandler.playbackState.listen((state) {
      isPlaying = state.playing;
      isPlayerReady = state.processingState != AudioProcessingState.loading && 
                      state.processingState != AudioProcessingState.buffering;
      notifyListeners();
    });

    _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        // Sadece gerçekten değiştiyse güncelle
        if (_currentMusic?.youtubeId != item.id) {
          _currentMusic = Music.fromMediaItem(item);
          _updateDominantColor(_currentMusic!.image);
          notifyListeners();
        }
      }
    });
  }

  // UI Değişkenleri
  List<Music> currentPlaylist = []; int currentIndex = 0;
  Music? _currentMusic;
  Music? get currentMusic => _currentMusic;
  bool isPlaying = false; bool isPlayerReady = false; Color? dominantColor;
  bool isShuffle = false; bool isRepeat = false; bool showHeartExplosion = false;

  // --- Oynatma Metodları ---
  void onMusicSelect(Music music, {List<Music>? playlist, int? index}) async {
    if (!_canControlMusic()) return;

    // Eğer zaten aynı şarkı çalıyorsa tekrar yükleme (Opsiyonel: Eğer istersen bunu kaldırabilirsin)
    if (_currentMusic?.youtubeId == music.youtubeId && isPlaying) return;

    currentPlaylist = playlist ?? [music];
    currentIndex = index ?? 0;
    _currentMusic = music;
    isPlayerReady = false; 
    _loadingVideoId = music.youtubeId; // Şu an bu ID yükleniyor
    notifyListeners();

    // Önce mevcut çalmayı durdur (Temiz geçiş için)
    await _audioHandler.stop();

    _loadAndPlay(music);
    _updateJamStateIfNeeded(music);
  }

  Future<void> syncMusic(Music music, bool shouldPlay, {int? positionInSeconds}) async {
    if (currentMusic?.youtubeId != music.youtubeId) {
      await _loadAndPlay(music, autoPlay: shouldPlay);
    }
    shouldPlay ? _audioHandler.play() : _audioHandler.pause();
    if (positionInSeconds != null) {
      _audioHandler.seek(Duration(seconds: positionInSeconds));
    }
  }

  void resetHeartExplosion() {
    showHeartExplosion = false;
    notifyListeners();
  }

  void togglePlayPause() {
    if (!_canControlMusic()) return;
    isPlaying ? _audioHandler.pause() : _audioHandler.play();
    _updateJamStateIfNeeded(null, isPlaying: !isPlaying);
  }

  void nextMusic() {
    if (!_canControlMusic() || currentPlaylist.isEmpty) return;
    currentIndex = (currentIndex + 1) % currentPlaylist.length;
    onMusicSelect(currentPlaylist[currentIndex], playlist: currentPlaylist, index: currentIndex);
  }

  void previousMusic() {
    if (!_canControlMusic() || currentPlaylist.isEmpty) return;
    currentIndex = currentIndex > 0 ? currentIndex - 1 : currentPlaylist.length - 1;
    onMusicSelect(currentPlaylist[currentIndex], playlist: currentPlaylist, index: currentIndex);
  }

  void toggleShuffle() { if (!_canControlMusic()) return; isShuffle = !isShuffle; notifyListeners(); }
  void toggleRepeat() { if (!_canControlMusic()) return; isRepeat = !isRepeat; notifyListeners(); }

  void handleVoiceCommand(String command) async {
    final intent = _voiceAssistantService.processCommand(command);

    switch (intent.intent) {
      case IntentType.PLAY:
        if (!isPlaying) togglePlayPause();
        break;
      case IntentType.PAUSE:
        if (isPlaying) togglePlayPause();
        break;
      case IntentType.NEXT:
        nextMusic();
        break;
      case IntentType.PREVIOUS:
        previousMusic();
        break;
      case IntentType.SEEK_FORWARD:
        seekForward(intent.seconds ?? 10);
        break;
      case IntentType.SEEK_BACKWARD:
        seekBackward(intent.seconds ?? 10);
        break;
      case IntentType.PLAY_SONG:
        if (intent.songName != null) {
          final results = await _musicService.searchMusic(intent.songName!);
          if (results.isNotEmpty) {
            final firstResult = results.first;
            onMusicSelect(Music(
              name: firstResult.title,
              image: 'https://img.youtube.com/vi/${firstResult.videoId}/0.jpg',
              desc: firstResult.uploader,
              youtubeId: firstResult.videoId,
              duration: Duration(seconds: firstResult.duration),
            ));
          }
        }
        break;
      case IntentType.VOLUME_UP:
        setMusicVolume((musicVolume + 10).clamp(0, 100));
        break;
      case IntentType.VOLUME_DOWN:
        setMusicVolume((musicVolume - 10).clamp(0, 100));
        break;
      case IntentType.SET_VOLUME:
        if (intent.volume != null) {
          setMusicVolume(intent.volume!.toDouble());
        }
        break;
      case IntentType.UNKNOWN:
        break;
    }
  }

  void setMusicVolume(double volume) {
    musicVolume = volume;
    _audioHandler.setVolume(volume / 100);
    notifyListeners();
  }

  void seekForward(int seconds) {
    final currentPos = _audioHandler.playbackState.value.position;
    _audioHandler.seek(currentPos + Duration(seconds: seconds));
  }

  void seekBackward(int seconds) {
    final currentPos = _audioHandler.playbackState.value.position;
    _audioHandler.seek(currentPos - Duration(seconds: seconds));
  }

  // --- Eksik Metodlar ---

  bool isCurrentLiked(String youtubeId) {
    return likedMusicsList.any((m) => m.youtubeId == youtubeId);
  }

  void toggleLike(Music music) {
    final index = likedMusicsList.indexWhere((m) => m.youtubeId == music.youtubeId);
    if (index != -1) {
      likedMusicsList.removeAt(index);
    } else {
      likedMusicsList.add(music);
      showHeartExplosion = true;
    }
    _saveDataToFirebase();
    notifyListeners();
  }

  bool isInPlaylist(String playlistId, Music music) {
    final p = userPlaylists.firstWhere((p) => p.id == playlistId, orElse: () => model.Playlist(id: "null", name: "", image: ""));
    return p.musics.any((m) => m.youtubeId == music.youtubeId);
  }

  void toggleMusicInPlaylist(String playlistId, Music music) {
    final p = userPlaylists.firstWhere((p) => p.id == playlistId);
    final exists = p.musics.any((m) => m.youtubeId == music.youtubeId);
    if (exists) {
      p.musics.removeWhere((m) => m.youtubeId == music.youtubeId);
    } else {
      p.musics.add(music);
    }
    p.lastUpdatedAt = DateTime.now();
    _saveDataToFirebase();
    notifyListeners();
  }

  void createPlaylist(String name) {
    userPlaylists.add(model.Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      image: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=2070&auto=format&fit=crop',
      ownerName: userName,
      ownerImage: userProfileImage,
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
    ));
    _saveDataToFirebase();
    notifyListeners();
  }

  void deletePlaylist(String playlistId) {
    userPlaylists.removeWhere((p) => p.id == playlistId);
    _saveDataToFirebase();
    notifyListeners();
  }

  void removeMusicFromPlaylist(String playlistId, String youtubeId) {
    final playlist = userPlaylists.firstWhere((p) => p.id == playlistId);
    playlist.musics.removeWhere((m) => m.youtubeId == youtubeId);
    playlist.lastUpdatedAt = DateTime.now();
    _saveDataToFirebase();
    notifyListeners();
  }

  void addAllMusicsToPlaylist(String targetPlaylistId, List<Music> musicsToAdd) {
    final target = userPlaylists.firstWhere((p) => p.id == targetPlaylistId);
    for (var music in musicsToAdd) {
      if (!target.musics.any((m) => m.youtubeId == music.youtubeId)) {
        target.musics.add(music);
      }
    }
    target.lastUpdatedAt = DateTime.now();
    _saveDataToFirebase();
    notifyListeners();
  }

  void removeAllMusicsFromPlaylist(String targetPlaylistId, List<Music> musicsToRemove) {
    final target = userPlaylists.firstWhere((p) => p.id == targetPlaylistId);
    for (var music in musicsToRemove) {
      target.musics.removeWhere((m) => m.youtubeId == music.youtubeId);
    }
    target.lastUpdatedAt = DateTime.now();
    _saveDataToFirebase();
    notifyListeners();
  }

  void updatePlaylistDetails(String id, String newName, String newDesc, String newImage, bool isPrivate) {
    final index = userPlaylists.indexWhere((p) => p.id == id);
    if (index != -1) {
      userPlaylists[index].name = newName;
      userPlaylists[index].description = newDesc;
      userPlaylists[index].image = newImage;
      userPlaylists[index].isPrivate = isPrivate;
      userPlaylists[index].lastUpdatedAt = DateTime.now();
      _saveDataToFirebase();
      notifyListeners();
    }
  }

  void toggleShowOnProfile(String playlistId) {
    final index = userPlaylists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      userPlaylists[index].showOnProfile = !userPlaylists[index].showOnProfile;
      userPlaylists[index].lastUpdatedAt = DateTime.now();
      _saveDataToFirebase();
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    await _loadDataFromFirebase();
  }

  Future<bool> isProfileComplete() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        return data != null && data['userName'] != null && data['userName'] != "Kullanıcı";
      }
    } catch (e) {}
    return false;
  }

  void updateUserProfile(String name, String imagePath) {
    userName = name;
    userProfileImage = imagePath;
    _saveDataToFirebase();
    notifyListeners();
  }

  // --- YouTube Yükleme Mantığı ---
  Future<void> _loadAndPlay(Music music, {bool autoPlay = true}) async {
    int retryCount = 0;
    const int maxRetries = 3;
    bool success = false;

    while (retryCount < maxRetries && !success) {
      // Eğer yükleme sırasında başka bir şarkıya basıldıysa bu işlemi iptal et
      if (_loadingVideoId != music.youtubeId) return;

      try {
        final streamUrl = await _musicService.getAudioStreamUrl(music.youtubeId);
        if (streamUrl == null || streamUrl.isEmpty) throw Exception("No URL");

        // Tekrar kontrol et
        if (_loadingVideoId != music.youtubeId) return;

        final item = MediaItem(
          id: music.youtubeId,
          album: music.desc,
          title: music.name,
          artist: music.desc,
          artUri: music.image.isNotEmpty ? Uri.parse(music.image) : null,
        );

        await _audioHandler.setAudioSource(streamUrl, item);
        
        if (autoPlay && _loadingVideoId == music.youtubeId) {
          await _audioHandler.play();
        }
        success = true;
      } catch (e) {
        retryCount++;
        if (retryCount < maxRetries) await Future.delayed(Duration(milliseconds: 500));
      }
    }
    
    if (_loadingVideoId == music.youtubeId) {
      isPlayerReady = true;
      notifyListeners();
    }
  }

  Future<void> _updateDominantColor(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(NetworkImage(imageUrl));
      dominantColor = palette.vibrantColor?.color ?? palette.dominantColor?.color ?? Colors.blueGrey[900];
      notifyListeners();
    } catch (e) {}
  }

  Future<void> _loadDataFromFirebase() async {
    final user = _auth.currentUser; if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        userName = data['userName'] ?? "Kullanıcı";
        userProfileImage = data['userProfileImage'] ?? "";
        likedMusicsList.clear();
        if (data['likedMusics'] != null) {
          for (var m in (data['likedMusics'] as List)) {
            likedMusicsList.add(Music.fromMap(Map<String, dynamic>.from(m)));
          }
        }
        userPlaylists.clear();
        if (data['playlists'] != null) {
          for (var p in (data['playlists'] as List)) {
            userPlaylists.add(model.Playlist.fromMap(p));
          }
        }
        notifyListeners();
      }
    } catch (e) {}
  }

  Future<void> _saveDataToFirebase() async {
    final user = _auth.currentUser; if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'userName': userName,
        'userProfileImage': userProfileImage,
        'likedMusics': likedMusicsList.map((m) => m.toMap()).toList(),
        'playlists': userPlaylists.map((p) => p.toMap()).toList(),
      }, SetOptions(merge: true));
    } catch (e) {}
  }

  void _updateJamStateIfNeeded(Music? music, {bool? isPlaying}) {
    final jamController = GetIt.instance<JamController>();
    if (jamController.activeJamId != null && jamController.iHaveAuthority) {
      if (music != null) jamController.updateJamMusic(music);
      if (isPlaying != null) jamController.toggleJamPlayPause(isPlaying);
    }
  }

  bool _canControlMusic() {
    final jamController = GetIt.instance<JamController>();
    return jamController.activeJamId == null || jamController.iHaveAuthority;
  }

  void _clearLocalData() {
    userName = "Kullanıcı"; userProfileImage = ""; likedMusicsList.clear(); userPlaylists.clear();
    notifyListeners();
  }

  @override
  void dispose() { 
    _musicService.dispose();
    super.dispose(); 
  }
}
