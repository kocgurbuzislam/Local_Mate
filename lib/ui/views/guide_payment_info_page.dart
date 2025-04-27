import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yerel_rehber_app/colors.dart';

class GuidePaymentInfoPage extends StatefulWidget {
  const GuidePaymentInfoPage({Key? key}) : super(key: key);

  @override
  _GuidePaymentInfoPageState createState() => _GuidePaymentInfoPageState();
}

class _GuidePaymentInfoPageState extends State<GuidePaymentInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _ibanController = TextEditingController();
  final _accountHolderController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPaymentInfo();
  }

  Future<void> _loadExistingPaymentInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('guides')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _ibanController.text = data['iban'] ?? '';
            _accountHolderController.text = data['accountHolder'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Ödeme bilgileri yüklenirken hata: $e');
    }
  }

  @override
  void dispose() {
    _ibanController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  bool _isValidIBAN(String iban) {
    // IBAN formatını kontrol et
    if (!iban.startsWith('TR')) return false;
    if (iban.length != 26) return false;

    // Sadece harf ve rakam içermeli
    final validChars = RegExp(r'^[A-Z0-9]+$');
    if (!validChars.hasMatch(iban.substring(2))) return false;

    return true;
  }

  Future<void> _updatePaymentInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final iban = _ibanController.text.trim().toUpperCase();
    if (!_isValidIBAN(iban)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçersiz IBAN formatı'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      await FirebaseFirestore.instance
          .collection('guides')
          .doc(user.uid)
          .update({
        'hasValidPaymentInfo': true,
        'iban': iban,
        'accountHolder': _accountHolderController.text.trim(),
        'paymentInfoUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ödeme bilgileri başarıyla güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ödeme bilgileri güncellenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödeme Bilgileri'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: mainColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: mainColor),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bilgi Kartı
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: mainColor),
                          const SizedBox(width: 8),
                          Text(
                            'Önemli Bilgi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tur ücretleri, tur tamamlandıktan sonra bu hesaba aktarılacaktır. '
                        'Lütfen bilgilerinizi doğru girdiğinizden emin olun.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // IBAN Alanı
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Banka Hesap Bilgileri',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ibanController,
                        decoration: InputDecoration(
                          labelText: 'IBAN',
                          hintText: 'TR...',
                          prefixIcon:
                              Icon(Icons.account_balance, color: mainColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: mainColor, width: 2),
                          ),
                          helperText: 'TR ile başlayan 26 karakterli IBAN',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'IBAN gerekli';
                          }
                          if (!_isValidIBAN(value.trim().toUpperCase())) {
                            return 'Geçersiz IBAN formatı';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _accountHolderController,
                        decoration: InputDecoration(
                          labelText: 'Hesap Sahibi',
                          prefixIcon: Icon(Icons.person, color: mainColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: mainColor, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Hesap sahibi gerekli';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Güncelleme Butonu
                ElevatedButton(
                  onPressed: _isLoading ? null : _updatePaymentInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Ödeme Bilgilerini Güncelle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
