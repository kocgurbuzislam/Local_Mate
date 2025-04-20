import 'package:yerel_rehber_app/data/entity/photo.dart';
import 'location.dart';

class Restaurant {
  final String name;
  final double? rating;
  final int? userRatingsTotal;
  final String? address;
  final String placeId;
  final Location? location;
  final bool? openNow;
  final List<String>? types;
  final List<Photo>? photos;
  final String? photoUrl;
  final List<dynamic>? reviews;
  final String? website;
  final String? phoneNumber;
  final String? internationalPhoneNumber;
  final Map<String, dynamic>? openingHours;
  final String? vicinity;
  final String? url;
  final int? utcOffset;

  Restaurant({
    required this.name,
    this.rating,
    this.userRatingsTotal,
    this.address,
    required this.placeId,
    this.location,
    this.openNow,
    this.types,
    this.photos,
    this.photoUrl,
    this.reviews,
    this.website,
    this.phoneNumber,
    this.internationalPhoneNumber,
    this.openingHours,
    this.vicinity,
    this.url,
    this.utcOffset,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    List<Photo>? parsedPhotos;
    if (json['photos'] != null) {
      parsedPhotos = (json['photos'] as List)
          .map(
              (photoJson) => Photo.fromJson(photoJson)) // Photo.fromJson kullan
          .toList();
    } else if (json['photo'] != null && json['photo'] is Map) {
      // Bazen 'photo' olarak tek bir map gelebilir (detaylarda nadir)
      parsedPhotos = [Photo.fromJson(json['photo'])];
    }

    return Restaurant(
      name: json['name'] ?? 'Ad Yok',
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: json['user_ratings_total'] as int?,
      // Adres için 'vicinity' veya 'formatted_address' kullanılabilir
      address: json['formatted_address'] ?? json['vicinity'] as String?,
      placeId: json['place_id'] as String? ?? '',
      // place_id genellikle olur ama null kontrolü ekleyelim
      location: json['geometry']?['location'] != null
          ? Location.fromJson(json['geometry']['location'])
          : null,
      // openNow için opening_hours içini kontrol et
      openNow: json['opening_hours']?['open_now'] as bool?,
      types: (json['types'] as List<dynamic>?)?.cast<String>(),
      photos: parsedPhotos,
      // Ayrıştırılmış fotoğrafları kullan
      // photoUrl anahtarını doğrudan aramıyoruz, photos listesi öncelikli
      photoUrl: null,
      // Bu alan API'den doğrudan gelmez, photos'tan türetilir. Modelde tutmaya gerek olmayabilir.
      reviews: json['reviews'] as List<dynamic>?,
      // Yorumları al
      website: json['website'] as String?,
      phoneNumber: json['formatted_phone_number'] as String?,
      internationalPhoneNumber: json['international_phone_number'] as String?,
      openingHours: json['opening_hours'] as Map<String, dynamic>?,
      vicinity: json['vicinity'] as String?,
      url: json['url'] as String?,
      utcOffset: json['utc_offset'] as int?,
    );
  }
}
