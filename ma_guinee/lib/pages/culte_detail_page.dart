import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class CulteDetailPage extends StatelessWidget {
  final Map<String, dynamic> lieu;
  const CulteDetailPage({super.key, required this.lieu});

  // ---------- Helpers ----------
  String _norm(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    if (s.isEmpty) return '';
    return s
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll('œ', 'oe');
  }

  bool _isMosquee() {
    final s = _norm('${lieu['type']} ${lieu['sous_categorie']} ${lieu['categorie']} ${lieu['description']} ${lieu['nom']}');
    return s.contains('mosquee');
  }

  bool _isEglise() {
    final s = _norm('${lieu['type']} ${lieu['sous_categorie']} ${lieu['categorie']} ${lieu['description']} ${lieu['nom']}');
    return s.contains('eglise') || s.contains('cathedrale');
  }

  void _ouvrirDansGoogleMaps(double lat, double lng) async {
    final Uri uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDonSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Merci ❤️'),
        content: const Text(
          "Très bientôt, vous pourrez faire un don directement depuis l'application.\n\n"
          "Votre générosité aidera ce lieu à continuer ses actions pour la communauté.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ---------- Widget CTA Don ----------
  Widget _donationSection(BuildContext context) {
    final isMosquee = _isMosquee();
    final isEglise  = _isEglise();

    final Color accent   = isMosquee ? const Color(0xFF009460)
                         : isEglise  ? const Color(0xFFCE1126)
                                     : const Color(0xFF113CFC);

    final IconData icon  = isMosquee ? Icons.mosque
                         : isEglise  ? Icons.church
                                     : Icons.handshake;

    final String titre   = isMosquee ? 'Soutenez votre mosquée'
                         : isEglise  ? 'Soutenez votre église'
                                     : 'Soutenir ce lieu';

    final String texte   = isMosquee
        ? "« Fi sabilillah » – pour la cause d’Allah. Même un petit geste peut aider à payer l’eau, l’électricité et l’entretien afin que la mosquée reste ouverte et accueillante."
        : isEglise
            ? "Un geste d’amour pour l’Église : aidez aux charges, à l’accueil des fidèles et aux actions solidaires. Chaque don compte pour faire vivre la communauté."
            : "Aidez ce lieu à continuer de servir la communauté : entretien, charges, accueil… Même une petite contribution a un grand impact.";

    final String btn     = isMosquee ? 'Contribuer (fi sabilillah)'
                         : isEglise  ? 'Faire un don'
                                     : 'Soutenir';

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.10), accent.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withOpacity(0.15),
                foregroundColor: accent,
                child: Icon(icon),
              ),
              const SizedBox(width: 10),
              Text(
                titre,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            texte,
            style: const TextStyle(height: 1.35, fontSize: 14.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showDonSoonDialog(context),
              icon: const Icon(Icons.volunteer_activism),
              label: Text(btn),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nom = (lieu['nom'] ?? 'Lieu de culte').toString();
    final String ville = (lieu['ville'] ?? 'Ville inconnue').toString();

    // images: supporte `images: []` OU `photo_url: "..."`.
    final List<String> images = (lieu['images'] is List && (lieu['images'] as List).isNotEmpty)
        ? List<String>.from(lieu['images'])
        : (lieu['photo_url'] != null && lieu['photo_url'].toString().isNotEmpty)
            ? [lieu['photo_url'].toString()]
            : [];

    // description: supporte `description`, `desc` ou `resume`.
    final String? description =
        (lieu['description'] ?? lieu['desc'] ?? lieu['resume'])?.toString();

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
          overflow: TextOverflow.ellipsis,
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
                  _ImagesCarouselWithThumbs(
                    images: images,
                    onOpenFull: (index) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _FullscreenGalleryPage(
                            images: images,
                            initialIndex: index,
                            heroPrefix: 'culte_$nom',
                          ),
                        ),
                      );
                    },
                    heroPrefix: 'culte_$nom',
                  )
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
                const SizedBox(height: 16),

                // Ville
                Text(
                  ville,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),

                // Description
                if (description != null && description.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    "Description :",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                ],

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
                      interactiveFlags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
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

                // ---- Section Don (juste sous la carte) ----
                _donationSection(context),

                const SizedBox(height: 18),
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
  final void Function(int index)? onOpenFull;
  final String heroPrefix;
  const _ImagesCarouselWithThumbs({
    required this.images,
    this.onOpenFull,
    required this.heroPrefix,
  });

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
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => widget.onOpenFull?.call(i),
                    child: Hero(
                      tag: '${widget.heroPrefix}_$i',
                      child: Image.network(
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
                onLongPress: () => widget.onOpenFull?.call(i),
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

/// --------- Page plein écran (swipe + zoom) ---------
class _FullscreenGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroPrefix;

  const _FullscreenGalleryPage({
    required this.images,
    required this.initialIndex,
    required this.heroPrefix,
  });

  @override
  State<_FullscreenGalleryPage> createState() => _FullscreenGalleryPageState();
}

class _FullscreenGalleryPageState extends State<_FullscreenGalleryPage> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          '${_index + 1}/$total',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _ctrl,
        onPageChanged: (i) => setState(() => _index = i),
        itemCount: widget.images.length,
        itemBuilder: (_, i) {
          final url = widget.images[i];
          return Center(
            child: Hero(
              tag: '${widget.heroPrefix}_$i',
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
