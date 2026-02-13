import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:muzik/controllers/player_controller.dart';
import 'package:muzik/controllers/jam_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:muzik/screens/app_wrapper.dart';
import 'package:muzik/services/navigation_service.dart';
import 'package:muzik/services/audio_handler.dart';
import 'package:muzik/services/music_service.dart';
import 'package:muzik/services/music_oprations.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'firebase_options.dart';

final getIt = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ 1. KURAL: MyAudioHandler'ı en başta manuel oluşturuyoruz (Cast hatasını önlemek için)
  final myAudioHandler = MyAudioHandler();

  // AudioService'i bu handler ile başlat
  await AudioService.init(
    builder: () => myAudioHandler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.muzik.channel.audio',
      androidNotificationChannelName: 'Muzik App Oynatıcı',
      androidStopForegroundOnPause: true,
    ),
  );

  // ✅ 2. KURAL: AudioSession yapılandırması
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // ✅ 3. KURAL: Servisleri doğru sırayla ve güvenli tiplerle kaydediyoruz
  getIt.registerSingleton<AudioHandler>(myAudioHandler);
  
  final musicService = MusicService();
  getIt.registerSingleton<MusicService>(musicService);
  
  // MusicOperations artık doğrudan doğru tipteki handler'ı alıyor
  getIt.registerSingleton<MusicOperations>(
    MusicOperations(musicService, myAudioHandler)
  );

  // Controller'lar en son kaydedilmeli
  getIt.registerSingleton<PlayerController>(PlayerController());
  getIt.registerSingleton<JamController>(JamController()); 
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      title: 'Muzik App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const AppWrapper(),
    );
  }
}
