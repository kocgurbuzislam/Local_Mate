import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yerel_rehber_app/colors.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Kullanıcı bulunamadı',
        );
      }

      // Önce mevcut şifre ile kimlik doğrulama yap
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      // Kimlik doğrulama
      await user.reauthenticateWithCredential(credential);

      // Firebase Authentication'da şifreyi güncelle
      await user.updatePassword(_newPasswordController.text);

      // Yeni şifre ile yeniden giriş yap
      await _auth.signInWithEmailAndPassword(
        email: user.email!,
        password: _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şifreniz başarıyla güncellendi')),
        );
        _clearControllers();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Bir hata oluştu';
      if (e.code == 'wrong-password') {
        errorMessage = 'Mevcut şifreniz yanlış';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Yeni şifreniz çok zayıf';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Bu işlem için son zamanlarda giriş yapmanız gerekiyor';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'Kullanıcı bulunamadı';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Geçersiz e-posta adresi';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Hesabınız devre dışı bırakılmış';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    // Önce şifre doğrulama dialogu göster
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Güvenlik Doğrulaması'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hesabınızı kapatmak için şifrenizi girin'),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: Text('Devam Et'),
          ),
        ],
      ),
    );

    passwordController.dispose();
    if (password == null || password.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Kapat'),
        content: const Text(
            'Hesabınızı kapatmak istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kapat', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Kullanıcı bulunamadı',
        );
      }

      // Yeniden kimlik doğrulama yap
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Rehber verilerini kontrol et
      final guideDoc = await FirebaseFirestore.instance
          .collection('guides')
          .doc(user.uid)
          .get();

      // Eğer rehber ise verilerini sil
      if (guideDoc.exists) {
        await FirebaseFirestore.instance
            .collection('guides')
            .doc(user.uid)
            .delete();

        try {
          final guidePhotosRef =
              FirebaseStorage.instance.ref().child('guide_photos/${user.uid}');
          final photosList = await guidePhotosRef.listAll();

          for (var photo in photosList.items) {
            await photo.delete();
          }
        } catch (e) {
          print('Rehber fotoğrafları silinirken hata: $e');
        }
      }

      // Kullanıcı verilerini Firestore'dan sil
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .delete();

      // Firebase Storage'dan profil fotoğrafını sil
      try {
        await FirebaseStorage.instance
            .ref()
            .child('profile_images/${user.uid}')
            .delete();
      } catch (e) {
        print('Profil fotoğrafı silinirken hata: $e');
      }

      // Firebase Auth'dan hesabı sil
      await user.delete();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hesabınız başarıyla silindi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Bir hata oluştu';
      if (e.code == 'requires-recent-login') {
        errorMessage = 'Bu işlem için son zamanlarda giriş yapmanız gerekiyor';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'Kullanıcı bulunamadı';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Girdiğiniz şifre yanlış';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Geçersiz e-posta adresi';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Hesabınız devre dışı bırakılmış';
      }

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hesap kapatılırken hata oluştu: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearControllers() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Güvenlik Ayarları",
          style: TextStyle(
              fontSize: 20, color: mainColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: mainColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: mainColor))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Şifre Değiştirme Kartı
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: mainColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.lock_outline,
                                color: mainColor,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              "Şifre Değiştir",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: mainColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildPasswordField(
                                controller: _currentPasswordController,
                                label: "Mevcut Şifre",
                                prefixIcon: Icons.lock_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Lütfen mevcut şifrenizi girin';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              _buildPasswordField(
                                controller: _newPasswordController,
                                label: "Yeni Şifre",
                                prefixIcon: Icons.lock_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Lütfen yeni şifrenizi girin';
                                  }
                                  if (value.length < 6) {
                                    return 'Şifre en az 6 karakter olmalıdır';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              _buildPasswordField(
                                controller: _confirmPasswordController,
                                label: "Yeni Şifre (Tekrar)",
                                prefixIcon: Icons.lock_outline,
                                validator: (value) {
                                  if (value != _newPasswordController.text) {
                                    return 'Şifreler eşleşmiyor';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _changePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: mainColor,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    "Şifreyi Değiştir",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  // Hesap İşlemleri Kartı
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              "Hesap İşlemleri",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Hesabınızı kapatmak istiyorsanız, aşağıdaki butona tıklayın. Bu işlem geri alınamaz ve tüm verileriniz silinecektir.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _deleteAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Hesabı Kapat",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(prefixIcon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mainColor),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }
}
