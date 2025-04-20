import 'package:equatable/equatable.dart';

class GuideCityState extends Equatable {
  final List<Map<String, dynamic>> cities;
  final List<Map<String, dynamic>> filteredCities;
  final Map<String, dynamic>? selectedCity;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const GuideCityState({
    this.cities = const [],
    this.filteredCities = const [],
    this.selectedCity,
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  GuideCityState copyWith({
    List<Map<String, dynamic>>? cities,
    List<Map<String, dynamic>>? filteredCities,
    Map<String, dynamic>? selectedCity,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return GuideCityState(
      cities: cities ?? this.cities,
      filteredCities: filteredCities ?? this.filteredCities,
      selectedCity: selectedCity ?? this.selectedCity,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props =>
      [cities, filteredCities, selectedCity, isLoading, error, searchQuery];
}
