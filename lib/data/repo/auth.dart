import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore için ekleme
import 'package:yerel_rehber_app/ui/views/bottom_navigation.dart';
import 'database.dart';

class AuthMethods {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Mevcut Kullanıcıyı Getir
  User? getCurrentUser() {
    return auth.currentUser;
  }

  // Firestore'dan Kullanıcı Adını Getir
  Future<String?> getUserName() async {
    User? user = auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await firestore.collection("Users").doc(user.uid).get();
      return userDoc["name"];
    }
    return null;
  }

  // Google ile Giriş Yap
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google girişi iptal edildi'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Kullanıcı bilgilerini Firestore'a kaydet
        await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
          'name': user.displayName ?? 'Bilinmeyen Kullanıcı',
          'email': user.email,
          'photoUrl': user.photoURL,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Başarılı giriş sonrası ana sayfaya yönlendir
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const BottomNavigation_()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Bir hata oluştu';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage =
            'Bu e-posta adresi başka bir giriş yöntemiyle kullanılıyor';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Geçersiz kimlik bilgileri';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Google ile giriş izni verilmemiş';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Bu hesap devre dışı bırakılmış';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'Kullanıcı bulunamadı';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Yanlış şifre';
      } else if (e.code == 'invalid-verification-code') {
        errorMessage = 'Geçersiz doğrulama kodu';
      } else if (e.code == 'invalid-verification-id') {
        errorMessage = 'Geçersiz doğrulama ID';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beklenmeyen bir hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // Apple ile Giriş Yap
  Future<User> signInWithApple({List<Scope> scopes = const []}) async {
    final result = await TheAppleSignIn.performRequests(
        [AppleIdRequest(requestedScopes: scopes)]);
    switch (result.status) {
      case AuthorizationStatus.authorized:
        final AppleIdCredential = result.credential!;
        final oAuthCredential = OAuthProvider('apple.com');
        final credential = oAuthCredential.credential(
            idToken: String.fromCharCodes(AppleIdCredential.identityToken!));
        final UserCredential = await auth.signInWithCredential(credential);
        final firebaseUser = UserCredential.user!;
        if (scopes.contains(Scope.fullName)) {
          final fullName = AppleIdCredential.fullName;
          if (fullName != null &&
              fullName.givenName != null &&
              fullName.familyName != null) {
            final displayName = '${fullName.givenName} ${fullName.familyName}';
            await firebaseUser.updateDisplayName(displayName);
          }
        }
        return firebaseUser;
      case AuthorizationStatus.error:
        throw PlatformException(
            code: 'ERROR_AUTHORIZATION_DENIED',
            message: result.error.toString());

      case AuthorizationStatus.cancelled:
        throw PlatformException(
            code: 'ERROR_ABORTED_BY_USER', message: 'Sign in aborted by user');
      default:
        throw UnimplementedError();
    }
  }
}
