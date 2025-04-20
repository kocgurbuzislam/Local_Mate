import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yerel_rehber_app/data/entity/city.dart';
import 'package:yerel_rehber_app/ui/cubit/city_cubit.dart';
import '../../../colors.dart';
import 'add_route.dart';

class GuideCities extends StatefulWidget {
  final List<Map<String, String>> selectedLanguages;

  const GuideCities({
    Key? key,
    required this.selectedLanguages,
  }) : super(key: key);

  @override
  _GuideCitiesState createState() => _GuideCitiesState();
}

class _GuideCitiesState extends State<GuideCities> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Veri yüklemeyi bir frame sonra yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CityCubit>().loadCities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şehir Seçimi'),
        centerTitle: true,
      ),
      body: BlocBuilder<CityCubit, CityState>(
        builder: (context, state) {
          if (state is CityLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(mainColor),
              ),
            );
          } else if (state is CityError) {
            return Center(child: Text(state.message));
          } else if (state is CityLoaded) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Hero(
                    tag: 'searchBar',
                    child: Material(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          // Arama gecikmesini azalt
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (_searchController.text == value) {
                              context.read<CityCubit>().searchCities(value);
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Şehir ara...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.selectedCity != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Hero(
                      tag: 'selectedCity',
                      child: Card(
                        color: mainColor.withOpacity(0.1),
                        child: ListTile(
                          leading: Icon(Icons.location_city, color: mainColor),
                          title: Text(
                            state.selectedCity!.name,
                            style: TextStyle(
                              color: mainColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            state.selectedCity!.description,
                            style: TextStyle(color: mainColor.withOpacity(0.8)),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.close, color: mainColor),
                            onPressed: () {
                              context
                                  .read<CityCubit>()
                                  .selectCity(state.selectedCity!);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.filteredCities.length,
                    // Liste performansını artır
                    cacheExtent: 100,
                    itemBuilder: (context, index) {
                      final city = state.filteredCities[index];
                      final isSelected = state.selectedCity == city;

                      return Hero(
                        tag: 'city_${city.id}',
                        child: Card(
                          child: ListTile(
                            title: Text(city.name),
                            subtitle: Text(
                              city.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: isSelected
                                  ? Icon(Icons.check_circle, color: mainColor)
                                  : const Icon(Icons.circle_outlined),
                            ),
                            onTap: () {
                              context.read<CityCubit>().selectCity(city);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
          return const SizedBox();
        },
      ),
      bottomNavigationBar: BlocBuilder<CityCubit, CityState>(
        builder: (context, state) {
          if (state is CityLoaded && state.selectedCity != null) {
            return Hero(
              tag: 'bottomButton',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (state.selectedCity != null) {
                      _onCitySelected({
                        'id': state.selectedCity!.id,
                        'name': state.selectedCity!.name,
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Devam Et',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  void _onCitySelected(Map<String, dynamic> city) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRoute(
          cityId: city['id'],
          cityName: city['name'],
          selectedLanguages: widget.selectedLanguages,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
