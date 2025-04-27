import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerel_rehber_app/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class GuideWithdrawPage extends StatefulWidget {
  const GuideWithdrawPage({Key? key}) : super(key: key);

  @override
  State<GuideWithdrawPage> createState() => _GuideWithdrawPageState();
}

class _GuideWithdrawPageState extends State<GuideWithdrawPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _ibanController = TextEditingController();
  bool _isLoading = false;
  double _userBalance = 0;
  String _accountHolder = '';
  bool _hasValidPaymentInfo = false;
  double _amount = 0;
  double _availableBalance = 0.0;
  bool _isProcessing = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  // Platform ücreti oranı
  final double _platformFeeRate = 0.05; // %5

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR');
    _loadAvailableBalance();
    _loadUserBalance();
    _loadPaymentInfo();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableBalance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Onaylanmış rezervasyonlardan toplam kazancı hesapla
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('guideId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'confirmed')
          .where('paymentReleased', isEqualTo: true)
          .get();

      double totalEarnings = 0.0;
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        totalEarnings += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Tamamlanmış para çekme işlemlerini hesapla
      final withdrawalsSnapshot = await FirebaseFirestore.instance
          .collection('withdrawals')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalWithdrawn = 0.0;
      for (var doc in withdrawalsSnapshot.docs) {
        final data = doc.data();
        totalWithdrawn += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Bekleyen para çekme işlemlerini hesapla
      final pendingWithdrawalsSnapshot = await FirebaseFirestore.instance
          .collection('withdrawals')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      double pendingWithdrawals = 0.0;
      for (var doc in pendingWithdrawalsSnapshot.docs) {
        final data = doc.data();
        pendingWithdrawals += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Kullanılabilir bakiye = Toplam kazanç - Toplam çekilen - Bekleyen çekimler
      final availableBalance =
          totalEarnings - totalWithdrawn - pendingWithdrawals;

      setState(() {
        _availableBalance = availableBalance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bakiye yüklenirken bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUserBalance() async {
    // Implementation of _loadUserBalance method
  }

  Future<void> _loadPaymentInfo() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('guides')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _ibanController.text = data['iban'] ?? '';
          _accountHolder = data['accountHolder'] ?? '';
          _hasValidPaymentInfo = data['hasValidPaymentInfo'] ?? false;
        });
      }
    } catch (e) {
      print('Ödeme bilgileri yüklenirken hata: $e');
    }
  }

  Future<void> _processWithdrawal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasValidPaymentInfo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce ödeme bilgilerinizi güncelleyin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir miktar girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount > _availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yetersiz bakiye'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final batch = FirebaseFirestore.instance.batch();

      // Platform ücretini hesapla
      final platformFee = amount * _platformFeeRate;
      final netAmount = amount - platformFee;

      // Para çekme işlemini kaydet
      final withdrawalRef =
          FirebaseFirestore.instance.collection('withdrawals').doc();
      batch.set(withdrawalRef, {
        'userId': userId,
        'amount': amount,
        'platformFee': platformFee,
        'netAmount': netAmount,
        'status': 'pending',
        'iban': _ibanController.text.trim(),
        'accountHolder': _accountHolder,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Para çekme talebi başarıyla oluşturuldu'),
            backgroundColor: Colors.green,
          ),
        );
        // Formu temizle
        _amountController.clear();
        // Bakiye bilgisini güncelle
        _loadAvailableBalance();
      }
    } catch (e) {
      print('Para çekme işlemi sırasında hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Para çekme işlemi başarısız oldu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Para Çekme',
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
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: mainColor,
                strokeWidth: 3,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 24),
                  _buildWithdrawalForm(),
                  const SizedBox(height: 24),
                  _buildWithdrawalHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kullanılabilir Bakiye',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Hesabım',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _currencyFormat.format(_availableBalance),
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu tutar, onaylanmış ve turist tarafından onaylanmış rezervasyonlardan elde ettiğiniz kazançlardan oluşmaktadır.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Para çekme işlemlerinde %5 platform ücreti alınmaktadır.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
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

  Widget _buildWithdrawalForm() {
    // Girilen tutar değiştiğinde platform ücretini hesapla
    double amount = 0;
    double platformFee = 0;
    double netAmount = 0;

    if (_amountController.text.isNotEmpty) {
      amount = double.tryParse(_amountController.text) ?? 0;
      platformFee = amount * _platformFeeRate;
      netAmount = amount - platformFee;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
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
                      Icons.payment,
                      color: mainColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Para Çekme Talebi',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Para çekme talebinizi oluşturmak için aşağıdaki formu doldurun.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _amount = double.tryParse(value) ?? 0;
                  });
                },
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  labelText: 'Çekilecek Tutar (TL)',
                  hintText: 'Örn: 1000',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: mainColor),
                  ),
                  labelStyle: GoogleFonts.poppins(),
                  hintStyle: GoogleFonts.poppins(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen bir tutar girin';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return 'Geçerli bir tutar girin';
                  }
                  if (amount <= 0) {
                    return 'Tutar 0\'dan büyük olmalıdır';
                  }
                  if (amount > _availableBalance) {
                    return 'Çekilecek tutar kullanılabilir bakiyeden büyük olamaz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ibanController,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  labelText: 'IBAN',
                  hintText: 'TR...',
                  prefixIcon: const Icon(Icons.account_balance),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: mainColor),
                  ),
                  labelStyle: GoogleFonts.poppins(),
                  hintStyle: GoogleFonts.poppins(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen IBAN girin';
                  }
                  if (!_isValidIBAN(value)) {
                    return 'Geçerli bir IBAN girin (TR ile başlayan 26 karakter)';
                  }
                  return null;
                },
              ),
              if (amount > 0) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Çekilecek Tutar:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _currencyFormat.format(amount),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Platform Ücreti (%5):',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _currencyFormat.format(platformFee),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hesabınıza Yatırılacak:',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            _currencyFormat.format(netAmount),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processWithdrawal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Para Çekme Talebi Oluştur',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Para çekme talepleriniz 1-3 iş günü içinde işleme alınacaktır.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawalHistory() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                    Icons.history,
                    color: mainColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Para Çekme Geçmişi',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('withdrawals')
                  .where('userId', isEqualTo: _auth.currentUser?.uid)
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

                final withdrawals = snapshot.data?.docs ?? [];

                if (withdrawals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz para çekme talebiniz bulunmuyor',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Para çekme talepleriniz burada görünecek',
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
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: withdrawals.length,
                  itemBuilder: (context, index) {
                    final withdrawal =
                        withdrawals[index].data() as Map<String, dynamic>;
                    final amount = withdrawal['amount'] as double? ?? 0.0;
                    final netAmount = withdrawal['netAmount'] as double? ?? 0.0;
                    final platformFee =
                        withdrawal['platformFee'] as double? ?? 0.0;
                    final status = withdrawal['status'] as String? ?? 'pending';
                    final createdAt = withdrawal['createdAt'] as Timestamp?;
                    final updatedAt = withdrawal['updatedAt'] as Timestamp?;

                    Color statusColor;
                    String statusText;
                    IconData statusIcon;

                    switch (status) {
                      case 'completed':
                        statusColor = Colors.green;
                        statusText = 'Tamamlandı';
                        statusIcon = Icons.check_circle;
                        break;
                      case 'pending':
                        statusColor = Colors.orange;
                        statusText = 'İşlemde';
                        statusIcon = Icons.pending;
                        break;
                      case 'rejected':
                        statusColor = Colors.red;
                        statusText = 'Reddedildi';
                        statusIcon = Icons.cancel;
                        break;
                      default:
                        statusColor = Colors.grey;
                        statusText = 'Bilinmiyor';
                        statusIcon = Icons.help;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _currencyFormat.format(amount),
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      statusIcon,
                                      size: 16,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusText,
                                      style: GoogleFonts.poppins(
                                        color: statusColor,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'IBAN: ${withdrawal['iban']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Talep: ${createdAt != null ? DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(createdAt.toDate()) : 'Belirtilmemiş'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          if (updatedAt != null && status != 'pending') ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.update,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Güncelleme: ${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(updatedAt.toDate())}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (status == 'completed') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Platform Ücreti:',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        _currencyFormat.format(platformFee),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.red[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Hesabınıza Yatırılan:',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      Text(
                                        _currencyFormat.format(netAmount),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidIBAN(String iban) {
    // Basit IBAN doğrulama - TR ile başlamalı ve 26 karakter olmalı
    return iban.startsWith('TR') && iban.length == 26;
  }
}
