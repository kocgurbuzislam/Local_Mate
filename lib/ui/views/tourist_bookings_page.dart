import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerel_rehber_app/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yerel_rehber_app/ui/views/tourist_confirmation_page.dart';

class TouristBookingsPage extends StatefulWidget {
  const TouristBookingsPage({Key? key}) : super(key: key);

  @override
  State<TouristBookingsPage> createState() => _TouristBookingsPageState();
}

class _TouristBookingsPageState extends State<TouristBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR');
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Rezervasyonlarım',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.grey[800], size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Lütfen giriş yapın',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Rezervasyonlarım',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey[800], size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: mainColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: mainColor,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Onay Bekleyenler'),
            Tab(text: 'Onaylananlar'),
            Tab(text: 'Tümü'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList('pending'),
          _buildBookingsList('confirmed'),
          _buildBookingsList('all'),
        ],
      ),
    );
  }

  Widget _buildBookingsList(String status) {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox();

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Bir hata oluştu',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: mainColor,
              strokeWidth: 3,
            ),
          );
        }

        final bookings = snapshot.data?.docs ?? [];
        if (bookings.isEmpty) {
          return Center(
            child: Container(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == 'pending'
                        ? Icons.pending_actions
                        : status == 'confirmed'
                            ? Icons.check_circle_outline
                            : Icons.calendar_today,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    status == 'pending'
                        ? 'Onay bekleyen rezervasyonunuz bulunmuyor'
                        : status == 'confirmed'
                            ? 'Onaylanmış rezervasyonunuz bulunmuyor'
                            : 'Henüz rezervasyon yapmadınız',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status == 'pending'
                        ? 'Rehber onayı bekleyen rezervasyonlarınız burada görünecek'
                        : status == 'confirmed'
                            ? 'Onaylanmış rezervasyonlarınız burada görünecek'
                            : 'Tüm rezervasyonlarınız burada görünecek',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index].data() as Map<String, dynamic>;
            final bookingId = bookings[index].id;
            final serviceName =
                booking['serviceName'] as String? ?? 'İsimsiz Hizmet';
            final guideName =
                booking['guideName'] as String? ?? 'İsimsiz Rehber';
            final amount = booking['amount'] as double? ?? 0.0;
            final numberOfPeople = booking['numberOfPeople'] as int? ?? 1;
            final bookingDate = booking['bookingDate'] as Timestamp?;
            final status = booking['status'] as String? ?? 'pending';
            final paymentReleased =
                booking['paymentReleased'] as bool? ?? false;
            final touristConfirmed =
                booking['touristConfirmed'] as bool? ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: mainColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.map_outlined,
                                  color: mainColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  serviceName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusChip(
                            status, paymentReleased, touristConfirmed),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    if (status == 'confirmed' && !touristConfirmed)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => _navigateToConfirmation(bookingId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Rezervasyonu Onayla',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(
      String status, bool paymentReleased, bool touristConfirmed) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Onay Bekliyor';
        icon = Icons.pending;
        break;
      case 'confirmed':
        if (touristConfirmed) {
          color = Colors.green;
          text = 'Onaylandı';
          icon = Icons.check_circle;
        } else {
          color = Colors.blue;
          text = 'Rehber Onayladı';
          icon = Icons.info;
        }
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'İptal Edildi';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        text = 'Bilinmiyor';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isAmount ? FontWeight.w600 : FontWeight.normal,
              color: isAmount ? mainColor : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToConfirmation(String bookingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TouristConfirmationPage(bookingId: bookingId),
      ),
    );
  }
}
