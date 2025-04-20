class Photo {
  final String photoReference;
  final int width;
  final int height;

  Photo(
      {required this.photoReference,
      required this.width,
      required this.height});

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      photoReference: json['photo_reference'] as String,
      width: json['width'] as int? ?? 400,
      height: json['height'] as int? ?? 400,
    );
  }
}
