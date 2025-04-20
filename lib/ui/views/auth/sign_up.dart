import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yerel_rehber_app/ui/views/bottom_navigation.dart';
import 'package:yerel_rehber_app/ui/views/home_page.dart';
import 'package:intl/intl.dart';
import '../../../colors.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  String name = "";
  String surname = "";
  String date = "";
  String email = "";
  String phoneNumber = "";
  String password = "";
  String passwordAgain = "";
  bool _isPasswordVisible = false;
  bool _isPasswordAgainVisible = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _surname = TextEditingController();
  final TextEditingController _date = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phoneNumber = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordAgain = TextEditingController();

  registration() async {
    if (_formKey.currentState!.validate()) {
      if (password == passwordAgain) {
        setState(() => _isLoading = true);
        try {
          UserCredential userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password);

          Map<String, dynamic> userInfoMap = {
            "name": name,
            "surname": surname,
            "date": date,
            "email": email,
            "phoneNumber": phoneNumber,
            "createdAt": DateTime.now(),
          };

          await FirebaseFirestore.instance
              .collection("Users")
              .doc(userCredential.user!.uid)
              .set(userInfoMap);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarıyla tamamlandı'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const BottomNavigation_()),
            (route) => false,
          );
        } on FirebaseAuthException catch (e) {
          String errorMessage = 'Bir hata oluştu';
          if (e.code == 'weak-password') {
            errorMessage = 'Şifre en az 6 karakter olmalıdır';
          } else if (e.code == 'email-already-in-use') {
            errorMessage = 'Bu e-posta adresi zaten kullanımda';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        } finally {
          setState(() => _isLoading = false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifreler eşleşmiyor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: mainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Kayıt Ol",
          style: TextStyle(
            color: mainColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hesap Oluştur",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: mainColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Lütfen bilgilerinizi girin",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: _name,
                    label: "Ad",
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen adınızı girin';
                      }
                      return null;
                    },
                    onChanged: (value) => name = value,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _surname,
                    label: "Soyad",
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen soyadınızı girin';
                      }
                      return null;
                    },
                    onChanged: (value) => surname = value,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _date,
                    label: "Doğum Tarihi",
                    icon: Icons.calendar_today,
                    readOnly: true,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: mainColor,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _date.text = DateFormat('dd/MM/yyyy').format(picked);
                          date = _date.text;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen doğum tarihinizi seçin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _email,
                    label: "E-posta",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen e-posta adresinizi girin';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Geçerli bir e-posta adresi girin';
                      }
                      return null;
                    },
                    onChanged: (value) => email = value,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneNumber,
                    label: "Telefon Numarası",
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen telefon numaranızı girin';
                      }
                      return null;
                    },
                    onChanged: (value) => phoneNumber = value,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _password,
                    label: "Şifre",
                    icon: Icons.lock_outline,
                    obscureText: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen şifrenizi girin';
                      }
                      if (value.length < 6) {
                        return 'Şifre en az 6 karakter olmalıdır';
                      }
                      return null;
                    },
                    onChanged: (value) => password = value,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordAgain,
                    label: "Şifre Tekrar",
                    icon: Icons.lock_outline,
                    obscureText: !_isPasswordAgainVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordAgainVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordAgainVisible = !_isPasswordAgainVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen şifrenizi tekrar girin';
                      }
                      if (value != _password.text) {
                        return 'Şifreler eşleşmiyor';
                      }
                      return null;
                    },
                    onChanged: (value) => passwordAgain = value,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : registration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Kayıt Ol",
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
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: mainColor),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mainColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _date.dispose();
    _email.dispose();
    _phoneNumber.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    super.dispose();
  }
}
