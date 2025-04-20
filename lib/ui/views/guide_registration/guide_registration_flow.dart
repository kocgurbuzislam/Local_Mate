import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/photo_selection_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/biography_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/language_selection_page.dart';

class GuideRegistrationData {
  static final GuideRegistrationData _instance =
      GuideRegistrationData._internal();

  factory GuideRegistrationData() {
    return _instance;
  }

  GuideRegistrationData._internal();

  File? photo;
  String? biography;
  List<Language> selectedLanguages = [];

  void reset() {
    photo = null;
    biography = null;
    selectedLanguages = [];
  }
}

class GuideRegistrationFlow extends StatefulWidget {
  const GuideRegistrationFlow({super.key});

  @override
  State<GuideRegistrationFlow> createState() => _GuideRegistrationFlowState();
}

class _GuideRegistrationFlowState extends State<GuideRegistrationFlow> {
  final GuideRegistrationData _registrationData = GuideRegistrationData();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _registrationData.reset();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rehber Ol'),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'Rehber Kaydı',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lütfen aşağıdaki adımları tamamlayın',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildRegistrationButton(
                        icon: Icons.photo_camera,
                        title: 'Profil Fotoğrafı',
                        subtitle: 'Profil fotoğrafınızı seçin',
                        onTap: () => _navigateToPhotoSelection(context),
                        isCompleted: _registrationData.photo != null,
                      ),
                      const SizedBox(height: 16),
                      _buildRegistrationButton(
                        icon: Icons.person,
                        title: 'Biyografi',
                        subtitle: 'Kendinizi tanıtın',
                        onTap: () => _navigateToBiography(context),
                        isCompleted:
                            _registrationData.biography?.isNotEmpty ?? false,
                      ),
                      const SizedBox(height: 16),
                      _buildRegistrationButton(
                        icon: Icons.language,
                        title: 'Dil Seçimi',
                        subtitle: 'Bildiğiniz dilleri seçin',
                        onTap: () => _navigateToLanguageSelection(context),
                        isCompleted:
                            _registrationData.selectedLanguages.isNotEmpty,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isRegistrationComplete()
                            ? _completeRegistration
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Kaydı Tamamla',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRegistrationButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isCompleted,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isCompleted ? Colors.white : Colors.grey[600],
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Future<void> _navigateToPhotoSelection(BuildContext context) async {
    final result = await Navigator.pushNamed<File?>(
      context,
      '/photo',
    );
    if (result != null) {
      setState(() => _registrationData.photo = result);
    }
  }

  Future<void> _navigateToBiography(BuildContext context) async {
    final result = await Navigator.pushNamed<String?>(
      context,
      '/biography',
    );
    if (result != null) {
      setState(() => _registrationData.biography = result);
    }
  }

  Future<void> _navigateToLanguageSelection(BuildContext context) async {
    final result = await Navigator.pushNamed<List<Language>?>(
      context,
      '/language',
    );
    if (result != null) {
      setState(() => _registrationData.selectedLanguages = result);
    }
  }

  bool _isRegistrationComplete() {
    return _registrationData.photo != null &&
        _registrationData.biography != null &&
        _registrationData.biography!.isNotEmpty &&
        _registrationData.selectedLanguages.isNotEmpty;
  }

  Future<void> _saveGuideData() async {
    if (!_isRegistrationComplete()) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Kullanıcı bulunamadı');

      // Profil fotoğrafını yükle
      String? photoUrl;
      if (_registrationData.photo != null) {
        final photoRef = FirebaseStorage.instance
            .ref()
            .child('guide_photos/${user.uid}/profile.jpg');
        await photoRef.putFile(_registrationData.photo!);
        photoUrl = await photoRef.getDownloadURL();
      }

      // Rehber verilerini Firestore'a kaydet
      await FirebaseFirestore.instance.collection('guides').doc(user.uid).set({
        'photoUrl': photoUrl,
        'biography': _registrationData.biography,
        'languages': _registrationData.selectedLanguages
            .map((e) => e.toString())
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rehber kaydınız başarıyla oluşturuldu'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _completeRegistration() async {
    if (!_isRegistrationComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm adımları tamamlayın'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _saveGuideData();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
