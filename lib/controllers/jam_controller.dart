import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/jam.dart';
import '../models/music.dart';
import 'player_controller.dart';

class JamController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? activeJamId;
  Jam? currentJam;
  StreamSubscription? _jamSubscription;
  Timer? _statsTimer;

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {}; 
  final Map<String, MediaStream> _remoteStreams = {}; 
  final Map<String, RTCVideoRenderer> _remoteRenderers = {}; 
  
  bool isMuted = false; 
  bool isDeafened = false;
  bool isMinimized = false;
  bool isUploading = false;
  Offset overlayPosition = const Offset(20, 100);

  double speakingThreshold = 0.01;
  bool isCalibrating = false;
  List<double> _calibrationSamples = [];

  List<MediaDeviceInfo> _devices = [];
  String? selectedInputId;
  String? selectedOutputId;

  Map<String, double> remoteVolumes = {};
  Map<String, int> activeSpeakers = {}; 
  DateTime? _lastSpeakerChange;
  
  static const Duration FLICKER_PROTECTION = Duration(milliseconds: 300);

  // ✅ Getter eklendi
  List<JamMember> get jamMembers => currentJam?.members.values.toList() ?? [];

  // ✅ Metot eklendi
  bool isMemberSpeaking(String uid) => activeSpeakers.containsKey(uid);

  final Map<String, dynamic> _iceConfiguration = {
    'iceServers': [{'urls': 'stun:stun1.l.google.com:19302'}, {'urls': 'stun:stun2.l.google.com:19302'}],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
    'optional': [],
  };

  JamController() {
    _initLocalStream().then((_) => loadDevices());
    _startStatsTimer(); 
  }

  // 💬 --- SOHBET VE DOSYA İŞLEMLERİ ---

  Future<void> sendChatMessage(String text, {String? type = 'text', String? fileUrl}) async {
    if (activeJamId == null) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final playerController = GetIt.instance<PlayerController>();
    try {
      await _firestore.collection('jams').doc(activeJamId).collection('messages').add({
        'senderId': user.uid,
        'senderName': playerController.userName,
        'senderPP': playerController.userProfileImage,
        'text': text.trim(),
        'type': type, 
        'fileUrl': fileUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("❌ Mesaj hatası: $e");
    }
  }

  Future<void> uploadAndSendImage(File imageFile) async {
    if (activeJamId == null) return;
    isUploading = true;
    notifyListeners();
    try {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final ref = _storage.ref().child('jams/$activeJamId/images/$fileName');
      final uploadTask = await ref.putFile(imageFile);
      final url = await uploadTask.ref.getDownloadURL();
      await sendChatMessage("", type: 'image', fileUrl: url);
    } catch (e) {
      debugPrint("❌ Fotoğraf hatası: $e");
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  Future<void> uploadAndSendVoice(String filePath) async {
    if (activeJamId == null) return;
    isUploading = true;
    notifyListeners();
    try {
      final file = File(filePath);
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.m4a";
      final ref = _storage.ref().child('jams/$activeJamId/voice/$fileName');
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      await sendChatMessage("", type: 'voice', fileUrl: url);
    } catch (e) {
      debugPrint("❌ Ses hatası: $e");
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  Stream<QuerySnapshot> getChatMessages() {
    if (activeJamId == null) return const Stream.empty();
    return _firestore
        .collection('jams')
        .doc(activeJamId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  bool hasAuthority(String uid) {
    if (currentJam == null) return false;
    return currentJam!.hostId == uid || currentJam!.authorizedUserIds.contains(uid);
  }

  bool get iHaveAuthority => hasAuthority(_auth.currentUser?.uid ?? "");

  Future<void> updateJamMusic(Music music) async {
    if (activeJamId == null || !iHaveAuthority) return;
    await _firestore.collection('jams').doc(activeJamId).update({
      'currentMusic': {'name': music.name, 'image': music.image, 'desc': music.desc, 'youtubeId': music.youtubeId},
      'isPlaying': true,
      'positionInSeconds': 0,
      'lastUpdate': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> toggleJamPlayPause(bool isPlaying) async {
    if (activeJamId == null || !iHaveAuthority) return;
    await _firestore.collection('jams').doc(activeJamId).update({'isPlaying': isPlaying, 'lastUpdate': DateTime.now().millisecondsSinceEpoch});
  }

  void _syncMusicState(Jam newJam) {
    final playerController = GetIt.instance<PlayerController>();
    final myUid = _auth.currentUser?.uid;
    if (!hasAuthority(myUid ?? "")) {
      if (newJam.currentMusic != null) {
        playerController.syncMusic(
          newJam.currentMusic!, 
          newJam.isPlaying, 
          positionInSeconds: newJam.positionInSeconds
        );
      }
    }
  }

  void setUserVolume(String uid, double volume) {
    remoteVolumes[uid] = volume;
    if (_remoteStreams.containsKey(uid)) {
      final stream = _remoteStreams[uid]!;
      for (var track in stream.getAudioTracks()) {
        track.enabled = !isDeafened && volume > 0.01;
        try { Helper.setVolume(volume, track); } catch (e) {}
      }
    }
    notifyListeners();
  }

  Future<void> loadDevices() async {
    try {
      final List<MediaDeviceInfo> allDevices = await navigator.mediaDevices.enumerateDevices();
      _devices = allDevices;
      notifyListeners();
    } catch (e) {}
  }

  List<MediaDeviceInfo> get inputDevices => _devices.where((d) => d.kind == 'audioinput').toList();
  List<MediaDeviceInfo> get outputDevices => _devices.where((d) => d.kind == 'audiooutput').toList();

  Future<void> switchInputDevice(String deviceId) async {
    selectedInputId = deviceId;
    if (_localStream != null) {
      _localStream!.getTracks().forEach((t) => t.stop());
      _localStream = null;
      await _initLocalStream();
      for (var pc in _peerConnections.values) {
        var senders = await pc.getSenders();
        try {
          var audioSender = senders.firstWhere((s) => s.track?.kind == 'audio');
          audioSender.replaceTrack(_localStream!.getAudioTracks()[0]);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  void setSpeakingThreshold(double value) {
    speakingThreshold = value;
    notifyListeners();
  }

  Future<void> startAutoCalibration() async {
    if (isCalibrating) return;
    isCalibrating = true;
    _calibrationSamples.clear();
    notifyListeners();
    await Future.delayed(const Duration(seconds: 5));
    if (_calibrationSamples.isNotEmpty) {
      double avg = _calibrationSamples.reduce((a, b) => a + b) / _calibrationSamples.length;
      speakingThreshold = (avg * 1.8).clamp(0.005, 0.06);
    }
    isCalibrating = false;
    notifyListeners();
  }

  Future<void> _initLocalStream() async {
    if (_localStream != null) return;
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
          'video': false,
        });
        if (_localStream!.getAudioTracks().isNotEmpty) _localStream!.getAudioTracks()[0].enabled = !isMuted;
        Helper.setSpeakerphoneOn(selectedOutputId == null);
        notifyListeners();
      } catch (e) {}
    }
  }

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (activeJamId == null && !isCalibrating) return;
      final Map<String, double> levels = {};
      final myUid = _auth.currentUser?.uid;
      if (!isMuted && myUid != null && _peerConnections.isNotEmpty) {
        try {
          final firstPc = _peerConnections.values.first;
          var stats = await firstPc.getStats();
          for (var report in stats) {
            if (report.type == 'media-source' && report.values['kind'] == 'audio') {
              final double? level = report.values['audioLevel'];
              if (level != null) {
                levels[myUid] = level;
                if (isCalibrating) _calibrationSamples.add(level);
              }
            }
          }
        } catch (_) {}
      }
      for (var entry in _peerConnections.entries) {
        final uid = entry.key;
        final pc = entry.value;
        try {
          var stats = await pc.getStats();
          for (var report in stats) {
            if (report.type == 'inbound-rtp' && report.values['kind'] == 'audio') {
              final double? level = report.values['audioLevel'];
              if (level != null) levels[uid] = (levels[uid] ?? 0) + level;
            }
          }
        } catch (_) {}
      }
      levels.removeWhere((uid, level) => level < speakingThreshold);
      if (levels.isEmpty) {
        if (activeSpeakers.isNotEmpty) { activeSpeakers = {}; notifyListeners(); }
        return;
      }
      final Map<String, int> newSpeakers = {};
      levels.forEach((uid, level) => newSpeakers[uid] = (level * 100).toInt());
      if (activeSpeakers.length != newSpeakers.length || activeSpeakers.keys.any((k) => !newSpeakers.containsKey(k))) {
        if (_lastSpeakerChange == null || DateTime.now().difference(_lastSpeakerChange!) > FLICKER_PROTECTION) {
          activeSpeakers = newSpeakers;
          _lastSpeakerChange = DateTime.now();
          notifyListeners();
        }
      }
    });
  }

  Future<bool> startJam(Music? firstMusic) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final playerController = GetIt.instance<PlayerController>();
    await _initLocalStream();
    final jamId = "jam_${user.uid}";
    final newJam = Jam(
      id: jamId, hostId: user.uid, currentMusic: firstMusic, isPlaying: firstMusic != null,
      authorizedUserIds: [user.uid],
      members: {
        user.uid: JamMember(uid: user.uid, name: playerController.userName, pp: playerController.userProfileImage, isMuted: isMuted, isDeafened: isDeafened)
      },
    );
    try {
      await _firestore.collection('jams').doc(jamId).set(newJam.toMap());
      activeJamId = jamId;
      _listenToJam(jamId);
      _listenToSignaling(jamId);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> joinJam(String jamId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final playerController = GetIt.instance<PlayerController>();
    await _initLocalStream();
    try {
      final me = JamMember(uid: user.uid, name: playerController.userName, pp: playerController.userProfileImage, isMuted: isMuted, isDeafened: isDeafened);
      await _firestore.collection('jams').doc(jamId).update({'members.${user.uid}': me.toMap()});
      activeJamId = jamId;
      _listenToJam(jamId);
      _listenToSignaling(jamId);
      return true;
    } catch (e) { return false; }
  }

  void toggleMute() {
    isMuted = !isMuted;
    if (_localStream != null) _localStream!.getAudioTracks()[0].enabled = !isMuted;
    if (activeJamId != null) _firestore.collection('jams').doc(activeJamId).update({'members.${_auth.currentUser?.uid}.isMuted': isMuted});
    notifyListeners();
  }

  void toggleDeafen() {
    isDeafened = !isDeafened;
    isMuted = isDeafened; 
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) _localStream!.getAudioTracks()[0].enabled = !isMuted;
    _remoteStreams.values.forEach((stream) { for (var track in stream.getAudioTracks()) track.enabled = !isDeafened; });
    if (activeJamId != null) {
      _firestore.collection('jams').doc(activeJamId).update({'members.${_auth.currentUser?.uid}.isDeafened': isDeafened, 'members.${_auth.currentUser?.uid}.isMuted': isMuted});
    }
    notifyListeners();
  }

  void _listenToJam(String jamId) {
    _jamSubscription?.cancel();
    _jamSubscription = _firestore.collection('jams').doc(jamId).snapshots().listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        Map<String, JamMember> memberMap = {};
        if (data['members'] != null) { (data['members'] as Map).forEach((key, value) { memberMap[key.toString()] = JamMember.fromMap(Map<String, dynamic>.from(value)); }); }
        final newJam = Jam(
          id: data['id'], hostId: data['hostId'], 
          currentMusic: data['currentMusic'] != null ? Music(name: data['currentMusic']['name'], image: data['currentMusic']['image'], desc: data['currentMusic']['desc'], youtubeId: data['currentMusic']['youtubeId']) : null,
          isPlaying: data['isPlaying'] ?? false, authorizedUserIds: List<String>.from(data['authorizedUserIds'] ?? []),
          members: memberMap,
          positionInSeconds: data['positionInSeconds'] ?? 0,
        );
        _syncMusicState(newJam);
        currentJam = newJam;
        connectToMembers();
        notifyListeners();
      } else { leaveJam(); }
    });
  }

  void _listenToSignaling(String jamId) {
    final myUid = _auth.currentUser!.uid;
    _firestore.collection('jams').doc(jamId).collection('offers').where('to', isEqualTo: myUid).snapshots().listen((snapshot) { for (var change in snapshot.docChanges) { if (change.type == DocumentChangeType.added) _handleOffer(change.doc.data()!, change.doc.id); } });
    _firestore.collection('jams').doc(jamId).collection('answers').where('to', isEqualTo: myUid).snapshots().listen((snapshot) { for (var change in snapshot.docChanges) { if (change.type == DocumentChangeType.added) _handleAnswer(change.doc.data()!); } });
    _firestore.collection('jams').doc(jamId).collection('candidates').where('to', isEqualTo: myUid).snapshots().listen((snapshot) { for (var change in snapshot.docChanges) { if (change.type == DocumentChangeType.added) { final data = change.doc.data()!; final pc = _peerConnections[data['from']]; pc?.addCandidate(RTCIceCandidate(data['candidate']['candidate'], data['candidate']['sdpMid'], data['candidate']['sdpMLineIndex'])); } } });
  }

  Future<void> connectToMembers() async {
    if (currentJam == null) return;
    final myUid = _auth.currentUser!.uid;
    for (var memberUid in currentJam!.members.keys) { if (memberUid != myUid && !_peerConnections.containsKey(memberUid)) { if (myUid.compareTo(memberUid) < 0) await _createPeerConnection(memberUid, isOfferer: true); } }
  }

  Future<void> _createPeerConnection(String otherUid, {required bool isOfferer}) async {
    if (isOfferer && _peerConnections.containsKey(otherUid)) return;
    RTCPeerConnection pc = await createPeerConnection(_iceConfiguration, _constraints);
    _peerConnections[otherUid] = pc;
    RTCVideoRenderer renderer = RTCVideoRenderer();
    await renderer.initialize();
    _remoteRenderers[otherUid] = renderer;
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) pc.addTrack(track, _localStream!);
    }
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[otherUid] = event.streams[0];
        _remoteRenderers[otherUid]?.srcObject = event.streams[0];
        notifyListeners();
      }
    };
    pc.onIceCandidate = (candidate) {
      _firestore.collection('jams').doc(activeJamId).collection('candidates').add({'from': _auth.currentUser!.uid, 'to': otherUid, 'candidate': candidate.toMap()});
    };
    if (isOfferer) {
      RTCSessionDescription offer = await pc.createOffer({'offerToReceiveAudio': 1});
      await pc.setLocalDescription(offer);
      await _firestore.collection('jams').doc(activeJamId).collection('offers').add({'from': _auth.currentUser!.uid, 'to': otherUid, 'sdp': offer.sdp, 'type': offer.type});
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> data, String offerId) async { final fromUid = data['from']; await _createPeerConnection(fromUid, isOfferer: false); RTCPeerConnection pc = _peerConnections[fromUid]!; await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type'])); RTCSessionDescription answer = await pc.createAnswer({'offerToReceiveAudio': 1}); await pc.setLocalDescription(answer); await _firestore.collection('jams').doc(activeJamId).collection('answers').add({'from': _auth.currentUser!.uid, 'to': fromUid, 'sdp': answer.sdp, 'type': answer.type}); }
  Future<void> _handleAnswer(Map<String, dynamic> data) async { final pc = _peerConnections[data['from']]; if (pc != null) await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type'])); }
  
  void setMinimized(bool value) { isMinimized = value; notifyListeners(); }
  void updatePosition(Offset newPos) { overlayPosition = newPos; notifyListeners(); }

  Future<void> leaveJam() async {
    _statsTimer?.cancel();
    _peerConnections.forEach((u, pc) => pc.dispose());
    _peerConnections.clear();
    _remoteStreams.clear();
    _remoteRenderers.forEach((u, r) => r.dispose());
    _remoteRenderers.clear();
    if (activeJamId != null) {
      if (currentJam?.hostId == _auth.currentUser?.uid) await _firestore.collection('jams').doc(activeJamId).delete();
      else await _firestore.collection('jams').doc(activeJamId).update({'members.${_auth.currentUser?.uid}': FieldValue.delete()});
    }
    _jamSubscription?.cancel();
    activeJamId = null;
    currentJam = null;
    isMinimized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _remoteRenderers.forEach((u, r) => r.dispose());
    super.dispose();
  }
}
