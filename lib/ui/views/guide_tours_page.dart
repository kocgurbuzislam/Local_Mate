import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerel_rehber_app/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';

class GuideToursPage extends StatefulWidget {
  const GuideToursPage({Key? key}) : super(key: key);

  @override
  State<GuideToursPage> createState() => _GuideToursPageState();
}

class _GuideToursPageState extends State<GuideToursPage>
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

  Future<void> _contactTourist(String userId, String touristName) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen önce giriş yapın'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Müşteri bilgilerini Firestore'dan al
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Müşteri bilgileri bulunamadı'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final customerName =
          '${userData['name'] ?? ''} ${userData['surname'] ?? ''}'.trim();

      // Chat ID oluştur
      final chatId = [currentUser.uid, userId]..sort();
      final chatRoomId = chatId.join('_');

      // Chat odasını oluştur
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .set({
        'users': [currentUser.uid, userId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'customerName': customerName,
        'guideName': (await FirebaseFirestore.instance
                    .collection('guides')
                    .doc(currentUser.uid)
                    .get())
                .data()?['fullName'] ??
            'İsimsiz Rehber',
      }, SetOptions(merge: true));

      // Chat ekranına yönlendir
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatRoomId,
            guideId: currentUser.uid,
            guideName: customerName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      final bookingRef =
          FirebaseFirestore.instance.collection('bookings').doc(bookingId);
      final bookingDoc = await bookingRef.get();

      if (!bookingDoc.exists) {
        throw Exception('Rezervasyon bulunamadı');
      }

      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final currentStatus = bookingData['status'] as String? ?? 'pending';
      final paymentReleased = bookingData['paymentReleased'] as bool? ?? false;
      final userId = bookingData['userId'] as String? ?? '';

      // Eğer rezervasyon zaten onaylanmış veya iptal edilmişse
      if (currentStatus != 'pending') {
        throw Exception(
            'Bu rezervasyon zaten ${currentStatus == 'confirmed' ? 'onaylanmış' : 'iptal edilmiş'}');
      }

      // Rezervasyon durumunu güncelle
      await bookingRef.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Eğer rezervasyon onaylandıysa ve ödeme henüz serbest bırakılmadıysa
      if (newStatus == 'confirmed' && !paymentReleased) {
        // Turistin onayını bekle
        await bookingRef.update({
          'waitingForTouristConfirmation': true,
          'touristConfirmationDeadline':
              DateTime.now().add(const Duration(hours: 24)),
        });

        // Turiste bildirim gönder
        if (userId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': userId,
            'type': 'booking_confirmation',
            'title': 'Rehber Onayı',
            'message':
                'Rehber rezervasyonunuzu onayladı. Lütfen 24 saat içinde onaylayın.',
            'bookingId': bookingId,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rezervasyon onaylandı. Turistin onayı bekleniyor.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (newStatus == 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rezervasyon iptal edildi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Durum güncellenirken bir hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Turist onayı için yeni fonksiyon
  Future<void> _handleTouristConfirmation(
      String bookingId, bool isConfirmed) async {
    try {
      final bookingRef =
          FirebaseFirestore.instance.collection('bookings').doc(bookingId);
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
            'bookingId': bookingId,
            'amount': amount,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rezervasyon onaylandı ve ödeme rehbere aktarıldı.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Rezervasyonu iptal et ve ödemeyi iade et
        await bookingRef.update({
          'status': 'cancelled',
          'cancelledBy': 'tourist',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        // İade işlemini başlat
        // TODO: Stripe üzerinden iade işlemini gerçekleştir

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rezervasyon iptal edildi. Ödeme iadesi başlatıldı.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İşlem sırasında bir hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, String bookingId) {
    final serviceName = booking['serviceName'] as String? ?? 'İsimsiz Hizmet';
    final amount = booking['amount'] as double? ?? 0.0;
    final status = booking['status'] as String? ?? 'pending';
    final createdAt = booking['createdAt'] as Timestamp?;
    final bookingDate = booking['bookingDate'] as Timestamp?;
    final numberOfPeople = booking['numberOfPeople'] as int? ?? 1;
    final userId = booking['userId'] as String? ?? '';
    final touristConfirmed = booking['touristConfirmed'] as bool? ?? false;
    final paymentReleased = booking['paymentReleased'] as bool? ?? false;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
      builder: (context, snapshot) {
        String customerName = 'İsimsiz Müşteri';
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          customerName =
              '${userData['name'] ?? ''} ${userData['surname'] ?? ''}'.trim();
        }

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'confirmed'
                                ? Colors.green[50]
                                : status == 'pending'
                                    ? Colors.orange[50]
                                    : Colors.red[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status == 'confirmed'
                                ? 'Onaylandı'
                                : status == 'pending'
                                    ? 'Bekliyor'
                                    : 'İptal Edildi',
                            style: GoogleFonts.poppins(
                              color: status == 'confirmed'
                                  ? Colors.green[700]
                                  : status == 'pending'
                                      ? Colors.orange[700]
                                      : Colors.red[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (status == 'confirmed' && !touristConfirmed) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Turist Onayı Bekleniyor',
                              style: GoogleFonts.poppins(
                                color: Colors.blue[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        if (status == 'confirmed' && touristConfirmed) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Turist Onayladı',
                              style: GoogleFonts.poppins(
                                color: Colors.green[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Müşteri: $customerName',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoItem(
                      Icons.group,
                      '$numberOfPeople kişi',
                    ),
                    const SizedBox(width: 16),
                    if (bookingDate != null)
                      _buildInfoItem(
                        Icons.calendar_today,
                        DateFormat('dd MMMM yyyy HH:mm', 'tr_TR')
                            .format(bookingDate.toDate()),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      createdAt != null
                          ? DateFormat('dd.MM.yyyy HH:mm')
                              .format(createdAt.toDate())
                          : '',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${amount.toStringAsFixed(2)} TL',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: mainColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (status == 'pending')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _updateBookingStatus(bookingId, 'confirmed'),
                          icon: const Icon(Icons.check, size: 16),
                          label: Text(
                            'Onayla',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (status == 'pending') const SizedBox(width: 8),
                    if (status == 'pending')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _updateBookingStatus(bookingId, 'cancelled'),
                          icon: const Icon(Icons.close, size: 16),
                          label: Text(
                            'Reddet',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (status == 'pending') const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _contactTourist(userId, customerName),
                        icon: const Icon(Icons.chat, size: 16,color: Colors.white,),
                        label: Text(
                          'İletişim',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Turlarım',
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
          indicatorColor: mainColor,
          labelColor: mainColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Bekleyenler'),
            Tab(text: 'Onaylananlar'),
            Tab(text: 'Tümü'),
          ],
        ),
      ),
      body: currentUser == null
          ? Center(
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
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Bekleyen Rezervasyonlar
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('guideId', isEqualTo: currentUser.uid)
                      .where('status', isEqualTo: 'pending')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                                children: [
                                  Icon(
                                    Icons.pending_actions,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Bekleyen rezervasyon bulunmuyor',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Yeni rezervasyonlar burada görünecek',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking =
                            bookings[index].data() as Map<String, dynamic>;
                        final bookingId = bookings[index].id;
                        return _buildBookingCard(booking, bookingId);
                      },
                    );
                  },
                ),
                // Onaylanan Rezervasyonlar
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('guideId', isEqualTo: currentUser.uid)
                      .where('status', isEqualTo: 'confirmed')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Onaylanan rezervasyon bulunmuyor',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Onayladığınız rezervasyonlar burada görünecek',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking =
                            bookings[index].data() as Map<String, dynamic>;
                        final bookingId = bookings[index].id;
                        return _buildBookingCard(booking, bookingId);
                      },
                    );
                  },
                ),
                // Tüm Rezervasyonlar
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('guideId', isEqualTo: currentUser.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Henüz rezervasyon bulunmuyor',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tüm rezervasyonlarınız burada görünecek',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking =
                            bookings[index].data() as Map<String, dynamic>;
                        final bookingId = bookings[index].id;
                        return _buildBookingCard(booking, bookingId);
                      },
                    );
                  },
                ),
              ],
            ),
    );
  }
}
