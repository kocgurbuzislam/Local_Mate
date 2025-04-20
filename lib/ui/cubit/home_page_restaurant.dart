import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yerel_rehber_app/data/entity/restaurant.dart';
import 'package:yerel_rehber_app/data/repo/public_repo.dart';

abstract class RestaurantState {}

class RestaurantInitial extends RestaurantState {}

class RestaurantLoading extends RestaurantState {}

class RestaurantLoaded extends RestaurantState {
  final List<Restaurant> restaurants;
  RestaurantLoaded(this.restaurants);
}

class RestaurantError extends RestaurantState {
  final String message;
  RestaurantError(this.message);
}

class RestaurantCubit extends Cubit<RestaurantState> {
  final TravelRepository repository;

  RestaurantCubit(this.repository) : super(RestaurantInitial());

  Future<void> fetchRestaurants(String city) async {
    try {
      emit(RestaurantLoading());
      final restaurants = await repository.fetchRestaurants(city);
      emit(RestaurantLoaded(restaurants));
    } catch (e) {
      emit(RestaurantError('Restoranlar yüklenemedi: $e'));
    }
  }
}
