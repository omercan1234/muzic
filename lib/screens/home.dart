import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/player_controller.dart';
import '../controllers/jam_controller.dart';
import '../services/music_oprations.dart';
import '../services/category_opration.dart';
import '../models/category.dart';
import '../models/music.dart';
import 'profile_screen.dart';
import 'jam_screen.dart';

class Home extends StatefulWidget {
  final Function(Music) onMiniPlayer;
  const Home({super.key, required this.onMiniPlayer});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final playerController = GetIt.instance<PlayerController>();
  final jamController = GetIt.instance<JamController>();

  // ⚙️ AYARLAR PANELİ
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text("Ayarlar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.white70),
                title: const Text("Profili Düzenle", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                },
              ),
              
              const Divider(color: Colors.white10),
              
              // 🚪 ÇIKIŞ YAP BUTONU
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Çıkış Yap", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context); // Paneli kapat
                  await FirebaseAuth.instance.signOut(); // Firebase'den çıkış yap
                  // Not: AppWrapper otomatik olarak WelcomeScreen'e dönecektir.
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jams')
              .where('authorizedUserIds', arrayContains: playerController.currentUserUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final jams = snapshot.data!.docs.where((doc) {
              return doc.id != jamController.activeJamId;
            }).toList();

            if (jams.isEmpty) {
              return const Center(
                child: Text("Henüz bir davet yok.", style: TextStyle(color: Colors.white54)),
              );
            }

            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Jam Davetleri", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: jams.length,
                    itemBuilder: (context, index) {
                      final jamData = jams[index].data() as Map<String, dynamic>;
                      final jamId = jams[index].id;
                      final hostId = jamData['hostId'];
                      final hostName = jamData['members']?[hostId]?['name'] ?? "Bir Arkadaşın";

                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFF1DB954), child: Icon(Icons.group, color: Colors.white)),
                        title: Text("$hostName seni Jam'e davet etti!", style: const TextStyle(color: Colors.white)),
                        subtitle: const Text("Birlikte müzik dinlemek için katıl.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(this.context);
                            Navigator.pop(context);
                            final success = await jamController.joinJam(jamId);
                            if (success && mounted) {
                              navigator.push(MaterialPageRoute(builder: (context) => const JamScreen()));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.black),
                          child: const Text("Katıl"),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _createCategory(Category category) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
            child: Image.network(category.imageURL, fit: BoxFit.cover, width: 56, height: 56),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(category.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  List<Widget> _createMusicList(String title) {
    // ✅ BURASI DÜZELTİLDİ: MusicOprations -> MusicOperations
    List<Music> musicList = MusicOperations.getMusic();
    return [
      Padding(
        padding: const EdgeInsets.only(left: 16, top: 24, bottom: 16),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      SizedBox(
        height: 210,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: musicList.length,
          itemBuilder: (ctx, index) {
            return _createMusic(musicList[index]);
          },
        ),
      ),
    ];
  }

  Widget _createMusic(Music music) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => widget.onMiniPlayer(music),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(music.image, width: 150, height: 150, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 150,
            child: Text(music.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 150,
            child: Text(music.desc, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Category> categoryList = CategoryOpration.getCategories();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.4],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(10.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: ListenableBuilder(
                listenable: playerController,
                builder: (context, _) {
                  return CircleAvatar(
                    backgroundColor: const Color(0xFF282828),
                    backgroundImage: playerController.userProfileImage.isNotEmpty
                        ? (playerController.userProfileImage.startsWith('http')
                            ? NetworkImage(playerController.userProfileImage)
                            : FileImage(File(playerController.userProfileImage))) as ImageProvider
                        : null,
                    child: playerController.userProfileImage.isEmpty
                        ? const Icon(Icons.person, color: Colors.white70, size: 18)
                        : null,
                  );
                },
              ),
            ),
          ),
          title: const Text("Tünaydın", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          actions: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jams')
                  .where('authorizedUserIds', arrayContains: playerController.currentUserUid)
                  .snapshots(),
              builder: (context, snapshot) {
                bool hasInvite = snapshot.hasData && snapshot.data!.docs.any((doc) => doc.id != jamController.activeJamId);
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(hasInvite ? Icons.notifications_active : Icons.notifications_none, color: Colors.white), 
                      onPressed: _showNotifications
                    ),
                    if (hasInvite)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                          constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: () {}),
            // ✅ AYARLAR BUTONU GÜNCELLENDİ
            IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), onPressed: _showSettings),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: categoryList.length,
                  itemBuilder: (ctx, index) => _createCategory(categoryList[index]),
                ),
              ),
              ..._createMusicList("Senin için derlendi"),
              ..._createMusicList("Hızla yükselenler"),
              ..._createMusicList("En çok dinlenenler"),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}
