import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yerel_rehber_app/colors.dart';
import '../../data/repo/auth.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  String userName = "Yükleniyor...";
  String userEmail = "Yükleniyor...";
  String? userPhone;
  String? userAddress;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Kullanıcı adını al
      String? name = await AuthMethods().getUserName();
      if (name != null) {
        setState(() {
          userName = name;
        });
      }

      // Diğer kullanıcı bilgilerini al
      try {
        final userDoc =
            await _firestore.collection('Users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            userEmail = user.email ?? "E-posta bulunamadı";
            userPhone = userDoc.data()?['phone'];
            userAddress = userDoc.data()?['address'];
          });
        }
      } catch (e) {
        print('Kullanıcı bilgileri yüklenirken hata: $e');
      }
    }
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
          "Kişisel Bilgiler",
          style: TextStyle(
              fontSize: 20, color: mainColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(
                title: "Ad Soyad",
                value: userName,
                icon: Icons.person_outline,
              ),
              SizedBox(height: 16),
              _buildInfoCard(
                title: "E-posta",
                value: userEmail,
                icon: Icons.email_outlined,
              ),
              SizedBox(height: 16),
              _buildInfoCard(
                title: "Telefon",
                value: userPhone ?? "Belirtilmemiş",
                icon: Icons.phone_outlined,
              ),
              SizedBox(height: 16),
              _buildInfoCard(
                title: "Adres",
                value: userAddress ?? "Belirtilmemiş",
                icon: Icons.location_on_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: mainColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: mainColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
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
}
