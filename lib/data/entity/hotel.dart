import 'package:yerel_rehber_app/data/entity/photo.dart';

class Hotel {
  final String name;
  final String? address;
  final double? rating;
  final int? totalReviews;
  final int? priceLevel;
  final double? latitude;
  final double? longitude;
  final List<Photo>? photos;
  final String? placeId;
  final String? website;
  final String? phoneNumber;
  final Map<String, dynamic>? openingHours;
  final List<dynamic>? reviews;
  final List<String>? types;
  final String? vicinity;
  final String? url;
  final int? utcOffset;
  final String? internationalPhoneNumber;

  Hotel({
    required this.name,
    this.address,
    this.rating,
    this.totalReviews,
    this.priceLevel,
    this.latitude,
    this.longitude,
    this.photos,
    this.placeId,
    this.website,
    this.phoneNumber,
    this.openingHours,
    this.reviews,
    this.types,
    this.vicinity,
    this.url,
    this.utcOffset,
    this.internationalPhoneNumber,
  });

  factory Hotel.fromJson(Map<String, dynamic> json) {
    List<Photo>? photos;
    if (json['photos'] != null) {
      photos = (json['photos'] as List).map((photo) {
        return Photo(
          photoReference: photo['photo_reference'] as String,
          width: photo['width'] as int? ?? 400,
          height: photo['height'] as int? ?? 400,
        );
      }).toList();
    }

    return Hotel(
      name: json['name'] as String,
      address: json['formatted_address'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      totalReviews: json['user_ratings_total'] as int?,
      priceLevel: json['price_level'] as int?,
      latitude: json['geometry']?['location']?['lat'] as double?,
      longitude: json['geometry']?['location']?['lng'] as double?,
      photos: photos,
      placeId: json['place_id'] as String?,
      website: json['website'] as String?,
      phoneNumber: json['formatted_phone_number'] as String?,
      openingHours: json['opening_hours'] as Map<String, dynamic>?,
      reviews: json['reviews'] as List<dynamic>?,
      types: (json['types'] as List<dynamic>?)?.cast<String>(),
      vicinity: json['vicinity'] as String?,
      url: json['url'] as String?,
      utcOffset: json['utc_offset'] as int?,
      internationalPhoneNumber: json['international_phone_number'] as String?,
    );
  }
}
