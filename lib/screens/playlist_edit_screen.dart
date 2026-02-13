 import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/playlist.dart';
import '../controllers/player_controller.dart';
import 'package:get_it/get_it.dart';

class PlaylistEditScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistEditScreen({super.key, required this.playlist});

  @override
  State<PlaylistEditScreen> createState() => _PlaylistEditScreenState();
}

class _PlaylistEditScreenState extends State<PlaylistEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late bool _isPrivate;
  File? _selectedImage;
  final playerController = GetIt.instance<PlayerController>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist.name);
    _descController = TextEditingController(text: widget.playlist.description);
    _isPrivate = widget.playlist.isPrivate;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  // ✅ DEĞİŞİKLİKLERİ KAYDET
  void _saveChanges() {
    final String newName = _nameController.text;
    final String newDesc = _descController.text;
    final String newImagePath = _selectedImage != null ? _selectedImage!.path : widget.playlist.image;

    // Kontrolcü üzerinden merkezi güncellemeyi yap (Firebase'e de yazar)
    playerController.updatePlaylistDetails(
      widget.playlist.id,
      newName,
      newDesc,
      newImagePath,
      _isPrivate,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("İptal", style: TextStyle(color: Colors.white)),
        ),
        title: const Text("Düzenle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text("Kaydet", style: TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // 🖼️ Kapak Fotoğrafı Değiştirme
            GestureDetector(
              onTap: _pickImage,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _selectedImage != null 
                          ? Image.file(_selectedImage!, fit: BoxFit.cover)
                          : (widget.playlist.image.startsWith('http') 
                              ? Image.network(widget.playlist.image, fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildPlaceholder())
                              : Image.file(File(widget.playlist.image), fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildPlaceholder())),
                      ),
                    ),
                    Container(
                      width: 200, height: 200,
                      color: Colors.black38,
                      child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 40),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text("Fotoğrafı Değiştir", style: TextStyle(color: Colors.white70, fontSize: 12)),
            
            const SizedBox(height: 40),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: "Ad",
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 14),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: "Açıklama",
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 14),
                      hintText: "Bir açıklama ekle...",
                      hintStyle: TextStyle(color: Colors.white24),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            SwitchListTile(
              value: _isPrivate,
              onChanged: (val) => setState(() => _isPrivate = val),
              title: const Text("Gizli yap", style: TextStyle(color: Colors.white, fontSize: 16)),
              subtitle: const Text("Bu çalma listesini sadece sen görebilirsin.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              activeColor: const Color(0xFF1DB954),
            ),

            const SizedBox(height: 40),

            TextButton(
              onPressed: () {
                playerController.deletePlaylist(widget.playlist.id);
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("ÇALMA LİSTESİNİ SİL", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(color: Colors.grey[900], child: const Icon(Icons.music_note, size: 80, color: Colors.white24));
  }
}
