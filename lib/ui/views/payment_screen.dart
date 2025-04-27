import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:yerel_rehber_app/colors.dart';
import 'package:yerel_rehber_app/data/repo/payment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentScreen extends StatefulWidget {
  final String guideId;
  final String guideName;
  final double amount;
  final String serviceName;
  final DateTime bookingDate;
  final TimeOfDay bookingTime;
  final int numberOfPeople;

  const PaymentScreen({
    Key? key,
    required this.guideId,
    required this.guideName,
    required this.amount,
    required this.serviceName,
    required this.bookingDate,
    required this.bookingTime,
    required this.numberOfPeople,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _errorMessage;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();
  final stripe.CardEditController controller = stripe.CardEditController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      // Müşteri oluştur veya mevcut müşteriyi al
      String? customerId = await PaymentService.getStoredCustomerId();
      if (customerId == null) {
        final customerData = await PaymentService.createCustomer(
          email: user.email ?? '',
          name: user.displayName ?? '',
        );
        customerId = customerData['id'];
      }

      // Ödeme niyeti oluştur
      final paymentIntent = await PaymentService.createPaymentIntent(
        amount: widget.amount,
        currency: 'try', // Türk Lirası
        customerId: customerId ?? '',
      );

      // Ödemeyi işle
      await PaymentService.processPayment(
        paymentIntentId: paymentIntent['id'],
        paymentMethodId: paymentIntent['payment_method'] ?? '',
      );

      try {
        // Rezervasyon bilgilerini Firestore'a kaydet
        final bookingRef =
            await FirebaseFirestore.instance.collection('bookings').add({
          'userId': user.uid,
          'guideId': widget.guideId,
          'serviceName': widget.serviceName,
          'amount': widget.amount,
          'numberOfPeople': widget.numberOfPeople,
          'bookingDate': DateTime(
            widget.bookingDate.year,
            widget.bookingDate.month,
            widget.bookingDate.day,
            widget.bookingTime.hour,
            widget.bookingTime.minute,
          ),
          'status': 'pending', // Başlangıçta bekliyor durumunda
          'createdAt': FieldValue.serverTimestamp(),
          'paymentId': paymentIntent['id'],
          'paymentStatus': 'completed',
          'customerName': user.displayName ?? '',
          'customerEmail': user.email ?? '',
          'guideName': widget.guideName,
          'paymentReleased': false, // Ödeme serbest bırakılmadı
          'paymentReleaseDate': null, // Ödeme serbest bırakılma tarihi
        });

        // Rehberin ödeme bilgilerini kontrol et
        final guideDoc = await FirebaseFirestore.instance
            .collection('guides')
            .doc(widget.guideId)
            .get();

        if (!guideDoc.exists) {
          throw Exception('Rehber bilgileri bulunamadı');
        }

        final guideData = guideDoc.data() as Map<String, dynamic>;
        final hasValidPaymentInfo = guideData['hasValidPaymentInfo'] ?? false;

        if (!hasValidPaymentInfo) {
          // Rehberin ödeme bilgileri eksikse uyarı göster
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Rehberin ödeme bilgileri eksik. Lütfen rehberle iletişime geçin.'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        print('Rezervasyon Firestore\'a başarıyla kaydedildi');
      } catch (firestoreError) {
        print('Firestore kayıt hatası: $firestoreError');
        throw Exception(
            'Ödeme başarılı ancak rezervasyon kaydedilemedi: $firestoreError');
      }

      // Başarılı ödeme
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Ödeme başarıyla tamamlandı! Rehber onayı bekleniyor.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ödeme işlemi sırasında bir hata oluştu: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? 'Bir hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ödeme',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Özet Kartı
              Container(
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: mainColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.person_outline, color: mainColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.guideName,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                widget.serviceName,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Toplam Tutar',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.amount.toStringAsFixed(2)} TL',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: mainColor,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: mainColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 16,
                                  color: mainColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.numberOfPeople} Kişi',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: mainColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Kart Bilgileri
              Container(
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kart Bilgileri',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: stripe.CardField(
                        controller: controller,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[800],
                          fontSize: 16,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        onCardChanged: (card) {
                          // Kart değişikliklerini burada işleyebilirsiniz
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[400]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Ödeme Butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Güvenli Ödeme Yap',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Ödemeniz güvenle işlenmektedir',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
