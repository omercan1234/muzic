import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../controllers/jam_controller.dart';
import '../controllers/player_controller.dart';
import '../widgets/jam/speaking_avatar.dart';

class JamScreen extends StatefulWidget {
  const JamScreen({super.key});

  @override
  State<JamScreen> createState() => _JamScreenState();
}

class _JamScreenState extends State<JamScreen> {
  final jamController = GetIt.instance<JamController>();
  final playerController = GetIt.instance<PlayerController>();
  final TextEditingController _messageController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _refreshDevices() async {
    await jamController.loadDevices();
    if (mounted) setState(() {});
  }

  void _minimize() {
    jamController.setMinimized(true);
    Navigator.pop(context);
  }

  void _showChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("Yazılı Sohbet", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: jamController.getChatMessages(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final messages = snapshot.data!.docs;
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(20),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index].data() as Map<String, dynamic>;
                            final isMe = msg['senderId'] == playerController.currentUserUid;
                            final type = msg['type'] ?? 'text';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundImage: msg['senderPP'] != null && msg['senderPP'].isNotEmpty 
                                      ? (msg['senderPP'].startsWith('http') ? NetworkImage(msg['senderPP']) : FileImage(File(msg['senderPP']))) as ImageProvider
                                      : null,
                                    child: msg['senderPP'] == null || msg['senderPP'].isEmpty ? const Icon(Icons.person, size: 20) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(msg['senderName'] ?? "Bilinmeyen", style: TextStyle(color: isMe ? const Color(0xFF1DB954) : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        if (type == 'text')
                                          Text(msg['text'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                        if (type == 'image')
                                          GestureDetector(
                                            onTap: () => _showFullScreenImage(msg['fileUrl']),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(msg['fileUrl'], width: 200, height: 200, fit: BoxFit.cover),
                                            ),
                                          ),
                                        if (type == 'voice')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                                                  onPressed: () async {
                                                    await _audioPlayer.setUrl(msg['fileUrl']);
                                                    _audioPlayer.play();
                                                  },
                                                ),
                                                const Text("Sesli Mesaj", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                          onPressed: () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                            if (image != null) {
                              await jamController.uploadAndSendImage(File(image.path));
                            }
                          },
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(25)),
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(hintText: "Mesaj gönder...", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onLongPress: () async {
                            if (await _audioRecorder.hasPermission()) {
                              final directory = await getTemporaryDirectory();
                              final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
                              await _audioRecorder.start(const RecordConfig(), path: path);
                              setModalState(() => _isRecording = true);
                            }
                          },
                          onLongPressUp: () async {
                            final path = await _audioRecorder.stop();
                            setModalState(() => _isRecording = false);
                            if (path != null) {
                              await jamController.uploadAndSendVoice(path);
                            }
                          },
                          child: CircleAvatar(
                            backgroundColor: _isRecording ? Colors.redAccent : Colors.transparent,
                            child: Icon(_isRecording ? Icons.mic : Icons.mic_none, color: Colors.white70),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF1DB954)),
                          onPressed: () {
                            if (_messageController.text.trim().isNotEmpty) {
                              jamController.sendChatMessage(_messageController.text);
                              _messageController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
    );
  }

  void _showSensitivitySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return ListenableBuilder(
          listenable: jamController,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("MİKROFON HASSASİYETİ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => jamController.startAutoCalibration(),
                        child: Text(
                          jamController.isCalibrating ? "KALİBRE EDİLİYOR..." : "OTOMATİK AYARLA",
                          style: const TextStyle(color: Color(0xFF1DB954), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  if (jamController.isCalibrating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Color(0xFF1DB954), strokeWidth: 2),
                            SizedBox(height: 16),
                            Text("🤫 Ortam dinleniyor, lütfen sessiz kalın...", style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF1DB954),
                            inactiveTrackColor: Colors.white10,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: jamController.speakingThreshold,
                            min: 0.001, max: 0.1,
                            onChanged: (value) => jamController.setSpeakingThreshold(value),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Daha Hassas", style: TextStyle(color: Colors.white38, fontSize: 10)),
                              Text("Değer: ${(jamController.speakingThreshold * 1000).toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              const Text("Daha Az Hassas", style: TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF282828), foregroundColor: Colors.white), child: const Text("TAMAM")),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeviceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return ListenableBuilder(
          listenable: jamController,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("SES CİHAZLARI", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1DB954), size: 20), onPressed: _refreshDevices),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("SES GİRİŞİ (MİKROFON)", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildDeviceDropdown(
                    devices: jamController.inputDevices,
                    selectedValue: jamController.selectedInputId,
                    onChanged: (id) => jamController.switchInputDevice(id!),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceDropdown({required List<MediaDeviceInfo> devices, required String? selectedValue, required void Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: DropdownButton<String>(
        value: selectedValue,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF181818),
        items: devices.map((d) => DropdownMenuItem(value: d.deviceId, child: Text(d.label, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: Listenable.merge([jamController, playerController]),
        builder: (context, _) {
          final members = jamController.jamMembers;
          final currentMusic = playerController.currentMusic;

          return Stack(
            children: [
              if (currentMusic != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.3,
                    child: Image.network(currentMusic.image, fit: BoxFit.cover),
                  ),
                ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30), onPressed: _minimize),
                          const Spacer(),
                          Column(
                            children: [
                              const Text("JAM OTURUMU", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                              Text(jamController.activeJamId ?? "Bağlanıyor...", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22), onPressed: () => jamController.leaveJam()),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 0.85),
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final bool isSpeaking = jamController.isMemberSpeaking(member.uid);
                            return SpeakingAvatar(
                              name: member.name, // ✅ userName -> name
                              imageUrl: member.pp, // ✅ userProfileImage -> pp
                              isSpeaking: isSpeaking,
                              isMe: member.uid == playerController.currentUserUid,
                            );
                          },
                        ),
                      ),
                    ),
                    if (currentMusic != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(currentMusic.image, width: 45, height: 45, fit: BoxFit.cover)),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(currentMusic.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(currentMusic.desc, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(playerController.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                                onPressed: () => playerController.togglePlayPause(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 30, left: 30, right: 30),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(icon: Icons.chat_bubble_outline, label: "Sohbet", onTap: _showChat),
                          _buildActionButton(
                            icon: jamController.isMuted ? Icons.mic_off : Icons.mic,
                            label: jamController.isMuted ? "Sessiz" : "Konuş",
                            onTap: () => jamController.toggleMute(),
                            color: jamController.isMuted ? Colors.redAccent : const Color(0xFF1DB954),
                          ),
                          _buildActionButton(
                            icon: jamController.isDeafened ? Icons.volume_off : Icons.volume_up,
                            label: "Dinle",
                            onTap: () => jamController.toggleDeafen(),
                            color: jamController.isDeafened ? Colors.orangeAccent : Colors.white,
                          ),
                          _buildActionButton(icon: Icons.tune, label: "Ayar", onTap: _showSensitivitySettings),
                          _buildActionButton(icon: Icons.settings_input_component, label: "Cihaz", onTap: _showDeviceSettings),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
