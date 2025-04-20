import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerel_rehber_app/colors.dart';
import '../cubit/guide_cubit.dart';
import 'chat_screen.dart';
import '../../data/repo/guide_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class GuideDetailScreen extends StatefulWidget {
  final Map<String, dynamic> guideData;
  final String guideId;

  const GuideDetailScreen({
    Key? key,
    required this.guideData,
    required this.guideId,
  }) : super(key: key);

  @override
  _GuideDetailScreenState createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  final GuideRepository _guideRepository = GuideRepository();
  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;
  List<String> _guideImages = [];
  bool _isEditing = false;
  List<Map<String, dynamic>> _reviews = [];
  String? _editingReviewId;
  Map<String, dynamic>? _userReview;
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();
  bool _isImagesLoaded = false;
  bool _isLoading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _guideFullName = 'İsimsiz Rehber';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR');
    _guideFullName =
        _capitalizeName(widget.guideData['fullName'] ?? 'İsimsiz Rehber');
    _initializeData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (widget.guideData['photos'] != null &&
        widget.guideData['photos'].isNotEmpty) {
      setState(() {
        _guideImages = List<String>.from(widget.guideData['photos']);
        _isImagesLoaded = true;
      });
    } else {
      setState(() {
        _isImagesLoaded = true;
      });
    }
    await _loadReviews();
  }

  Future<void> _loadReviews() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('guideId', isEqualTo: widget.guideId)
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _reviews = reviewsSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yorumlar yüklenirken bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir puan verin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yorum yapmak için giriş yapmalısınız'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (_isEditing && _editingReviewId != null) {
        // Düzenleme durumu
        await context.read<GuideCubit>().updateReview(
              guideId: widget.guideId,
              reviewId: _editingReviewId!,
              comment: _commentController.text,
              rating: _rating,
            );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorumunuz başarıyla güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Yeni yorum ekleme durumu
        await context.read<GuideCubit>().addReview(
              guideId: widget.guideId,
              userId: currentUser.uid,
              comment: _commentController.text,
              rating: _rating,
            );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorumunuz başarıyla eklendi'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _rating = 0;
        _commentController.clear();
        _isEditing = false;
        _editingReviewId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      await context.read<GuideCubit>().deleteReview(
            guideId: widget.guideId,
            reviewId: reviewId,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yorumunuz başarıyla silindi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yorum silinirken bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _commentController.clear();
      _rating = 0;
      _isEditing = false;
      _editingReviewId = null;
    });
  }

  void _startEditing(Map<String, dynamic> review) {
    setState(() {
      _isEditing = true;
      _editingReviewId = review['id'];
      _commentController.text = review['comment'] ?? '';
      _rating = review['rating'] ?? 0;
    });
    _scrollToEditForm();
  }

  void _showReviewOptions(Map<String, dynamic> review) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Düzenle'),
            onTap: () {
              Navigator.pop(context);
              _startEditing(review);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Sil', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await _deleteReview(review['id']);
            },
          ),
        ],
      ),
    );
  }

  String _capitalizeName(String fullName) {
    if (fullName.isEmpty) return fullName;
    List<String> names = fullName.split(" ");
    for (int i = 0; i < names.length; i++) {
      if (names[i].isNotEmpty) {
        names[i] =
            names[i][0].toUpperCase() + names[i].substring(1).toLowerCase();
      }
    }
    return names.join(" ");
  }

  Future<String> _getUserProfileImage(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['profileImage'] ?? '';
      }
      return '';
    } catch (e) {
      print("Error fetching profile image for $userId: $e");
      return '';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return 'Tarih belirtilmemiş';
    }

    try {
      DateTime? date;

      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is Map<String, dynamic>) {
        if (timestamp['_seconds'] != null) {
          final seconds = timestamp['_seconds'] as int;
          date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      } else if (timestamp is Map) {
        // Firebase Timestamp'in farklı formatları için
        final seconds = timestamp['seconds'];
        final nanoseconds = timestamp['nanoseconds'];
        if (seconds != null) {
          date = DateTime.fromMillisecondsSinceEpoch(
            (seconds as int) * 1000 + ((nanoseconds as int) ~/ 1000000),
          );
        }
      }

      if (date != null) {
        return DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(date);
      }

      return 'Tarih belirtilmemiş';
    } catch (e) {
      print('Tarih formatlama hatası: $e');
      return 'Tarih belirtilmemiş';
    }
  }

  void _scrollToEditForm() {
    Future.delayed(const Duration(milliseconds: 300), () {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _handleContactButton() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen önce giriş yapın'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Debug için tüm guideData'yı yazdır
      print("Tüm Guide Data: ${widget.guideData}");

      // Guide ID'yi kontrol et
      final guideId = widget.guideId;
      print("Guide ID: $guideId");

      if (guideId.isEmpty) {
        print("Hata: Guide ID boş! Guide Data: ${widget.guideData}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rehber ID bulunamadı'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Guide verilerini Firestore'dan al
      print("Firestore'dan guide verisi çekiliyor...");
      final guideDoc = await FirebaseFirestore.instance
          .collection('guides')
          .doc(guideId)
          .get();

      if (!guideDoc.exists) {
        print("Hata: Guide dokümanı bulunamadı!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rehber bulunamadı'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final guideData = guideDoc.data();
      if (guideData == null) {
        print("Hata: Guide verisi null!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rehber verileri alınamadı'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print("Firestore'dan alınan guide verisi: $guideData");

      // Guide ID'yi userId olarak kullan
      final guideUserId = guideId;
      print("Guide User ID: $guideUserId");

      if (guideUserId == currentUser.uid) {
        print("Hata: Kullanıcı kendine mesaj göndermeye çalışıyor!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kendinize mesaj gönderemezsiniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Chat ID oluştur
      final chatId = [currentUser.uid, guideUserId]..sort();
      final chatRoomId = chatId.join('_');
      print("Oluşturulan Chat Room ID: $chatRoomId");

      // Chat odasını oluştur
      print("Chat odası oluşturuluyor...");
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .set({
        'users': [currentUser.uid, guideUserId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("Chat ekranına yönlendiriliyor...");
      // Chat ekranına yönlendir
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
            chatId: chatRoomId,
            guideId: guideUserId,
            guideName: widget.guideData['fullName'] ?? 'İsimsiz Rehber',
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = const Offset(1.0, 0.0);
            var end = Offset.zero;
            var curve = Curves.ease;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    } catch (e, stackTrace) {
      print("İletişime Geç Hatası: $e");
      print("Stack Trace: $stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLanguagesSection() {
    final languages = widget.guideData['languages'] as List?;
    if (languages == null || languages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
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
            'Bildiği Diller',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: languages.map<Widget>((language) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (language['flag'] != null)
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: NetworkImage(language['flag']),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Text(
                      language['name'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guideBio = widget.guideData['bio'] as String? ?? '';
    final guideRoutes = widget.guideData['routes'] as List<dynamic>? ?? [];
    final guideCityName =
        widget.guideData['cityName'] as String? ?? 'Şehir belirtilmemiş';
    final guideLanguages =
        widget.guideData['languages'] as List<dynamic>? ?? [];

    double averageRating = 0;
    if (_reviews.isNotEmpty) {
      averageRating = _reviews
              .map((r) => r['rating'] as int? ?? 0)
              .reduce((a, b) => a + b) /
          _reviews.length;
    }
    int reviewCount = _reviews.length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: mainColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isImagesLoaded && _guideImages.isNotEmpty)
                    PageView(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() {
                          _currentPhotoIndex = index;
                        });
                      },
                      children: _guideImages.map((imageUrl) {
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: mainColor, strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.broken_image_outlined,
                                size: 60, color: Colors.grey[500]),
                          ),
                        );
                      }).toList(),
                    )
                  else if (_isImagesLoaded && _guideImages.isEmpty)
                    Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.person,
                          size: 100, color: Colors.grey[400]),
                    )
                  else
                    Container(
                      color: Colors.grey[200],
                      child: Center(
                          child: CircularProgressIndicator(
                              color: mainColor, strokeWidth: 2)),
                    ),
                  if (_isImagesLoaded && _guideImages.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _guideImages.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == _currentPhotoIndex
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Guide Header Info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _guideFullName,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (reviewCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: mainColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star,
                                      size: 18, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Location Info
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              color: mainColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            guideCityName,
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      // Languages Info
                      if (guideLanguages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.language_outlined,
                                color: mainColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${guideLanguages.length} dil biliyor',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ],
                      // Review Count Info
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.rate_review_outlined,
                              color: mainColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$reviewCount yorum',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // --- About Section ---
                if (guideBio.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.white,
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hakkında',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 10),
                        Text(
                          guideBio,
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                if (guideBio.isNotEmpty) const SizedBox(height: 8),

                // --- Languages Section ---
                _buildLanguagesSection(),
                const SizedBox(height: 8),

                // --- Routes Section ---
                if (guideRoutes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rotalar',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: guideRoutes.length,
                          itemBuilder: (context, index) {
                            final route =
                                guideRoutes[index] as Map<String, dynamic>? ??
                                    {};
                            final routeName =
                                route['name'] as String? ?? 'İsimsiz Rota';
                            final routeDesc =
                                route['description'] as String? ?? '';
                            final routeDuration =
                                route['duration']?.toString() ?? '?';
                            final routePrice =
                                route['price']?.toString() ?? '?';
                            final routePlaces =
                                route['places'] as List<dynamic>? ?? [];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[200]!),
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
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.map_outlined,
                                            color: mainColor, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          routeName,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (routeDesc.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(routeDesc,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600])),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.timer_outlined,
                                          size: 16, color: Colors.blueGrey),
                                      const SizedBox(width: 4),
                                      Text('$routeDuration saat',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700])),
                                      const SizedBox(width: 16),
                                      Icon(Icons.attach_money_outlined,
                                          size: 16, color: Colors.green[700]),
                                      const SizedBox(width: 4),
                                      Text('$routePrice TL',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700])),
                                    ],
                                  ),
                                  if (routePlaces.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Gezilecek Yerler:',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[800]),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children:
                                          routePlaces.map<Widget>((place) {
                                        return Chip(
                                          label: Text(place.toString(),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700])),
                                          backgroundColor: Colors.grey[100],
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              side: BorderSide(
                                                  color: Colors.grey[200]!)),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                if (guideRoutes.isNotEmpty) const SizedBox(height: 8),

                // --- Reviews Section ---
                _buildReviewSection(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
              spreadRadius: 0,
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _handleContactButton,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'İletişime Geç',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
  }

  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yorumlar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              // Yorum yapma formu
              if (_auth.currentUser != null)
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
                        _isEditing ? 'Yorumu Düzenle' : 'Yorum Yap',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(
                          5,
                          (index) => IconButton(
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                            onPressed: () {
                              setState(() {
                                _rating = index + 1;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Yorumunuzu yazın...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: mainColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_isEditing)
                            Expanded(
                              child: TextButton(
                                onPressed: _resetForm,
                                child: const Text('İptal'),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          SizedBox(width: _isEditing ? 16 : 0),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submitReview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _isEditing ? 'Güncelle' : 'Gönder',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Tüm yorumlar
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reviews')
                    .where('guideId', isEqualTo: widget.guideId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Bir hata oluştu: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: mainColor,
                        strokeWidth: 3,
                      ),
                    );
                  }

                  final reviews = snapshot.data!.docs;

                  if (reviews.isEmpty) {
                    return Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz yorum yapılmamış',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review =
                          reviews[index].data() as Map<String, dynamic>;
                      final reviewId = reviews[index].id;
                      final isCurrentUserReview =
                          review['userId'] == _auth.currentUser?.uid;

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('Users')
                            .doc(review['userId'])
                            .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final userData = userSnapshot.data!.data()
                              as Map<String, dynamic>?;
                          final userName = userData?['name'] ?? '';
                          final userSurname = userData?['surname'] ?? '';
                          final fullName = '$userName $userSurname'.trim();
                          final userImage =
                              userData?['profileImage'] as String?;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
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
                                Row(
                                  children: [
                                    if (userImage != null &&
                                        userImage.isNotEmpty)
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage:
                                            NetworkImage(userImage),
                                      )
                                    else
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            mainColor.withOpacity(0.1),
                                        child: Text(
                                          fullName.isNotEmpty
                                              ? fullName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: mainColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Row(
                                            children: List.generate(
                                              5,
                                              (index) => Icon(
                                                index <
                                                        (review['rating']
                                                                as int? ??
                                                            0)
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrentUserReview)
                                      IconButton(
                                        icon: const Icon(Icons.more_vert),
                                        onPressed: () {
                                          _showReviewOptions({
                                            ...review,
                                            'id': reviewId,
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  review['comment'] as String,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatTimestamp(review['timestamp']),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
