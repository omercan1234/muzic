import 'package:flutter/material.dart';
import 'package:muzik/widgets/auth/auth_button.dart';
import 'package:muzik/widgets/auth/auth_textfield.dart';
import 'package:muzik/screens/auth/setup_profile_screen.dart';
import 'package:muzik/screens/app.dart';
import 'package:muzik/services/auth_service.dart';
import 'package:muzik/controllers/player_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

class AuthScreen extends StatefulWidget {
  final bool isSignUp;
  const AuthScreen({super.key, this.isSignUp = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final PlayerController _playerController = GetIt.instance<PlayerController>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun.")));
      return;
    }

    setState(() => _isLoading = true);
    
    final result = widget.isSignUp 
      ? await _authService.signUpWithEmail(_emailController.text, _passwordController.text)
      : await _authService.signInWithEmail(_emailController.text, _passwordController.text);
    
    if (!mounted) return;

    if (result is User) {
      // ✅ GİRİŞ BAŞARILI: Hemen verileri Firebase'den çek
      await _playerController.refreshData();

      if (widget.isSignUp) {
        setState(() => _isLoading = false);
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SetupProfileScreen()), (route) => false);
      } else {
        try {
          final bool isProfileComplete = await _playerController.isProfileComplete();
          setState(() => _isLoading = false);
          if (isProfileComplete) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MyApp()), (route) => false);
          } else {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SetupProfileScreen()), (route) => false);
          }
        } catch (e) {
          setState(() => _isLoading = false);
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SetupProfileScreen()), (route) => false);
        }
      }
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.toString()), backgroundColor: Colors.redAccent));
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final result = await _authService.signInWithGoogle();
    
    if (!mounted) return;

    if (result is User) {
      // ✅ GİRİŞ BAŞARILI: Hemen verileri Firebase'den çek
      await _playerController.refreshData();

      try {
        final bool isProfileComplete = await _playerController.isProfileComplete();
        setState(() => _isLoading = false);
        if (isProfileComplete) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MyApp()), (route) => false);
        } else {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SetupProfileScreen()), (route) => false);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SetupProfileScreen()), (route) => false);
      }
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.toString()), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
        : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Center(child: Icon(Icons.music_note, color: Color(0xFF1DB954), size: 80)),
              const SizedBox(height: 40),
              Text(
                widget.isSignUp ? "Hesap Oluştur" : "Oturum Aç",
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              AuthTextField(label: "E-posta", controller: _emailController),
              const SizedBox(height: 20),
              AuthTextField(label: "Parola", isPassword: true, controller: _passwordController),
              const SizedBox(height: 40),
              Center(
                child: AuthButton(
                  text: widget.isSignUp ? "Kayıt Ol" : "Oturum Aç",
                  onPressed: _handleAuth,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: const [
                  Expanded(child: Divider(color: Colors.white24)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("VEYA", style: TextStyle(color: Colors.white24, fontSize: 12))),
                  Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 40),
              AuthButton(
                text: "Google ile devam et",
                icon: Icons.g_mobiledata,
                backgroundColor: Colors.transparent,
                textColor: Colors.white,
                onPressed: _handleGoogleSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
