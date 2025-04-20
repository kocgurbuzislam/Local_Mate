import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yerel_rehber_app/data/entity/city.dart';
import 'package:yerel_rehber_app/data/entity/hotel.dart';
import 'package:yerel_rehber_app/data/entity/restaurant.dart';
import 'package:yerel_rehber_app/data/entity/route.dart';
import 'package:yerel_rehber_app/data/entity/photo.dart';
import 'package:http/http.dart' as http;

class TravelRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final String googleApiKey =
      dotenv.env['GOOGLE_API_KEY'] ?? 'API_KEY_BULUNAMADI';

  final Map<String, List<Restaurant>> _restaurantCache = {};
  final Map<String, List<Hotel>> _hotelCache = {};
  final Duration _cacheDuration = const Duration(minutes: 30);
  final Map<String, DateTime> _lastFetchTime = {};
  final Map<String, Future<List<Restaurant>>> _pendingRestaurantRequests = {};
  final Map<String, Future<List<Hotel>>> _pendingHotelRequests = {};

  Future<List<Restaurant>> fetchRestaurants(String city) async {
    final cacheKey = city.toLowerCase();
    final now = DateTime.now();

    if (_restaurantCache.containsKey(cacheKey) &&
        _lastFetchTime.containsKey('restaurant_$cacheKey') &&
        now.difference(_lastFetchTime['restaurant_$cacheKey']!) <
            _cacheDuration) {
      return _restaurantCache[cacheKey]!;
    }

    if (_pendingRestaurantRequests.containsKey(cacheKey)) {
      return _pendingRestaurantRequests[cacheKey]!;
    }

    _pendingRestaurantRequests[cacheKey] = _fetchRestaurantsFromApi(city);

    try {
      final restaurants = await _pendingRestaurantRequests[cacheKey]!;
      _restaurantCache[cacheKey] = restaurants;
      _lastFetchTime['restaurant_$cacheKey'] = now;
      return restaurants;
    } finally {
      _pendingRestaurantRequests.remove(cacheKey);
    }
  }

  Future<List<Restaurant>> _fetchRestaurantsFromApi(String city) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=restaurants+in+$city&key=$googleApiKey&region=tr';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == 'REQUEST_DENIED') {
          throw Exception('API Anahtarı hatası: ${data['error_message']}');
        }

        final results = data['results'] as List;
        final restaurants = await Future.wait(results.map((place) async {
          final placeId = place['place_id'];
          final detailsUrl =
              'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=photos,name,formatted_address,rating,user_ratings_total,price_level,geometry,website,formatted_phone_number,opening_hours,reviews,types,vicinity,url,utc_offset,formatted_phone_number,international_phone_number,opening_hours,website&key=$googleApiKey';

          print('Detay URL: $detailsUrl');
          final detailsResponse = await http.get(Uri.parse(detailsUrl));
          final detailsData = jsonDecode(detailsResponse.body);
          print('API Yanıtı: ${detailsData['result']}');

          List<Photo> photos = [];
          if (detailsData['result'] != null &&
              detailsData['result']['photos'] != null) {
            photos = (detailsData['result']['photos'] as List).map((photo) {
              return Photo(
                photoReference: photo['photo_reference'] as String,
                width: photo['width'] as int? ?? 400,
                height: photo['height'] as int? ?? 400,
              );
            }).toList();
          }

          return Restaurant.fromJson({
            ...place,
            'photos': detailsData['result']['photos'] ?? [],
            'name': detailsData['result']['name'] ?? place['name'],
            'formatted_address': detailsData['result']['formatted_address'] ??
                place['formatted_address'],
            'rating': detailsData['result']['rating'] ?? place['rating'],
            'user_ratings_total': detailsData['result']['user_ratings_total'] ??
                place['user_ratings_total'],
            'price_level':
                detailsData['result']['price_level'] ?? place['price_level'],
            'geometry': detailsData['result']['geometry'] ?? place['geometry'],
            'website': detailsData['result']['website'],
            'phone_number': detailsData['result']['formatted_phone_number'],
            'opening_hours': detailsData['result']['opening_hours'],
            'reviews': detailsData['result']['reviews'],
            'types': detailsData['result']['types'],
            'vicinity': detailsData['result']['vicinity'],
            'url': detailsData['result']['url'],
            'utc_offset': detailsData['result']['utc_offset'],
            'international_phone_number': detailsData['result']
                ['international_phone_number'],
          });
        }));

        return restaurants;
      } else {
        throw Exception('API Hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Restoranlar yüklenirken bir hata oluştu: $e');
    }
  }

  Future<List<Hotel>> fetchHotels(String city) async {
    final cacheKey = city.toLowerCase();
    final now = DateTime.now();

    if (_hotelCache.containsKey(cacheKey) &&
        _lastFetchTime.containsKey('hotel_$cacheKey') &&
        now.difference(_lastFetchTime['hotel_$cacheKey']!) < _cacheDuration) {
      return _hotelCache[cacheKey]!;
    }

    if (_pendingHotelRequests.containsKey(cacheKey)) {
      return _pendingHotelRequests[cacheKey]!;
    }

    _pendingHotelRequests[cacheKey] = _fetchHotelsFromApi(city);

    try {
      final hotels = await _pendingHotelRequests[cacheKey]!;
      _hotelCache[cacheKey] = hotels;
      _lastFetchTime['hotel_$cacheKey'] = now;
      return hotels;
    } finally {
      _pendingHotelRequests.remove(cacheKey);
    }
  }

  Future<List<Hotel>> _fetchHotelsFromApi(String city) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=hotels+in+$city&key=$googleApiKey&region=tr';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == 'REQUEST_DENIED') {
          throw Exception('API Anahtarı hatası: ${data['error_message']}');
        }

        final results = data['results'] as List;
        final hotels = await Future.wait(results.map((place) async {
          final placeId = place['place_id'];
          final detailsUrl =
              'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=photos,name,formatted_address,rating,user_ratings_total,price_level,geometry,website,formatted_phone_number,opening_hours,reviews,types,vicinity,url,utc_offset,formatted_phone_number,international_phone_number,opening_hours,website&key=$googleApiKey';

          final detailsResponse = await http.get(Uri.parse(detailsUrl));
          final detailsData = jsonDecode(detailsResponse.body);

          List<Photo> photos = [];
          if (detailsData['result'] != null &&
              detailsData['result']['photos'] != null) {
            photos = (detailsData['result']['photos'] as List).map((photo) {
              return Photo(
                photoReference: photo['photo_reference'] as String,
                width: photo['width'] as int? ?? 400,
                height: photo['height'] as int? ?? 400,
              );
            }).toList();
          }

          return Hotel.fromJson({
            ...place,
            'photos': detailsData['result']['photos'] ?? [],
            'name': detailsData['result']['name'] ?? place['name'],
            'formatted_address': detailsData['result']['formatted_address'] ??
                place['formatted_address'],
            'rating': detailsData['result']['rating'] ?? place['rating'],
            'user_ratings_total': detailsData['result']['user_ratings_total'] ??
                place['user_ratings_total'],
            'price_level':
                detailsData['result']['price_level'] ?? place['price_level'],
            'geometry': detailsData['result']['geometry'] ?? place['geometry'],
            'website': detailsData['result']['website'],
            'phone_number': detailsData['result']['formatted_phone_number'],
            'opening_hours': detailsData['result']['opening_hours'],
            'reviews': detailsData['result']['reviews'],
            'types': detailsData['result']['types'],
            'vicinity': detailsData['result']['vicinity'],
            'url': detailsData['result']['url'],
            'utc_offset': detailsData['result']['utc_offset'],
            'international_phone_number': detailsData['result']
                ['international_phone_number'],
          });
        }));

        return hotels;
      } else {
        throw Exception('API Hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Oteller yüklenirken bir hata oluştu: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCities() async {
    final String url = '${dotenv.env["CITY_ENDPOINT"]}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data'] as List;

        return results.map((city) {
          return {
            'name': city['name'],
            'id': city['id'].toString(),
            'description': '${city['name']}, ${city['region']['tr']}',
            'rating': 4.5,
            'reviewCount': city['population'],
            'region': city['region']['tr'],
            'weatherInfo': '',
            'travelInfo': '',
            'foto': '',
            'population': city['population'],
            'latitude': city['coordinates']['latitude'],
            'longitude': city['coordinates']['longitude'],
            'isMetropolitan': city['isMetropolitan'],
            'isCoastal': city['isCoastal'],
            'area': city['area'],
            'altitude': city['altitude'],
            'areaCode': city['areaCode'][0],
          };
        }).toList()
          ..sort(
              (a, b) => a['name'].toString().compareTo(b['name'].toString()));
      } else {
        throw Exception(
            'Şehirler yüklenirken bir hata oluştu: ${response.statusCode}');
      }
    } catch (e) {
      // API çalışmadığında veya internet bağlantısı olmadığında
      // statik listeyi kullanıyoruz. Bu sayede uygulama offline modda da çalışabilir
      // ve kullanıcılar şehir listesine her zaman erişebilir.
      return _regions.entries.expand((region) {
        return region.value.map((cityName) {
          return {
            'name': cityName,
            'id': cityName
                .toLowerCase()
                .replaceAll('ğ', 'g')
                .replaceAll('ü', 'u')
                .replaceAll('ş', 's')
                .replaceAll('ı', 'i')
                .replaceAll('ö', 'o')
                .replaceAll('ç', 'c')
                .replaceAll(' ', '-'),
            'description': '$cityName, ${region.key}',
            'rating': 4.5,
            'reviewCount': 1000,
            'region': region.key,
            'weatherInfo': '',
            'travelInfo': '',
            'foto': '',
          };
        });
      }).toList()
        ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    }
  }

  final Map<String, List<String>> _regions = {
    'Marmara': [
      'İstanbul',
      'Bursa',
      'Kocaeli',
      'Tekirdağ',
      'Balıkesir',
      'Edirne',
      'Çanakkale',
      'Yalova',
      'Kırklareli',
      'Bilecik',
      'Sakarya'
    ],
    'Ege': [
      'İzmir',
      'Aydın',
      'Muğla',
      'Denizli',
      'Manisa',
      'Kütahya',
      'Afyonkarahisar',
      'Uşak'
    ],
    'Akdeniz': [
      'Antalya',
      'Mersin',
      'Adana',
      'Hatay',
      'Burdur',
      'Isparta',
      'Osmaniye',
      'Kahramanmaraş'
    ],
    'İç Anadolu': [
      'Ankara',
      'Konya',
      'Kayseri',
      'Eskişehir',
      'Sivas',
      'Yozgat',
      'Aksaray',
      'Niğde',
      'Nevşehir',
      'Kırşehir',
      'Kırıkkale',
      'Karaman',
      'Çankırı'
    ],
    'Karadeniz': [
      'Samsun',
      'Trabzon',
      'Rize',
      'Ordu',
      'Giresun',
      'Amasya',
      'Sinop',
      'Tokat',
      'Çorum',
      'Kastamonu',
      'Bayburt',
      'Bartın',
      'Karabük',
      'Zonguldak',
      'Bolu',
      'Düzce',
      'Artvin',
      'Gümüşhane'
    ],
    'Doğu Anadolu': [
      'Erzurum',
      'Van',
      'Malatya',
      'Elazığ',
      'Ağrı',
      'Kars',
      'Erzincan',
      'Ardahan',
      'Bitlis',
      'Tunceli',
      'Bingöl',
      'Iğdır',
      'Muş',
      'Hakkari'
    ],
    'Güneydoğu Anadolu': [
      'Gaziantep',
      'Diyarbakır',
      'Şanlıurfa',
      'Batman',
      'Mardin',
      'Siirt',
      'Adıyaman',
      'Kilis',
      'Şırnak'
    ],
  };

  Future<List<Map<String, String>>> fetchLanguages() async {
    final String url = '${dotenv.env["LANGUAGE_ENDPOINT"]}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final Set<Map<String, String>> languages = {};

      for (var country in data) {
        if (country['languages'] != null) {
          (country['languages'] as Map<String, dynamic>).forEach((code, name) {
            languages.add({
              'name': name,
              'code': code,
              'flag': country['flag'] ?? '🏳️',
            });
          });
        }
      }

      return languages.toList()
        ..sort((a, b) => a['name']!.compareTo(b['name']!));
    } else {
      throw Exception(
          'Diller yüklenirken bir hata oluştu: ${response.statusCode}');
    }
  }
}
