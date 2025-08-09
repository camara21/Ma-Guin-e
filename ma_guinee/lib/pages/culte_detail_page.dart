import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class CulteDetailPage extends StatelessWidget {
  final Map<String, dynamic> lieu;
  const CulteDetailPage({super.key, required this.lieu});

  void _ouvrirDansGoogleMaps(double lat, double lng) async {
    final Uri uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Impossible d’ouvrir Google Maps");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nom = lieu['nom'] ?? 'Lieu de culte';
    final String ville = lieu['ville'] ?? 'Ville inconnue';

    final List<String> images = (lieu['images'] is List && (lieu['images'] as List).isNotEmpty)
        ? List<String>.from(lieu['images'])
        : (lieu['photo_url'] != null && lieu['photo_url'].toString().isNotEmpty)
            ? [lieu['photo_url'].toString()]
            : [];

    final double latitude = (lieu['latitude'] ?? 0).toDouble();
    final double longitude = (lieu['longitude'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        title: Text(
          nom,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF113CFC),
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (images.isNotEmpty)
                  _ImagesCarouselWithThumbs(images: images)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.place, size: 70, color: Colors.grey),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                Text(
                  ville,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),

                const SizedBox(height: 20),
                const Text(
                  "Localisation :",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 7, offset: Offset(0, 2)),
                    ],
                  ),
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      center: LatLng(latitude, longitude),
                      zoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.example.ma_guinee',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(latitude, longitude),
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.location_on,
                                color: Color(0xFF009460), size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _ouvrirDansGoogleMaps(latitude, longitude),
                    icon: const Icon(Icons.map),
                    label: const Text("Ouvrir dans Google Maps"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF113CFC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// --------- Carousel avec miniatures + compteur ---------
class _ImagesCarouselWithThumbs extends StatefulWidget {
  final List<String> images;
  const _ImagesCarouselWithThumbs({required this.images});

  @override
  State<_ImagesCarouselWithThumbs> createState() => _ImagesCarouselWithThumbsState();
}

class _ImagesCarouselWithThumbsState extends State<_ImagesCarouselWithThumbs> {
  final PageController _pageCtrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image principale + compteur
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: widget.images.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (_, i) => Image.network(
                    widget.images[i],
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ),
              // Compteur en haut à droite
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_current + 1}/$total',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Miniatures
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final selected = i == _current;
              return GestureDetector(
                onTap: () {
                  _pageCtrl.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? const Color(0xFF113CFC) : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      if (selected)
                        BoxShadow(
                          color: const Color(0xFF113CFC).withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    widget.images[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
