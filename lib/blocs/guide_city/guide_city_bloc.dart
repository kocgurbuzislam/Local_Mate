import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'guide_city_event.dart';
import 'guide_city_state.dart';

class GuideCityBloc extends Bloc<GuideCityEvent, GuideCityState> {
  GuideCityBloc() : super(const GuideCityState()) {
    on<LoadCities>(_onLoadCities);
    on<SearchCities>(_onSearchCities);
    on<SelectCity>(_onSelectCity);
    on<SaveSelectedCity>(_onSaveSelectedCity);
    on<LoadSelectedCity>(_onLoadSelectedCity);
  }

  Future<void> _onLoadCities(
      LoadCities event, Emitter<GuideCityState> emit) async {
    try {
      emit(state.copyWith(isLoading: true));
      final response =
          await http.get(Uri.parse('https://turkiyeapi.dev/api/v1/provinces'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> provinces = data['data'];

        final cities = provinces.map((province) {
          return {
            'id': province['id'].toString(),
            'name': province['name'],
            'region': province['region']['tr'],
            'population': province['population'],
            'area': province['area'],
            'districts': (province['districts'] as List)
                .map((district) => district['name'])
                .toList(),
          };
        }).toList();

        emit(state.copyWith(
          cities: cities,
          filteredCities: cities,
          isLoading: false,
        ));
      } else {
        emit(state.copyWith(
          error: 'Şehirler yüklenirken bir hata oluştu',
          isLoading: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Şehirler yüklenirken bir hata oluştu: $e',
        isLoading: false,
      ));
    }
  }

  void _onSearchCities(SearchCities event, Emitter<GuideCityState> emit) {
    final query = event.query.toLowerCase();
    final filteredCities = state.cities.where((city) {
      return city['name'].toLowerCase().contains(query) ||
          city['region'].toLowerCase().contains(query);
    }).toList();

    emit(state.copyWith(
      filteredCities: filteredCities,
      searchQuery: query,
    ));
  }

  void _onSelectCity(SelectCity event, Emitter<GuideCityState> emit) {
    emit(state.copyWith(
      selectedCity: event.city,
    ));
  }

  Future<void> _onSaveSelectedCity(
      SaveSelectedCity event, Emitter<GuideCityState> emit) async {
    try {
      emit(state.copyWith(isLoading: true));
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && state.selectedCity != null) {
        await FirebaseFirestore.instance
            .collection('guides')
            .doc(user.uid)
            .update({
          'city': state.selectedCity,
        });

        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Şehir kaydedilirken bir hata oluştu: $e',
        isLoading: false,
      ));
    }
  }

  Future<void> _onLoadSelectedCity(
      LoadSelectedCity event, Emitter<GuideCityState> emit) async {
    try {
      emit(state.copyWith(isLoading: true));
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('guides')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data()?['city'] != null) {
          final cityData = doc.data()!['city'];
          // Eğer city bir String ise, mevcut şehirler listesinden bul
          if (cityData is String) {
            final selectedCity = state.cities.firstWhere(
              (city) => city['name'] == cityData,
              orElse: () => {},
            );
            if (selectedCity.isNotEmpty) {
              emit(state.copyWith(
                selectedCity: selectedCity,
                isLoading: false,
              ));
            }
          } else if (cityData is Map<String, dynamic>) {
            // Districts listesini String listesine dönüştür
            final Map<String, dynamic> updatedCityData = Map.from(cityData);
            if (updatedCityData['districts'] != null) {
              final List<dynamic> districtsList = updatedCityData['districts'];
              final List<String> stringDistricts = districtsList
                  .map((district) {
                    if (district is Map<String, dynamic>) {
                      return district['name']?.toString() ?? '';
                    }
                    return district.toString();
                  })
                  .where((district) => district.isNotEmpty)
                  .toList();

              updatedCityData['districts'] = stringDistricts;
            }

            emit(state.copyWith(
              selectedCity: updatedCityData,
              isLoading: false,
            ));
          }
        } else {
          emit(state.copyWith(isLoading: false));
        }
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Seçili şehir yüklenirken bir hata oluştu: $e',
        isLoading: false,
      ));
    }
  }
}
