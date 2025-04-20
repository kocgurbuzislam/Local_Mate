class Route {
  final String id;
  final String name;
  final String description;
  final String cityId;
  final List<String> places;
  final String duration;
  final String difficulty;
  final String image;
  final double rating;
  final int reviewCount;

  Route({
    required this.id,
    required this.name,
    required this.description,
    required this.cityId,
    required this.places,
    required this.duration,
    required this.difficulty,
    required this.image,
    this.rating = 0.0,
    this.reviewCount = 0,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      cityId: json['cityId'],
      places: List<String>.from(json['places']),
      duration: json['duration'],
      difficulty: json['difficulty'],
      image: json['image'],
      rating: json['rating']?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cityId': cityId,
      'places': places,
      'duration': duration,
      'difficulty': difficulty,
      'image': image,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }
}
