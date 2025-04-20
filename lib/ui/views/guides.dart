import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yerel_rehber_app/colors.dart';
import '../cubit/guide_cubit.dart';
import 'guide_detail_screen.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCity;
  String? _selectedLanguage;
  double? _minRating;

  @override
  void initState() {
    super.initState();
    context.read<GuideCubit>().fetchGuides();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    context.read<GuideCubit>().filterGuides(
          city: _selectedCity,
          language: _selectedLanguage,
          minRating: _minRating,
          searchQuery: _searchController.text,
        );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtreleme Seçenekleri'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Şehir',
                  hintText: 'Şehir adı girin',
                ),
                onChanged: (value) => _selectedCity = value,
              ),
              SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Dil',
                  hintText: 'Dil adı girin',
                ),
                onChanged: (value) => _selectedLanguage = value,
              ),
              SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Minimum Puan',
                  hintText: '0.0 - 5.0 arası',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    _minRating = double.tryParse(value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<GuideCubit>().clearFilters();
              Navigator.pop(context);
            },
            child: const Text('Filtreleri Temizle'),
          ),
          TextButton(
            onPressed: () {
              context.read<GuideCubit>().filterGuides(
                    city: _selectedCity,
                    language: _selectedLanguage,
                    minRating: _minRating,
                  );
              Navigator.pop(context);
            },
            child: const Text('Filtrele'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Rehberler",
          style: TextStyle(
            color: mainColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: mainColor),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: mainColor.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rehber ara...',
                  prefixIcon: Icon(Icons.search, color: mainColor),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<GuideCubit, GuideState>(
              builder: (context, state) {
                if (state is GuideLoading) {
                  return Center(
                    child: CircularProgressIndicator(color: mainColor),
                  );
                } else if (state is GuideError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          "Bir hata oluştu",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.message,
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                } else if (state is GuideLoaded) {
                  if (state.guides.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            "Rehber bulunamadı",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Arama kriterlerinize uygun rehber bulunamadı",
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.guides.length,
                    itemBuilder: (context, index) {
                      final guide = state.guides[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      GuideDetailScreen(
                                    guideData: guide,
                                    guideId: guide['id'] ?? '',
                                  ),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    var begin = const Offset(1.0, 0.0);
                                    var end = Offset.zero;
                                    var curve = Curves.ease;
                                    var tween = Tween(begin: begin, end: end)
                                        .chain(CurveTween(curve: curve));
                                    return SlideTransition(
                                      position: animation.drive(tween),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey[200],
                                      image: guide['photos'] != null &&
                                              guide['photos'].isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                  guide['photos'][0]),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: guide['photos'] == null ||
                                            guide['photos'].isEmpty
                                        ? Icon(Icons.person,
                                            size: 40, color: Colors.grey[400])
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          guide['fullName'] ?? 'İsimsiz Rehber',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: mainColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              guide['cityName'] ??
                                                  'Şehir belirtilmemiş',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.language,
                                              size: 16,
                                              color: mainColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              guide['languages'] != null
                                                  ? '${(guide['languages'] as List).length} dil biliyor'
                                                  : 'Dil bilgisi belirtilmemiş',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color:
                                                    mainColor.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.star,
                                                    size: 16,
                                                    color: mainColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${(guide['rating'] ?? 0.0).toStringAsFixed(1)}',
                                                    style: TextStyle(
                                                      color: mainColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}
