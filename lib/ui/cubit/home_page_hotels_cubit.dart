import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yerel_rehber_app/data/repo/public_repo.dart';

import '../../data/entity/hotel.dart';

abstract class HotelState {}

class HotelInitial extends HotelState {}

class HotelLoading extends HotelState {}

class HotelLoaded extends HotelState {
  final List<Hotel> hotels;
  HotelLoaded(this.hotels);
}

class HotelError extends HotelState {
  final String message;
  HotelError(this.message);
}

class HomePageHotelsCubit extends Cubit<HotelState> {
  final TravelRepository repository;

  HomePageHotelsCubit(this.repository) : super(HotelInitial());

  Future<void> fetchHotels(String city) async {
    try {
      emit(HotelLoading());
      final hotels = await repository.fetchHotels(city);
      emit(HotelLoaded(hotels));
    } catch (e) {
      emit(HotelError('Oteller yüklenemedi: $e'));
    }
  }
}
