class Language {
  final String name;
  final String code;
  final String flag;

  Language({
    required this.name,
    required this.code,
    required this.flag,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      name: json['name'] as String,
      code: json['code'] as String,
      flag: json['flag'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'flag': flag,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Language &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          code == other.code;

  @override
  int get hashCode => name.hashCode ^ code.hashCode;
}
