import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GuideRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getGuides() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('guides').get();
      List<Map<String, dynamic>> guides = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> guideData = doc.data() as Map<String, dynamic>;
        String guideId = doc.id;
        guideData['id'] = guideId;
        print("Guide doküman ID: $guideId");

        String fullName = "Bilinmeyen Kullanıcı";

        try {
          DocumentSnapshot userDoc =
              await _firestore.collection('Users').doc(guideId).get();
          print(
              "Users koleksiyonundan veri çekiliyor. Doküman var mı: ${userDoc.exists}");

          if (userDoc.exists) {
            Map<String, dynamic> userData =
                userDoc.data() as Map<String, dynamic>;
            print("Çekilen kullanıcı verisi: $userData");

            if (userData['name'] != null &&
                userData['name'].toString().contains(' ')) {
              fullName = userData['name'].toString();
              print("Google kullanıcısı - Tam isim: $fullName");
            } else {
              String name = userData['name']?.toString() ?? '';
              String surname = userData['surname']?.toString() ?? '';

              if (name.isNotEmpty || surname.isNotEmpty) {
                fullName = "${name.trim()} ${surname.trim()}".trim();
                print("Normal kullanıcı - Tam isim: $fullName");
              }
            }
          } else {
            print("Users koleksiyonunda $guideId ID'li doküman bulunamadı");
          }
        } catch (e) {
          print("Kullanıcı bilgisi çekilirken hata: $e");
          fullName = "Bilinmeyen Kullanıcı";
        }

        guideData['fullName'] = fullName;

        dynamic cityData = guideData['city'];
        String cityName = 'Şehir belirtilmemiş';

        if (cityData != null) {
          if (cityData is String) {
            cityName = cityData;
          } else if (cityData is Map<String, dynamic>) {
            cityName = cityData['name'] ?? 'Şehir belirtilmemiş';
          }
        }

        guideData['cityName'] = cityName;

        // Yeni koleksiyondan yorumları çek
        QuerySnapshot reviewSnapshot = await _firestore
            .collection('reviews')
            .where('guideId', isEqualTo: guideId)
            .get();

        List<Map<String, dynamic>> reviews = reviewSnapshot.docs.map((doc) {
          Map<String, dynamic> reviewData = doc.data() as Map<String, dynamic>;
          reviewData['reviewId'] = doc.id;
          return reviewData;
        }).toList();

        guideData['reviews'] = reviews;
        guideData['reviewCount'] = reviews.length;
        guideData['rating'] = reviews.isNotEmpty
            ? reviews.fold(0.0, (sum, r) => sum + (r['rating'] ?? 0.0)) /
                reviews.length
            : 0.0;

        guides.add(guideData);
      }

      return guides;
    } catch (e) {
      print("getGuides metodu genel hatası: $e");
      throw Exception("Veri çekme hatası: $e");
    }
  }

  // Yeni yorum ekle (DocumentReference döndür)
  Future<DocumentReference> addReview({
    required String guideId,
    required String userId,
    required String comment,
    required int rating,
  }) async {
    try {
      return await _firestore.collection('reviews').add({
        'guideId': guideId,
        'userId': userId,
        'comment': comment,
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Yorum ekleme hatası: $e");
    }
  }

  // Yorum sil
  Future<void> deleteReview({
    required String guideId,
    required String reviewId,
  }) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).delete();
    } catch (e) {
      throw Exception("Yorum silme hatası: $e");
    }
  }

  // Yorum güncelle
  Future<Map<String, dynamic>?> updateReview({
    required String guideId,
    required String reviewId,
    required String comment,
    required int rating,
  }) async {
    try {
      print('Yorum güncelleniyor - Review ID: $reviewId');
      print('Güncellenecek veriler - Comment: $comment, Rating: $rating');

      final reviewRef = _firestore.collection('reviews').doc(reviewId);

      // Yorumun var olup olmadığını kontrol et
      final reviewDoc = await reviewRef.get();
      if (!reviewDoc.exists) {
        print('Yorum bulunamadı: $reviewId');
        throw Exception('Yorum bulunamadı');
      }

      // Güncellenecek verileri hazırla
      final updateData = {
        'comment': comment,
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('Güncellenecek veriler: $updateData');

      // Yorumu güncelle
      await reviewRef.update(updateData);

      // Güncellenmiş yorumu al
      final updatedReviewDoc = await reviewRef.get();
      final updatedReview = updatedReviewDoc.data();

      if (updatedReview != null) {
        print('Güncellenen yorum verisi: $updatedReview');
        return updatedReview;
      }

      return null;
    } catch (e) {
      print('Yorum güncellenirken hata oluştu: $e');
      rethrow;
    }
  }

  Future<void> saveGuideData({
    required List<Map<String, String>> selectedLanguages,
    required Map<String, dynamic> selectedCity,
    required List<String> routes,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      print("Kaydedilen userId: $userId"); // Debug log
      if (userId == null) throw Exception('Kullanıcı oturum açmamış');

      final guideData = {
        'userId': userId, // Doküman ID'si olarak kullanılacak
        'languages': selectedLanguages,
        'city': selectedCity,
        'routes': routes,
        'status': 'pending',
        'rating': 0.0, // Başlangıç değerlendirme puanı
        'reviewCount': 0, // Başlangıç yorum sayısı
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      print("Kaydedilen rehber verisi: $guideData"); // Debug log

      // Doküman ID'si olarak userId kullanılıyor
      await _firestore.collection('guides').doc(userId).set(
            guideData,
            SetOptions(merge: true),
          );

      // Kullanıcı rolünü güncelle - Users koleksiyonunda doküman ID'si olarak userId kullanılıyor
      await _firestore.collection('Users').doc(userId).update({
        'role': 'guide_pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Rehber kaydı yapılamadı: $e');
    }
  }

  Future<Map<String, dynamic>?> getGuideData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore.collection('guides').doc(userId).get();
      return doc.data();
    } catch (e) {
      throw Exception('Rehber bilgileri alınamadı: $e');
    }
  }
}
