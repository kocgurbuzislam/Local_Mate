class City {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final List<String> popularPlaces;
  final String region;
  final String weatherInfo;
  final String travelInfo;
  final String foto;
  final double score;
  final int starNumber;

  City({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.popularPlaces,
    required this.region,
    required this.weatherInfo,
    required this.travelInfo,
    required this.foto,
    required this.score,
    required this.starNumber,
  });

  factory City.fromMap(Map<String, dynamic> map) {
    return City(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      imageUrl: map['imageUrl'] as String,
      rating: map['rating'] as double,
      reviewCount: map['reviewCount'] as int,
      popularPlaces: List<String>.from(map['popularPlaces'] as List),
      region: map['region'] as String,
      weatherInfo: map['weatherInfo'] as String,
      travelInfo: map['travelInfo'] as String,
      foto: map['foto'] as String,
      score: map['score'] as double,
      starNumber: map['starNumber'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'popularPlaces': popularPlaces,
      'region': region,
      'weatherInfo': weatherInfo,
      'travelInfo': travelInfo,
      'foto': foto,
      'score': score,
      'starNumber': starNumber,
    };
  }
}
