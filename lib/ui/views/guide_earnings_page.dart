import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerel_rehber_app/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class GuideEarningsPage extends StatefulWidget {
  const GuideEarningsPage({Key? key}) : super(key: key);

  @override
  State<GuideEarningsPage> createState() => _GuideEarningsPageState();
}

class _GuideEarningsPageState extends State<GuideEarningsPage> {
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Kazançlarım',
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
          : StreamBuilder<QuerySnapshot>(
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
                                Icons.account_balance_wallet_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz bir kazanç bulunmuyor',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Rehberlik hizmetleriniz onaylandıkça\nkazançlarınız burada görünecek',
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

                // Toplam kazancı hesapla
                double totalEarnings = 0;
                Map<String, double> serviceEarnings = {};

                for (var booking in bookings) {
                  final data = booking.data() as Map<String, dynamic>;
                  if (data['status'] == 'confirmed') {
                    final amount = (data['amount'] as num).toDouble();
                    totalEarnings += amount;

                    final serviceName =
                        data['serviceName'] as String? ?? 'Diğer';
                    serviceEarnings[serviceName] =
                        (serviceEarnings[serviceName] ?? 0) + amount;
                  }
                }

                // Pasta grafiği için veri hazırla
                List<PieChartSectionData> sections = [];
                List<Color> colors = [
                  mainColor,
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                  Colors.purple,
                  Colors.teal,
                  Colors.pink,
                  Colors.indigo,
                ];

                int colorIndex = 0;
                serviceEarnings.forEach((service, amount) {
                  final percentage = (amount / totalEarnings) * 100;
                  sections.add(
                    PieChartSectionData(
                      color: colors[colorIndex % colors.length],
                      value: amount,
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: _touchedIndex == colorIndex ? 110 : 100,
                      titleStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      badgeWidget: _touchedIndex == colorIndex
                          ? _buildBadge(service, amount)
                          : null,
                      badgePositionPercentageOffset: 1.3,
                    ),
                  );
                  colorIndex++;
                });

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Toplam kazanç kartı
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [mainColor, mainColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: mainColor.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Toplam Kazanç',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${totalEarnings.toStringAsFixed(2)} TL',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${bookings.length} rezervasyon',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Kazanç Dağılımı Grafiği
                      if (serviceEarnings.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 24),
                          padding: const EdgeInsets.all(24),
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
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: mainColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.pie_chart_outline,
                                      color: mainColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Kazanç Dağılımı',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                height: 220,
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      enabled: true,
                                      touchCallback: (FlTouchEvent event,
                                          pieTouchResponse) {
                                        if (event is FlTapUpEvent) {
                                          // Dokunma olayını işle ve setState'i sadece gerektiğinde çağır
                                          if (pieTouchResponse
                                                  ?.touchedSection !=
                                              null) {
                                            final newIndex = pieTouchResponse!
                                                .touchedSection!
                                                .touchedSectionIndex;
                                            if (_touchedIndex != newIndex) {
                                              setState(() {
                                                _touchedIndex = newIndex;
                                              });
                                            }
                                          } else if (_touchedIndex != -1) {
                                            setState(() {
                                              _touchedIndex = -1;
                                            });
                                          }
                                        }
                                      },
                                    ),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    sections: sections,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Grafik Açıklamaları
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: serviceEarnings.entries.map((entry) {
                                  final index = serviceEarnings.keys
                                      .toList()
                                      .indexOf(entry.key);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color:
                                                colors[index % colors.length],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          entry.key,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Kazanç listesi
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: bookings.length,
                        itemBuilder: (context, index) {
                          final booking =
                              bookings[index].data() as Map<String, dynamic>;
                          final amount = booking['amount'] as double? ?? 0.0;
                          final serviceName =
                              booking['serviceName'] as String? ?? '';
                          final status = booking['status'] as String? ?? '';
                          final createdAt = booking['createdAt'] as Timestamp?;
                          final numberOfPeople =
                              booking['numberOfPeople'] as int? ?? 1;
                          final bookingDate =
                              booking['bookingDate'] as Timestamp?;
                          final customerName =
                              booking['customerName'] as String? ?? '';

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
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
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  // Detay sayfasına yönlendirme eklenebilir
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: mainColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.map_outlined,
                                              color: mainColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  serviceName,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  customerName,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: status == 'confirmed'
                                                  ? Colors.green[50]
                                                  : Colors.orange[50],
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              status == 'confirmed'
                                                  ? 'Onaylandı'
                                                  : 'Bekliyor',
                                              style: GoogleFonts.poppins(
                                                color: status == 'confirmed'
                                                    ? Colors.green[700]
                                                    : Colors.orange[700],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
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
                                              DateFormat(
                                                      'dd MMMM yyyy', 'tr_TR')
                                                  .format(bookingDate.toDate()),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
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
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
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

  Widget _buildBadge(String service, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            service,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            '${amount.toStringAsFixed(0)} TL',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
