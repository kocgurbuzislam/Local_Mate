import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yerel_rehber_app/data/repo/public_repo.dart';
import '../../data/entity/city.dart';

class HomePageCubit extends Cubit<List<City>> {
  HomePageCubit() : super(<City>[]);

  var prepo = TravelRepository();

  Future<void> citysLoad() async {
    final citiesData = await prepo.fetchCities();
    final cities = citiesData
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
    emit(cities);
  }
}
