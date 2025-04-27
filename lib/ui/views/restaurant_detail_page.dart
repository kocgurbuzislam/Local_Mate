import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yerel_rehber_app/colors.dart';
import 'package:yerel_rehber_app/data/entity/restaurant.dart';

class RestaurantDetailPage extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailPage({super.key, required this.restaurant});

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  GoogleMapController? _mapController;

  final String googleApiKey =
      dotenv.env['GOOGLE_API_KEY'] ?? 'API_KEY_BULUNAMADI';

  @override
  void dispose() {
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // --- URL/Harita Açma Fonksiyonları ---
  Future<void> _openInGoogleMaps() async {
    final lat = widget.restaurant.location?.lat;
    final lng = widget.restaurant.location?.lng;
    final placeId = widget.restaurant.placeId;

    if (lat != null && lng != null) {
      final query = Uri.encodeComponent('$lat,$lng');
      final urlString = placeId.isNotEmpty
          ? 'https://www.google.com/maps/search/?api=1&query=$query&query_place_id=$placeId'
          : 'https://www.google.com/maps/search/?api=1&query=$query';
      final googleUrl = Uri.parse(urlString);

      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Harita uygulaması açılamadı.');
      }
    } else {
      _showErrorSnackBar('Konum bilgisi bulunamadı.');
    }
  }

  // Genel URL açma
  Future<void> _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      _showErrorSnackBar('Geçerli bir URL bulunamadı.');
      return;
    }
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'http://$urlString';
    }
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('URL açılamadı: $urlString');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- Bitiş: URL/Harita Açma Fonksiyonları ---

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // API Anahtarı kontrolü
    if (googleApiKey == "YOUR_GOOGLE_API_KEY" || googleApiKey.isEmpty) {
      return const Scaffold(
          body: Center(
              child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("HATA:\nGoogle API Anahtarı yapılandırılmamış.",
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      textAlign: TextAlign.center))));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- Fotoğraf Galerisi ve App Bar ---
          SliverAppBar(
            expandedHeight: 350,
            // Genişletilmiş yükseklik
            pinned: true,
            stretch: true,
            backgroundColor: Colors.white,
            elevation: 1,
            foregroundColor: mainColor,
            surfaceTintColor: Colors.white,
            leading: _buildAppBarButton(
                Icons.arrow_back, () => Navigator.pop(context)),
            actions: const [
              SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.fadeTitle
              ],
              background:
                  _buildPhotoHeader(), // Fotoğraf galerisi veya tek resim
            ),
          ),

          // --- Ana Bilgi Bloğu ---
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.restaurant.name,
                      style: textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // Puan, Değerlendirme Sayısı ve Açık/Kapalı Durumu
                  _buildRatingStatusRow(textTheme),
                  const SizedBox(height: 12),

                  // Türler (Chips)
                  _buildTypeChips(),
                  const SizedBox(height: 16),

                  // Adres
                  _buildInfoRow(context,
                      icon: Icons.location_on_outlined,
                      text: widget.restaurant.address ?? 'Adres bilgisi yok',
                      isTappable: false),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // --- Bölüm Ayracı ---
          const SliverToBoxAdapter(
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
            ),
          ),

          // --- İletişim Bilgileri Bölümü ---
          _buildSectionSliver(
            context: context,
            title: 'İletişim',
            isVisible: widget.restaurant.website != null ||
                widget.restaurant.phoneNumber != null ||
                widget.restaurant.internationalPhoneNumber != null,
            children: [
              if (widget.restaurant.website != null)
                _buildInfoRow(context,
                    icon: Icons.language_outlined,
                    text: widget.restaurant.website!,
                    onTap: () => _launchURL(widget.restaurant.website)),
              if (widget.restaurant.phoneNumber != null)
                _buildInfoRow(context,
                    icon: Icons.phone_outlined,
                    text: widget.restaurant.phoneNumber!,
                    detailText: "(Yerel)",
                    onTap: () => _makePhoneCall(widget.restaurant.phoneNumber)),
              if (widget.restaurant.internationalPhoneNumber != null)
                _buildInfoRow(context,
                    icon: Icons.phone_forwarded_outlined,
                    text: widget.restaurant.internationalPhoneNumber!,
                    detailText: "(Uluslararası)",
                    onTap: () => _makePhoneCall(
                        widget.restaurant.internationalPhoneNumber)),
            ],
          ),

          // --- Bölüm Ayracı ---
          const SliverToBoxAdapter(
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
            ),
          ),

          // --- Çalışma Saatleri Bölümü ---
          _buildSectionSliver(
            context: context,
            title: 'Çalışma Saatleri',
            isVisible: widget.restaurant.openingHours != null,
            children: _buildOpeningHoursWidgets(context),
          ),

          // --- Konum Haritası Bölümü ---
          _buildSectionSliver(
            context: context,
            title: 'Konum',
            isVisible: widget.restaurant.location?.lat != null &&
                widget.restaurant.location?.lng != null,
            children: [_buildGoogleMap()],
          ),

          // --- Diğer Bilgiler Bölümü ---
          _buildSectionSliver(
            context: context,
            title: 'Diğer Bilgiler',
            isVisible: widget.restaurant.url != null ||
                widget.restaurant.utcOffset != null,
            children: [
              if (widget.restaurant.url != null)
                _buildInfoRow(context,
                    icon: Icons.link_outlined,
                    text: "Google Haritalar'da Görüntüle",
                    onTap: () => _launchURL(widget.restaurant.url)),
              if (widget.restaurant.utcOffset != null)
                _buildInfoRow(context,
                    icon: Icons.access_time_outlined,
                    text: _formatUtcOffset(widget.restaurant.utcOffset!),
                    detailText: "(Saat Dilimi)",
                    isTappable: false),
            ],
          ),

          // --- Değerlendirmeler Bölümü ---
          if (widget.restaurant.reviews != null &&
              widget.restaurant.reviews!.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
              sliver: SliverToBoxAdapter(
                child: Text(
                    'Değerlendirmeler (${widget.restaurant.reviews!.length})',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            SliverPadding(
              padding:
                  const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) => _buildReviewCard(
                        context, widget.restaurant.reviews![index]),
                    childCount: widget.restaurant.reviews!.length),
              ),
            ),
          ],

          // Sayfa sonuna boşluk
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),

      // Alt Buton
      bottomNavigationBar: _buildBottomActionButton(context),
    );
  }

  // --- Yardımcı Widget'lar ---

  Widget _buildAppBarButton(IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // Fotoğraf Galerisi veya Tek Fotoğraf Widget'ı
  Widget _buildPhotoHeader() {
    final photos = widget.restaurant.photos;
    final photoUrl = widget.restaurant.photoUrl;

    // 1. Photos listesi varsa PageView kullan
    if (photos != null && photos.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: photos.length,
            controller: _pageController,
            pageSnapping: true,
            physics: const PageScrollPhysics(),
            onPageChanged: (index) => setState(() {
              _currentPhotoIndex = index;
            }),
            itemBuilder: (context, index) {
              final photo = photos[index];
              // Fotoğraf referansını kullanarak Google Places Photo API URL'si oluştur
              final imageUrl =
                  "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${photo.photoReference}&key=$googleApiKey";
              return CachedNetworkImage(
                imageUrl: imageUrl,
                memCacheWidth: 800,
                // Detay sayfası için daha büyük önbellek
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: const Duration(milliseconds: 300),
                cacheKey: photo.photoReference,
                // Referansı anahtar olarak kullan
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => _buildFallbackImage(),
              );
            },
          ),
          // Fotoğraf Göstergesi
          if (photos.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentPhotoIndex == i ? 12 : 8,
                    height: _currentPhotoIndex == i ? 12 : 8,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPhotoIndex == i
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                        border:
                            Border.all(color: Colors.black.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 3,
                              offset: const Offset(0, 1))
                        ]),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    // 2. Photos listesi yoksa, ama photoUrl varsa onu kullan
    else if (photoUrl != null && photoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photoUrl,
        memCacheWidth: 800,
        // Tek resim için de önbellek boyutu
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => _buildFallbackImage(),
      );
    }
    // 3. Hiç resim yoksa fallback göster
    else {
      return _buildFallbackImage();
    }
  }

  // Resim yoksa veya yüklenemezse gösterilecek yer tutucu
  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey[300],
      child: Center(
          child: Icon(Icons.restaurant_menu_rounded,
              size: 100, color: Colors.grey[600])),
    );
  }

  // Puan, Değerlendirme Sayısı ve Açık/Kapalı Durumu Satırı
  Widget _buildRatingStatusRow(TextTheme textTheme) {
    final rating = widget.restaurant.rating;
    final totalReviews = widget.restaurant.userRatingsTotal;
    final isOpen = widget.restaurant.openNow;

    return Wrap(
      // Farklı bilgileri yan yana sığdırmak için Wrap
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12.0, // Öğeler arası yatay boşluk
      runSpacing: 8.0, // Satır atlanırsa dikey boşluk
      children: [
        // Puan ve Değerlendirme
        if (rating != null)
          Row(
            mainAxisSize: MainAxisSize.min, // İçeriğe göre boyutlan
            children: [
              Icon(Icons.star_rounded, color: Colors.amber[600], size: 22),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1),
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              if (totalReviews != null && totalReviews > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 5.0),
                  child: Text('($totalReviews)',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[700])),
                ),
            ],
          ),

        // Açık/Kapalı Durumu
        if (isOpen != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: isOpen
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOpen
                      ? Icons.check_circle_outline
                      : Icons.highlight_off_outlined,
                  color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  isOpen ? 'Şu an Açık' : 'Şu an Kapalı',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Türler (Chips)
  Widget _buildTypeChips() {
    final types = widget.restaurant.types;
    if (types == null || types.isEmpty) return const SizedBox.shrink();

    // İstenmeyen türleri filtrele
    List<String> relevantTypes = types
        .where((t) =>
            t != 'point_of_interest' && t != 'establishment' && t != 'food')
        .toList();
    // Eğer filtre sonucu hepsi gittiyse veya çok az kaldıysa, 'food'u geri ekle
    if (relevantTypes.isEmpty && types.contains('food')) {
      relevantTypes = ['food'];
    } else if (relevantTypes.isEmpty && types.isNotEmpty) {
      relevantTypes = [types.first]; // En azından ilkini al
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: relevantTypes.map((type) {
        String formattedType = type.replaceAll('_', ' ');
        formattedType =
            formattedType[0].toUpperCase() + formattedType.substring(1);
        return Chip(
          label: Text(formattedType),
          labelStyle: TextStyle(fontSize: 12, color: Colors.grey[800]),
          backgroundColor: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          visualDensity: VisualDensity.compact,
          side: BorderSide.none,
        );
      }).toList(),
    );
  }

  // Genel Bilgi Satırı
  Widget _buildInfoRow(BuildContext context,
      {required IconData icon,
      required String text,
      String? detailText,
      VoidCallback? onTap,
      bool isTappable = true}) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: mainColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.4)),
              if (detailText != null) ...[
                const SizedBox(height: 2),
                Text(detailText,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]))
              ]
            ],
          )),
          if (onTap != null && isTappable) ...[
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400])
          ]
        ],
      ),
    );
    return (onTap != null && isTappable)
        ? Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(4),
                child: content))
        : content;
  }

  // Bölüm Başlığı ve İçeriği İçin Sliver
  Widget _buildSectionSliver(
      {required BuildContext context,
      required String title,
      bool isVisible = true,
      required List<Widget> children}) {
    if (!isVisible || children.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 10.0),
          sliver: SliverToBoxAdapter(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold))),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverList(delegate: SliverChildListDelegate.fixed(children)),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        // Yorum bölümü olmadığı için ayraç her zaman eklenebilir (Konum'dan sonra)
        // if (!isLastSection)
        const SliverToBoxAdapter(
            child: Divider(height: 1, thickness: 1, indent: 16, endIndent: 16)),
      ],
    );
  }

  // Google Harita Widget'ı
  Widget _buildGoogleMap() {
    final lat = widget.restaurant.location?.lat;
    final lng = widget.restaurant.location?.lng;
    if (lat == null || lng == null) return const SizedBox.shrink();

    final latLng = LatLng(lat, lng);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: _openInGoogleMaps,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: AbsorbPointer(
              absorbing: true,
              child: Stack(
                children: [
                  GoogleMap(
                      initialCameraPosition:
                          CameraPosition(target: latLng, zoom: 15.5),
                      markers: {
                        Marker(
                            markerId: MarkerId(widget.restaurant.placeId),
                            position: latLng,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed))
                      },
                      // Restoran için kırmızı marker
                      liteModeEnabled: true,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1))
                            ]),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.map_outlined, size: 16, color: mainColor),
                          const SizedBox(width: 6),
                          Text('Haritada Göster',
                              style: TextStyle(
                                  color: mainColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500))
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Alt Aksiyon Butonu (Yol Tarifi)
  Widget? _buildBottomActionButton(BuildContext context) {
    // Konum varsa Yol Tarifi butonu gösterelim
    final lat = widget.restaurant.location?.lat;
    final lng = widget.restaurant.location?.lng;
    if (lat == null || lng == null) return null; // Konum yoksa buton gösterme

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          label: const Text('Yol Tarifi Al'),
          onPressed: _openInGoogleMaps, // Haritada açma fonksiyonunu kullan
          style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              elevation: 2),
        ),
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, dynamic reviewData) {
    if (reviewData is! Map<String, dynamic>) return const SizedBox.shrink();
    final Map<String, dynamic> review = reviewData;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                    image: review['profile_photo_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(review['profile_photo_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: review['profile_photo_url'] == null
                      ? Icon(Icons.person_outline_rounded,
                          color: Colors.grey[400], size: 24)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review['author_name'] ?? 'Bilinmeyen Kullanıcı',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    color: Colors.amber[600], size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  (review['rating'] ?? 0).toString(),
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (review['relative_time_description'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          review['relative_time_description'],
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (review['text'] != null && review['text'].isNotEmpty)
              Text(
                review['text'],
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              )
            else
              Text(
                'Değerlendirme metni yok.',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatUtcOffset(int offsetMinutes) {
    final duration = Duration(minutes: offsetMinutes);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final sign = hours >= 0 ? '+' : '';
    final formattedHours = hours.abs().toString().padLeft(2, '0');
    final formattedMinutes = minutes.abs().toString().padLeft(2, '0');
    return 'UTC $sign$formattedHours:$formattedMinutes';
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showErrorSnackBar('Telefon numarası bulunamadı.');
      return;
    }
    final Uri launchUri =
        Uri(scheme: 'tel', path: phoneNumber.replaceAll(RegExp(r'\s+'), ''));
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showErrorSnackBar('Arama yapılamadı: $phoneNumber');
    }
  }

  List<Widget> _buildOpeningHoursWidgets(BuildContext context) {
    if (widget.restaurant.openingHours == null) return [];
    List<Widget> widgets = [];
    final openingHours = widget.restaurant.openingHours!;

    if (openingHours['open_now'] != null) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
        child: Row(
          children: [
            Icon(
              openingHours['open_now']
                  ? Icons.check_circle_outline
                  : Icons.highlight_off_outlined,
              color: openingHours['open_now']
                  ? Colors.green[700]
                  : Colors.red[700],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              openingHours['open_now'] ? 'Şu an Açık' : 'Şu an Kapalı',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: openingHours['open_now']
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
            ),
          ],
        ),
      ));
    }

    if (openingHours['weekday_text'] != null &&
        (openingHours['weekday_text'] as List).isNotEmpty) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 8));
      }
      widgets
          .addAll((openingHours['weekday_text'] as List).map((day) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0),
                child: Text(
                  day,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[700]),
                ),
              )));
    }

    return widgets;
  }
}
