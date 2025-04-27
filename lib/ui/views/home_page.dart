import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yerel_rehber_app/colors.dart'; // Renkleriniz
import 'package:yerel_rehber_app/data/entity/restaurant.dart'; // Restaurant modeliniz
import 'package:yerel_rehber_app/data/entity/hotel.dart'; // Hotel modeliniz
import 'package:yerel_rehber_app/ui/cubit/home_page_hotels_cubit.dart'; // Hotel Cubit
import 'package:yerel_rehber_app/ui/cubit/home_page_restaurant.dart'; // Restaurant Cubit
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yerel_rehber_app/ui/views/hotel_detail_page.dart'; // Hotel Detay Sayfası
import 'package:yerel_rehber_app/ui/views/restaurant_detail_page.dart';
import '../../data/entity/photo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  final TextEditingController _cityController = TextEditingController();
  String selectedCity = "İstanbul";

  final String googleApiKey =
      dotenv.env['GOOGLE_API_KEY'] ?? 'API_KEY_BULUNAMADI';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final hotelsCubit = context.read<HomePageHotelsCubit>();
    final restaurantsCubit = context.read<RestaurantCubit>();
    // Eğer zaten yükleniyorsa tekrar tetikleme
    if (hotelsCubit.state is HotelLoading ||
        restaurantsCubit.state is RestaurantLoading) {
      return;
    }
    try {
      await Future.wait([
        hotelsCubit.fetchHotels(selectedCity),
        restaurantsCubit.fetchRestaurants(selectedCity),
      ]);
    } catch (e) {
      print("Veri yükleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Veriler yüklenirken hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _updateCity(String city) async {
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty || trimmedCity == selectedCity || !mounted) return;
    final hotelsCubit = context.read<HomePageHotelsCubit>();
    final restaurantsCubit = context.read<RestaurantCubit>();
    // Eğer zaten yükleniyorsa tekrar tetikleme
    if (hotelsCubit.state is HotelLoading ||
        restaurantsCubit.state is RestaurantLoading) {
      return;
    }
    setState(() {
      selectedCity = trimmedCity;
      _cityController.clear();
    });
    FocusScope.of(context).unfocus();
    try {
      await Future.wait([
        hotelsCubit.fetchHotels(trimmedCity),
        restaurantsCubit.fetchRestaurants(trimmedCity),
      ]);
    } catch (e) {
      print("Şehir güncelleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Veriler güncellenirken hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (googleApiKey == "YOUR_GOOGLE_API_KEY" || googleApiKey.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "HATA:\nGoogle API Anahtarı yapılandırılmamış.\nLütfen kodu kontrol edin.",
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // --- Üst Kısım ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Nereye Gitmek İstersin?",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_none_rounded),
                          color: mainColor,
                          tooltip: "Bildirimler",
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _cityController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Şehir adı girin...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon:
                              Icon(Icons.search_rounded, color: mainColor),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.arrow_forward_ios_rounded,
                                color: mainColor, size: 18),
                            tooltip: "Ara",
                            onPressed: () => _updateCity(_cityController.text),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 15.0),
                        ),
                        onSubmitted: _updateCity,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_pin, color: mainColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            selectedCity,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: mainColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Oteller Bölümü ---
            _buildSectionHeader("Popüler Oteller"),
            BlocBuilder<HomePageHotelsCubit, HotelState>(
              builder: (context, state) {
                bool isLoading = state is HotelLoading;
                return SliverToBoxAdapter(
                  key: ValueKey(
                      'hotels-section-$selectedCity-${isLoading ? 'loading' : 'loaded'}'),
                  child: _buildHorizontalList<Hotel>(
                    context: context,
                    isLoading: isLoading,
                    error: state is HotelError ? state.message : null,
                    data: state is HotelLoaded ? state.hotels : [],
                    itemBuilder: (context, hotel) =>
                        _buildHotelCard(context, hotel),
                    emptyListText: 'Bu şehirde otel bulunamadı.',
                  ),
                );
              },
            ),

            // --- Restoranlar Bölümü ---
            _buildSectionHeader("Lezzet Durakları"),
            BlocBuilder<RestaurantCubit, RestaurantState>(
              builder: (context, state) {
                bool isLoading = state is RestaurantLoading;
                List<Restaurant> restaurants = [];
                if (state is RestaurantLoaded) {
                  restaurants = state.restaurants;
                }
                return SliverToBoxAdapter(
                  key: ValueKey(
                      'restaurants-section-$selectedCity-${isLoading ? 'loading' : 'loaded'}'),
                  child: _buildHorizontalList<Restaurant>(
                    context: context,
                    isLoading: isLoading,
                    error: state is RestaurantError ? state.message : null,
                    data: restaurants,
                    itemBuilder: (context, restaurant) =>
                        _buildRestaurantCard(context, restaurant),
                    emptyListText: 'Bu şehirde restoran bulunamadı.',
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  // --- Yardımcı Widget Fonksiyonları ---

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: mainColor.withOpacity(0.9),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalList<T>({
    required BuildContext context,
    required bool isLoading,
    required String? error,
    required List<T> data,
    required Widget Function(BuildContext, T) itemBuilder,
    required String emptyListText,
  }) {
    const double listHeight = 290;
    const double cacheExtentValue = 600;

    if (isLoading) {
      return SizedBox(
        height: listHeight,
        child: Center(child: CircularProgressIndicator(color: mainColor)),
      );
    }
    if (error != null) {
      return _buildErrorOrEmptyListContainer(listHeight, 'Hata: $error', true);
    }
    if (data.isEmpty) {
      return _buildErrorOrEmptyListContainer(listHeight, emptyListText, false);
    }

    return SizedBox(
      height: listHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        cacheExtent: cacheExtentValue,
        itemCount: data.length,
        padding: const EdgeInsets.only(left: 16.0, right: 0),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: itemBuilder(context, data[index]),
          );
        },
      ),
    );
  }

  Widget _buildErrorOrEmptyListContainer(
      double height, String message, bool isError) {
    return Container(
      height: height,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isError
              ? Colors.red.withOpacity(0.05)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isError
                  ? Colors.red.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2))),
      child: Text(
        message,
        style: TextStyle(color: isError ? Colors.red[700] : Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHotelCard(BuildContext context, Hotel hotel) {
    return SizedBox(
      width: 230,
      child: Card(
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.08),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HotelDetailPage(hotel: hotel),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: _buildPlaceImage(
                  photos: hotel.photos,
                  photoUrl: null, // Otel modelinde photoUrl yok varsayımı
                  fallbackIcon: Icons.hotel_rounded,
                  apiKey: googleApiKey,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hotel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hotel.rating != null) ...[
                          Icon(Icons.star_rounded,
                              color: Colors.amber[700], size: 18),
                          const SizedBox(width: 4),
                          Text(hotel.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey[800])),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                            child: Text(hotel.vicinity ?? hotel.address ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (hotel.priceLevel != null && hotel.priceLevel! > 0)
                      Text('Fiyat: ${'₺' * hotel.priceLevel!}',
                          style: TextStyle(
                              color: mainColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(BuildContext context, Restaurant restaurant) {
    return SizedBox(
      width: 230,
      child: Card(
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.08),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            print("Restoran tıklandı: ${restaurant.name}");
            // TODO: RestaurantDetailPage'e yönlendirme ekle
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    RestaurantDetailPage(restaurant: restaurant),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: _buildPlaceImage(
                  photos: restaurant.photos,
                  photoUrl: restaurant.photoUrl,
                  fallbackIcon: Icons.restaurant_menu_rounded,
                  apiKey: googleApiKey,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (restaurant.rating != null) ...[
                          Icon(Icons.star_rounded,
                              color: Colors.amber[700], size: 18),
                          const SizedBox(width: 4),
                          Text(restaurant.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey[800])),
                          if (restaurant.userRatingsTotal != null &&
                              restaurant.userRatingsTotal! > 0)
                            Text(' (${restaurant.userRatingsTotal})',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600])),
                          const SizedBox(width: 8),
                        ],
                        if (restaurant.openNow != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: restaurant.openNow!
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(restaurant.openNow! ? 'Açık' : 'Kapalı',
                                style: TextStyle(
                                    color: restaurant.openNow!
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                        if (restaurant.rating == null &&
                            restaurant.openNow != null)
                          const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (restaurant.address != null &&
                        restaurant.address!.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 5),
                          Expanded(
                              child: Text(restaurant.address!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                      height: 1.3))),
                        ],
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceImage({
    required List<dynamic>? photos,
    required String? photoUrl,
    required IconData fallbackIcon,
    required String apiKey,
    double height = 160,
  }) {
    String? imageUrlToLoad;
    bool useGooglePhotoApi = false;

    if (photos != null && photos.isNotEmpty) {
      final firstPhoto = photos[0];
      String? photoReference;
      if (firstPhoto is Photo) {
        photoReference = firstPhoto.photoReference;
      } else if (firstPhoto is Map &&
          firstPhoto.containsKey('photo_reference')) {
        photoReference = firstPhoto['photo_reference'];
      }
      if (photoReference != null) {
        imageUrlToLoad =
            "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=$apiKey";
        useGooglePhotoApi = true;
      }
    }
    if (imageUrlToLoad == null && photoUrl != null && photoUrl.isNotEmpty) {
      imageUrlToLoad = photoUrl;
      useGooglePhotoApi = false;
    }

    if (imageUrlToLoad != null) {
      const int cacheWidth = 400;

      return CachedNetworkImage(
        imageUrl: imageUrlToLoad,
        memCacheWidth: cacheWidth,
        fit: BoxFit.cover,
        height: height,
        width: double.infinity,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) => Container(
            color: Colors.grey[200], height: height, width: double.infinity),
        errorWidget: (context, url, error) {
          print("Resim yükleme hatası ($fallbackIcon): $url, $error");
          return Container(
              color: Colors.grey[200],
              height: height,
              width: double.infinity,
              child: Icon(fallbackIcon, size: 48, color: Colors.grey[400]));
        },
      );
    } else {
      return Container(
          height: height,
          width: double.infinity,
          color: Colors.grey[200],
          child: Icon(fallbackIcon, size: 48, color: Colors.grey[400]));
    }
  }

  String _formatTypes(List<String>? types) {
    if (types == null || types.isEmpty) return '-';
    List<String> relevantTypes = types
        .where((t) => t != 'point_of_interest' && t != 'establishment')
        .toList();
    if (relevantTypes.isEmpty) relevantTypes = types;
    return relevantTypes
        .map((type) {
          String formatted = type.replaceAll('_', ' ');
          return formatted[0].toUpperCase() + formatted.substring(1);
        })
        .take(2)
        .join(', ');
  }
}
