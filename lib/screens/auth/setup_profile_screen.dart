import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/auth/auth_button.dart';
import '../../controllers/player_controller.dart';
import '../app.dart';
import 'package:get_it/get_it.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final PlayerController _playerController = GetIt.instance<PlayerController>();
  File? _image;

  // 📸 İZİN VE SEÇİM MANTIĞI
  Future<void> _handleImageAction(ImageSource source) async {
    bool hasPermission = false;

    if (source == ImageSource.camera) {
      // Kamera İzni İste
      var status = await Permission.camera.request();
      if (status.isGranted) hasPermission = true;
    } else {
      // Galeri İzni (Android versiyonuna göre otomatik seçer)
      if (Platform.isAndroid) {
        // Android 13 ve üzeri için READ_MEDIA_IMAGES (photos)
        // Android 12 ve altı için storage
        if (await Permission.photos.request().isGranted ||
            await Permission.storage.request().isGranted) {
          hasPermission = true;
        }
      } else {
        hasPermission = true; // iOS vb.
      }
    }

    if (hasPermission) {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 50,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
      if (mounted) Navigator.pop(context);
    } else {
      // İzin verilmediyse uyarı ver veya ayarlara gönder
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("İzin verilmedi. Ayarlardan izinleri açabilirsiniz."),
            action: SnackBarAction(label: "Ayarlar", onPressed: () => openAppSettings()),
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("Profil Fotoğrafı Seç", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text("Kamera", style: TextStyle(color: Colors.white)),
              onTap: () => _handleImageAction(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text("Galeri", style: TextStyle(color: Colors.white)),
              onTap: () => _handleImageAction(ImageSource.gallery),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Profilini oluştur", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Center(
                child: GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 75,
                        backgroundColor: const Color(0xFF282828),
                        backgroundImage: _image != null ? FileImage(_image!) : null,
                        child: _image == null ? const Icon(Icons.person, size: 85, color: Colors.white54) : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF1DB954),
                          child: const Icon(Icons.edit, size: 20, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: "Adın ne?",
                  hintStyle: TextStyle(color: Colors.white24),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Bu isim profilinde görünecek.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 100),
              AuthButton(
                text: "Uygulamayı Başlat",
                onPressed: () {
                  if (_nameController.text.isNotEmpty) {
                    _playerController.updateUserProfile(_nameController.text, _image?.path ?? "");
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyApp()));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir isim girin")));
                  }
                },
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
