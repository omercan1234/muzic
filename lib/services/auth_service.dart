import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // ✅ 7.2.0 Sürümü için doğru başlatma yöntemi.
  // Unnamed constructor hatasını aşmak için scopes ile yapılandırılmış hali tercih edilir.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
  );

  // 📧 EMAIL/PAROLA GİRİŞİ
  Future<dynamic> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Hatası: ${e.code} - ${e.message}");
      return _translateError(e.code);
    } catch (e) {
      return "Beklenmedik bir hata oluştu.";
    }
  }

  // 📧 EMAIL/PAROLA KAYIT
  Future<dynamic> signUpWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Kayıt Hatası: ${e.code} - ${e.message}");
      return _translateError(e.code);
    } catch (e) {
      return "Kayıt sırasında bir hata oluştu.";
    }
  }

  // 🌐 GOOGLE İLE GİRİŞ
  Future<dynamic> signInWithGoogle() async {
    try {
      // Önceki oturumu temizle
      await _googleSignIn.signOut();
      
      // ✅ signIn() metodu artık GoogleSignIn nesnesi üzerinden güvenle çağrılabilir
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Giriş iptal edildi.";

      // ✅ Kimlik bilgilerini al (authentication bir Future'dır)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // ✅ accessToken ve idToken alımı
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase ile oturum aç
      UserCredential result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      debugPrint("Google Giriş Hatası: $e");
      return "Google girişi başarısız oldu.";
    }
  }

  // 🚪 ÇIKIŞ YAP
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Çıkış hatası: $e");
    }
  }

  String _translateError(String code) {
    switch (code) {
      case 'invalid-credential': return 'Kimlik bilgileri hatalı veya süresi dolmuş.';
      case 'user-not-found': return 'Bu e-posta ile kayıtlı bir kullanıcı bulunamadı.';
      case 'wrong-password': return 'Hatalı parola girdiniz.';
      case 'email-already-in-use': return 'Bu e-posta adresi zaten kullanımda.';
      case 'weak-password': return 'Parola çok zayıf (en az 6 karakter olmalı).';
      case 'invalid-email': return 'Geçersiz bir e-posta adresi girdiniz.';
      default: return 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }

  User? get currentUser => _auth.currentUser;
}
