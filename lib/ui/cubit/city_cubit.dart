import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yerel_rehber_app/data/entity/city.dart';
import 'package:yerel_rehber_app/data/repo/public_repo.dart';

abstract class CityState {}

class CityInitial extends CityState {}

class CityLoading extends CityState {}

class CityLoaded extends CityState {
  final List<City> cities;
  final List<City> filteredCities;
  final City? selectedCity;
  final String searchQuery;

  CityLoaded({
    required this.cities,
    required this.filteredCities,
    this.selectedCity,
    required this.searchQuery,
  });
}

class CityError extends CityState {
  final String message;
  CityError(this.message);
}

class CityCubit extends Cubit<CityState> {
  final TravelRepository _repository;
  City? _selectedCity;
  List<City> _allCities = [];
  String _searchQuery = '';

  CityCubit({required TravelRepository repository})
      : _repository = repository,
        super(CityInitial());

  Future<void> loadCities() async {
    try {
      emit(CityLoading());
      final citiesData = await _repository.fetchCities();
      _allCities = citiesData
          .map((json) => City(
                id: json['id'],
                name: json['name'],
                description: json['description'],
                imageUrl: '',
                rating: json['rating'],
                reviewCount: json['reviewCount'],
                popularPlaces: [],
                region: json['region'],
                weatherInfo: json['weatherInfo'],
                travelInfo: json['travelInfo'],
                foto: json['foto'],
                score: json['rating'],
                starNumber: (json['rating'] * 5 / 5).round(),
              ))
          .toList();
      _emitLoadedState();
    } catch (e) {
      emit(CityError('Şehirler yüklenirken bir hata oluştu: $e'));
    }
  }

  void searchCities(String query) {
    _searchQuery = query.toLowerCase();
    _emitLoadedState();
  }

  void selectCity(City city) {
    if (state is CityLoaded) {
      final currentState = state as CityLoaded;
      final isSelected = currentState.selectedCity?.id == city.id;

      _selectedCity = isSelected ? null : city;
      emit(CityLoaded(
        cities: currentState.cities,
        filteredCities: currentState.filteredCities,
        selectedCity: _selectedCity,
        searchQuery: currentState.searchQuery,
      ));
    }
  }

  void _emitLoadedState() {
    final filteredCities = _allCities.where((city) {
      return city.name.toLowerCase().contains(_searchQuery);
    }).toList();

    emit(CityLoaded(
      cities: _allCities,
      filteredCities: filteredCities,
      selectedCity: _selectedCity,
      searchQuery: _searchQuery,
    ));
  }

  City? getSelectedCity() {
    return _selectedCity;
  }
}
