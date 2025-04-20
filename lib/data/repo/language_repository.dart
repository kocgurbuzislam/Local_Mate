import 'dart:convert';

import 'package:http/http.dart' as http;

class LanguageRepository {
  Future<List<Map<String, String>>> fetchLanguages() async {
    final response =
        await http.get(Uri.parse('https://restcountries.com/v3.1/all'));
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      Set<Map<String, String>> languages = {};

      for (var country in data) {
        if (country['languages'] != null) {
          country['languages'].forEach((key, value) {
            languages.add({
              'code': key,
              'name': value,
              'flag': country['flags']['png'] ?? ''
            });
          });
        }
      }
      return languages.toList();
    } else {
      throw Exception("Failed to load languages");
    }
  }
}
