import 'package:flutter_bloc/flutter_bloc.dart';

// States
abstract class AllCitiesState {}

class AllCitiesInitial extends AllCitiesState {}

class AllCitiesLoading extends AllCitiesState {}

class AllCitiesLoaded extends AllCitiesState {
  final String? selectedCity;
  final List<String> filteredCities;
  final List<String> allCities;

  AllCitiesLoaded({
    this.selectedCity,
    required this.filteredCities,
    required this.allCities,
  });
}

class AllCitiesError extends AllCitiesState {
  final String message;
  AllCitiesError(this.message);
}

// Cubit
class AllCitiesCubit extends Cubit<AllCitiesState> {
  AllCitiesCubit() : super(AllCitiesInitial()) {
    loadCities();
  }

  final List<String> _allCities = [
    'Adana',
    'Adıyaman',
    'Afyonkarahisar',
    'Ağrı',
    'Amasya',
    'Ankara',
    'Antalya',
    'Artvin',
    'Aydın',
    'Balıkesir',
    'Bilecik',
    'Bingöl',
    'Bitlis',
    'Bolu',
    'Burdur',
    'Bursa',
    'Çanakkale',
    'Çankırı',
    'Çorum',
    'Denizli',
    'Diyarbakır',
    'Edirne',
    'Elazığ',
    'Erzincan',
    'Erzurum',
    'Eskişehir',
    'Gaziantep',
    'Giresun',
    'Gümüşhane',
    'Hakkari',
    'Hatay',
    'Isparta',
    'Mersin',
    'İstanbul',
    'İzmir',
    'Kars',
    'Kastamonu',
    'Kayseri',
    'Kırklareli',
    'Kırşehir',
    'Kocaeli',
    'Konya',
    'Kütahya',
    'Malatya',
    'Manisa',
    'Kahramanmaraş',
    'Mardin',
    'Muğla',
    'Muş',
    'Nevşehir',
    'Niğde',
    'Ordu',
    'Rize',
    'Sakarya',
    'Samsun',
    'Siirt',
    'Sinop',
    'Sivas',
    'Tekirdağ',
    'Tokat',
    'Trabzon',
    'Tunceli',
    'Şanlıurfa',
    'Uşak',
    'Van',
    'Yozgat',
    'Zonguldak',
    'Aksaray',
    'Bayburt',
    'Karaman',
    'Kırıkkale',
    'Batman',
    'Şırnak',
    'Bartın',
    'Ardahan',
    'Iğdır',
    'Yalova',
    'Karabük',
    'Kilis',
    'Osmaniye',
    'Düzce',
  ];

  String? _selectedCity;
  String _searchQuery = '';

  void loadCities() {
    emit(AllCitiesLoading());
    _emitLoadedState();
  }

  void searchCities(String query) {
    _searchQuery = query.toLowerCase();
    _emitLoadedState();
  }

  void selectCity(String city) {
    _selectedCity = city;
    _emitLoadedState();
  }

  void _emitLoadedState() {
    final filteredCities = _allCities.where((city) {
      return city.toLowerCase().contains(_searchQuery);
    }).toList();

    emit(AllCitiesLoaded(
      selectedCity: _selectedCity,
      filteredCities: filteredCities,
      allCities: _allCities,
    ));
  }
}
