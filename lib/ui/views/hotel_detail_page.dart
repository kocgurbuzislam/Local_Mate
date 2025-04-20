import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yerel_rehber_app/colors.dart';
import 'package:yerel_rehber_app/data/entity/hotel.dart'; // Hotel modeli
import 'package:yerel_rehber_app/data/entity/photo.dart'; // Photo modeli
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class HotelDetailPage extends StatefulWidget {
  final Hotel hotel;

  const HotelDetailPage({super.key, required this.hotel});

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
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

  // --- URL/Telefon/Harita Açma Fonksiyonları ---
  Future<void> _openInGoogleMaps() async {
    if (widget.hotel.latitude != null && widget.hotel.longitude != null) {
      final query = Uri.encodeComponent(
          '${widget.hotel.latitude},${widget.hotel.longitude}');
      final googleUrl =
          Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Harita uygulaması açılamadı.');
      }
    } else {
      _showErrorSnackBar('Konum bilgisi bulunamadı.');
    }
  }

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

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- Bitiş: URL/Telefon/Harita Açma Fonksiyonları ---

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // API Anahtarı kontrolü
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
      // AppBar yerine CustomScrollView kullanıyoruz
      body: CustomScrollView(
        slivers: [
          // --- Fotoğraf Galerisi ve App Bar ---
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.white,
            elevation: 1,
            foregroundColor: mainColor,
            surfaceTintColor: Colors.white,
            leading: _buildAppBarButton(
                Icons.arrow_back, () => Navigator.pop(context)),
            actions: [],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.fadeTitle,
              ],
              background: _buildPhotoPageView(), // Fotoğraf galerisi
            ),
          ),

          // --- Ana Bilgi Bloğu ---
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.hotel.name,
                      style: textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildRatingAndReviews(textTheme), // Puan ve değerlendirme
                  const SizedBox(height: 12),
                  _buildTypeChips(), // Türler (varsa)
                  const SizedBox(height: 16),
                  _buildInfoRow(context,
                      icon: Icons.location_on_outlined,
                      text: widget.hotel.address ?? 'Adres bilgisi yok',
                      isTappable: false),
                  const SizedBox(height: 12),
                  if (widget.hotel.priceLevel != null &&
                      widget.hotel.priceLevel! > 0) ...[
                    _buildInfoRow(context,
                        icon: Icons.attach_money_outlined,
                        text:
                            'Fiyat Seviyesi: ${'₺' * widget.hotel.priceLevel!}',
                        isTappable: false),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
              child:
                  Divider(height: 1, thickness: 1, indent: 16, endIndent: 16)),

          // --- İletişim Bilgileri Bölümü ---
          _buildSectionSliver(
            context: context,
            title: 'İletişim',
            isVisible: widget.hotel.website != null ||
                widget.hotel.phoneNumber != null ||
                widget.hotel.internationalPhoneNumber != null,
            children: [
              if (widget.hotel.website != null)
                _buildInfoRow(context,
                    icon: Icons.language_outlined,
                    text: widget.hotel.website!,
                    onTap: () => _launchURL(widget.hotel.website)),
              if (widget.hotel.phoneNumber != null)
                _buildInfoRow(context,
                    icon: Icons.phone_outlined,
                    text: widget.hotel.phoneNumber!,
                    detailText: "(Yerel)",
                    onTap: () => _makePhoneCall(widget.hotel.phoneNumber)),
              if (widget.hotel.internationalPhoneNumber != null)
                _buildInfoRow(context,
                    icon: Icons.phone_forwarded_outlined,
                    text: widget.hotel.internationalPhoneNumber!,
                    detailText: "(Uluslararası)",
                    onTap: () =>
                        _makePhoneCall(widget.hotel.internationalPhoneNumber)),
            ],
          ),

          // --- Çalışma Saatleri Bölümü ---
          _buildSectionSliver(
            context: context,
            title: 'Çalışma Saatleri',
            isVisible: widget.hotel.openingHours != null,
            children: _buildOpeningHoursWidgets(context),
          ),

          // --- Konum Haritası Bölümü ---
          _buildSectionSliver(
            context: context,
            title: 'Konum',
            isVisible:
                widget.hotel.latitude != null && widget.hotel.longitude != null,
            children: [_buildGoogleMap()],
          ),

          // --- Diğer Bilgiler Bölümü ---
          _buildSectionSliver(
            context: context,
            title: 'Diğer Bilgiler',
            isVisible: widget.hotel.vicinity != null ||
                widget.hotel.url != null ||
                widget.hotel.utcOffset != null,
            children: [
              if (widget.hotel.vicinity != null &&
                  widget.hotel.vicinity != widget.hotel.address)
                _buildInfoRow(context,
                    icon: Icons.explore_outlined,
                    text: widget.hotel.vicinity!,
                    detailText: "(Çevre)",
                    isTappable: false),
              if (widget.hotel.url != null)
                _buildInfoRow(context,
                    icon: Icons.link_outlined,
                    text: "Google Haritalar'da Görüntüle",
                    onTap: () => _launchURL(widget.hotel.url)),
              if (widget.hotel.utcOffset != null)
                _buildInfoRow(context,
                    icon: Icons.access_time_outlined,
                    text: _formatUtcOffset(widget.hotel.utcOffset!),
                    detailText: "(Saat Dilimi)",
                    isTappable: false),
            ],
          ),

          // --- Değerlendirmeler Bölümü ---
          if (widget.hotel.reviews != null &&
              widget.hotel.reviews!.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
              sliver: SliverToBoxAdapter(
                  child: Text(
                      'Değerlendirmeler (${widget.hotel.reviews!.length})',
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold))),
            ),
            SliverPadding(
              padding:
                  const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) => _buildReviewCard(
                          context, widget.hotel.reviews![index]),
                      childCount: widget.hotel.reviews!.length)),
            ),
          ],
          // Sayfa sonuna boşluk
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),

      bottomNavigationBar: _buildBookingButton(context),
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

  Widget _buildPhotoPageView() {
    if (widget.hotel.photos == null || widget.hotel.photos!.isEmpty) {
      return Container(
          color: Colors.grey[300],
          child: Center(
              child: Icon(Icons.hotel_outlined,
                  size: 100, color: Colors.grey[600])));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.hotel.photos!.length,
          controller: _pageController,
          pageSnapping: true,
          physics: const PageScrollPhysics(),
          onPageChanged: (index) => setState(() {
            _currentPhotoIndex = index;
          }),
          itemBuilder: (context, index) {
            final photo = widget.hotel.photos![index];
            final imageUrl =
                "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${photo.photoReference}&key=$googleApiKey";

            return CachedNetworkImage(
              imageUrl: imageUrl,
              memCacheWidth: 800,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 300),
              fadeOutDuration: const Duration(milliseconds: 300),
              cacheKey: photo.photoReference,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.grey[600], size: 64)),
            );
          },
        ),
        // Fotoğraf Göstergesi
        if (widget.hotel.photos!.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.hotel.photos!.length,
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
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
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

  Widget _buildRatingAndReviews(TextTheme textTheme) {
    bool hasRating = widget.hotel.rating != null;
    bool hasReviews =
        widget.hotel.totalReviews != null && widget.hotel.totalReviews! > 0;
    if (!hasRating && !hasReviews) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasRating) ...[
          Icon(Icons.star_rounded, color: Colors.amber[600], size: 22),
          const SizedBox(width: 4),
          Text(widget.hotel.rating!.toStringAsFixed(1),
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
        ],
        if (hasReviews)
          Text('(${widget.hotel.totalReviews} değerlendirme)',
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey[700]))
        else if (hasRating)
          Text('(Değerlendirme yok)',
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTypeChips() {
    if (widget.hotel.types == null || widget.hotel.types!.isEmpty)
      return const SizedBox.shrink();
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: widget.hotel.types!.map((type) {
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

  Widget _buildSectionSliver(
      {required BuildContext context,
      required String title,
      bool isVisible = true,
      required List<Widget> children}) {
    if (!isVisible || children.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    final bool isLastSection = title == 'Diğer Bilgiler';

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
        SliverToBoxAdapter(child: SizedBox(height: isLastSection ? 0 : 8)),
        if (!isLastSection)
          const SliverToBoxAdapter(
              child:
                  Divider(height: 1, thickness: 1, indent: 16, endIndent: 16)),
      ],
    );
  }

  List<Widget> _buildOpeningHoursWidgets(BuildContext context) {
    if (widget.hotel.openingHours == null) return [];
    List<Widget> widgets = [];
    final openingHours = widget.hotel.openingHours!;
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
                size: 20),
            const SizedBox(width: 8),
            Text(openingHours['open_now'] ? 'Şu an Açık' : 'Şu an Kapalı',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: openingHours['open_now']
                        ? Colors.green[700]
                        : Colors.red[700])),
          ],
        ),
      ));
    }
    if (openingHours['weekday_text'] != null &&
        (openingHours['weekday_text'] as List).isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
      widgets.addAll((openingHours['weekday_text'] as List).map((day) =>
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Text(day,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[700])))));
    }
    return widgets;
  }

  Widget _buildGoogleMap() {
    if (widget.hotel.latitude == null || widget.hotel.longitude == null)
      return const SizedBox.shrink();
    final latLng = LatLng(widget.hotel.latitude!, widget.hotel.longitude!);
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
                            markerId: MarkerId(
                                widget.hotel.placeId ?? widget.hotel.name),
                            position: latLng,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueAzure))
                      },
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

  String _formatUtcOffset(int offsetMinutes) {
    final duration = Duration(minutes: offsetMinutes);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final sign = hours >= 0 ? '+' : '';
    final formattedHours = hours.abs().toString().padLeft(2, '0');
    final formattedMinutes = minutes.abs().toString().padLeft(2, '0');
    return 'UTC $sign$formattedHours:$formattedMinutes';
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

  Widget? _buildBookingButton(BuildContext context) {
    bool canBook =
        widget.hotel.website != null || widget.hotel.phoneNumber != null;
    if (!canBook) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          label: const Text('Rezervasyon Yap'),
          onPressed: () {
            if (widget.hotel.website != null) {
              _launchURL(widget.hotel.website);
            } else if (widget.hotel.phoneNumber != null) {
              _makePhoneCall(widget.hotel.phoneNumber);
            }
          },
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
}
