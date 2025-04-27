import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerel_rehber_app/colors.dart';

class TouristConfirmationPage extends StatefulWidget {
  final String bookingId;

  const TouristConfirmationPage({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  State<TouristConfirmationPage> createState() =>
      _TouristConfirmationPageState();
}

class _TouristConfirmationPageState extends State<TouristConfirmationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR');
  }

  Future<void> _handleConfirmation(bool isConfirmed) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId);
      final bookingDoc = await bookingRef.get();

      if (!bookingDoc.exists) {
        throw Exception('Rezervasyon bulunamadı');
      }

      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final currentStatus = bookingData['status'] as String? ?? '';
      final paymentReleased = bookingData['paymentReleased'] as bool? ?? false;
      final guideId = bookingData['guideId'] as String? ?? '';
      final amount = bookingData['amount'] as double? ?? 0.0;

      if (currentStatus != 'confirmed' || paymentReleased) {
        throw Exception('Bu rezervasyon için onay işlemi yapılamaz');
      }

      if (isConfirmed) {
        // Ödemeyi serbest bırak ve rehbere aktar
        await bookingRef.update({
          'paymentReleased': true,
          'paymentReleasedAt': FieldValue.serverTimestamp(),
          'touristConfirmed': true,
          'touristConfirmationDate': FieldValue.serverTimestamp(),
        });

        // Rehberin kazançlarını güncelle
        if (guideId.isNotEmpty) {
          final guideRef =
              FirebaseFirestore.instance.collection('guides').doc(guideId);
          await guideRef.update({
            'totalEarnings': FieldValue.increment(amount),
            'availableBalance': FieldValue.increment(amount),
          });

          // Rehbere bildirim gönder
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': guideId,
            'type': 'payment_released',
            'title': 'Ödeme Serbest Bırakıldı',
            'message':
                'Turist rezervasyonu onayladı. Ödemeniz hesabınıza aktarıldı.',
            'bookingId': widget.bookingId,
            'amount': amount,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Rezervasyon onaylandı ve ödeme rehbere aktarıldı.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Rezervasyonu iptal et ve ödemeyi iade et
        await bookingRef.update({
          'status': 'cancelled',
          'cancelledBy': 'tourist',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        // İade işlemini başlat
        //Stripe üzerinden iade işlemini gerçekleştir

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Rezervasyon iptal edildi. Ödeme iadesi başlatıldı.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem sırasında bir hata oluştu: ${e.toString()}'),
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
        title: const Text('Rezervasyon Onayı'),
        backgroundColor: Colors.white,
        foregroundColor: mainColor,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Bir hata oluştu: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final bookingData = snapshot.data?.data() as Map<String, dynamic>?;
          if (bookingData == null) {
            return const Center(
              child: Text('Rezervasyon bulunamadı'),
            );
          }

          final serviceName =
              bookingData['serviceName'] as String? ?? 'İsimsiz Hizmet';
          final amount = bookingData['amount'] as double? ?? 0.0;
          final guideName =
              bookingData['guideName'] as String? ?? 'İsimsiz Rehber';
          final bookingDate = bookingData['bookingDate'] as Timestamp?;
          final numberOfPeople = bookingData['numberOfPeople'] as int? ?? 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rezervasyon Detayları',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('Hizmet', serviceName),
                        _buildDetailRow('Rehber', guideName),
                        _buildDetailRow('Kişi Sayısı', '$numberOfPeople kişi'),
                        if (bookingDate != null)
                          _buildDetailRow(
                            'Rezervasyon Tarihi',
                            DateFormat('dd MMMM yyyy HH:mm', 'tr_TR')
                                .format(bookingDate.toDate()),
                          ),
                        _buildDetailRow(
                          'Ödeme Tutarı',
                          '${amount.toStringAsFixed(2)} TL',
                          isAmount: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Rehber rezervasyonunuzu onayladı. Lütfen aşağıdaki seçeneklerden birini seçin:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  )
                else
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => _handleConfirmation(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 32,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Rezervasyonu Onayla',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => _handleConfirmation(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 32,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text(
                          'Rezervasyonu İptal Et',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
              color: isAmount ? Colors.green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
