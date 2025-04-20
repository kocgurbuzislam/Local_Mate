import 'dart:convert';

import 'package:http/http.dart' as http;

class CityRepository {
  Future<List<String>> fetchCities() async {
    final response =
        await http.get(Uri.parse('https://turkiyeapi.dev/api/v1/provinces'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['data'].map((city) => city['name']));
    } else {
      throw Exception('Şehirler yüklenemedi');
    }
  }
}
