import 'package:equatable/equatable.dart';

abstract class GuideCityEvent extends Equatable {
  const GuideCityEvent();

  @override
  List<Object?> get props => [];
}

class LoadCities extends GuideCityEvent {}

class SearchCities extends GuideCityEvent {
  final String query;

  const SearchCities(this.query);

  @override
  List<Object?> get props => [query];
}

class SelectCity extends GuideCityEvent {
  final Map<String, dynamic> city;

  const SelectCity(this.city);

  @override
  List<Object?> get props => [city];
}

class SaveSelectedCity extends GuideCityEvent {}

class LoadSelectedCity extends GuideCityEvent {}
