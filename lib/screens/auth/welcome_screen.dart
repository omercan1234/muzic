import 'package:flutter/material.dart';
import '../../widgets/auth/auth_button.dart';
import '../../services/auth_service.dart';
import '../auth.dart';
import 'setup_profile_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      setState(() => _isLoading = false);

      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SetupProfileScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Google Giriş Hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
        : Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.music_note, color: Colors.white, size: 60),
                const SizedBox(height: 20),
                const Text(
                  "Milyonlarca şarkı.\nÜcretsiz.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                
                // 📧 ÜCRETSİZ KAYDOL (Kayıt modunda AuthScreen açar)
                AuthButton(
                  text: "Ücretsiz kaydol",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthScreen(isSignUp: true)),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                AuthButton(
                  text: "Google ile devam et",
                  icon: Icons.g_mobiledata,
                  backgroundColor: Colors.transparent,
                  textColor: Colors.white,
                  onPressed: _handleGoogleSignIn,
                ),
                
                const SizedBox(height: 20),
                
                // 🔑 OTURUM AÇ (Giriş modunda AuthScreen açar)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthScreen(isSignUp: false)),
                    );
                  },
                  child: const Text(
                    "Oturum Aç",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
