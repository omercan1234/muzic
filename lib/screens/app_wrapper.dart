import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../controllers/jam_controller.dart';
import '../widgets/jam/mini_jam_bar.dart';
import 'auth/welcome_screen.dart';
import 'app.dart'; // Ana uygulama (MyApp)
import '../services/navigation_service.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  final JamController _jamController = GetIt.instance<JamController>();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _jamController.addListener(_handleJamStateChange);
  }

  @override
  void dispose() {
    _jamController.removeListener(_handleJamStateChange);
    _removeOverlay();
    super.dispose();
  }

  void _handleJamStateChange() {
    if (_jamController.isMinimized && _overlayEntry == null) {
      _showOverlay();
    }
    else if (!_jamController.isMinimized && _overlayEntry != null) {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    final overlay = NavigationService.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => const MiniJamBar(),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    // 🔐 OTURUM DURUMUNU DİNLE
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Eğer kullanıcı giriş yapmışsa ana uygulamayı (MyApp), yapmamışsa WelcomeScreen'i göster
        if (snapshot.hasData) {
          return const MyApp(); 
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}
