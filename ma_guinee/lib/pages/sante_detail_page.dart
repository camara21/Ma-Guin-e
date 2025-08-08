import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class SanteDetailPage extends StatefulWidget {
  final dynamic cliniqueId; // accepte int OU String (UUID)
  const SanteDetailPage({super.key, required this.cliniqueId});

  @override
  State<SanteDetailPage> createState() => _SanteDetailPageState();
}

class _SanteDetailPageState extends State<SanteDetailPage> {
  Map<String, dynamic>? clinique;
  bool loading = true;

  // Carrousel
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadClinique();
  }

  Future<void> _loadClinique() async {
    setState(() => loading = true);

    // Laisse l'id dans son type d'origine (int si la colonne est int, String si UUID)
    final data = await Supabase.instance.client
        .from('cliniques')
        .select()
        .eq('id', widget.cliniqueId)
        .maybeSingle();

    setState(() {
      clinique = (data == null) ? null : Map<String, dynamic>.from(data);
      loading = false;
    });
  }

  // -------- Helpers images ----------
  List<String> _imagesFromClinique() {
    final raw = clinique?['images'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    final p = (clinique?['photo_url'] ?? '').toString();
    return p.isNotEmpty ? [p] : [];
  }

  void _openFullScreenGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) {
        final controller = PageController(initialPage: initialIndex);
        int current = initialIndex;
        return StatefulBuilder(
          builder: (context, setS) => Stack(
            children: [
              PhotoViewGallery.builder(
                itemCount: images.length,
                pageController: controller,
                builder: (_, i) => PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(images[i]),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: PhotoViewHeroAttributes(tag: 'clinique_$i'),
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                onPageChanged: (i) => setS(() => current = i),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${current + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  // -----------------------------------

  void _contacterCentre(String numero) async {
    final tel = numero.toString();
    if (tel.isEmpty) return;
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _ouvrirCarte() {
    final lat = (clinique?['latitude'] as num?)?.toDouble();
    final lng = (clinique?['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
      launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coordonnées non disponibles")),
      );
    }
  }

  void _prendreRendezVous() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Prise de rendez-vous'),
        content: const Text("La fonctionnalité sera bientôt disponible."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (clinique == null) {
      return const Scaffold(body: Center(child: Text("Centre de santé introuvable.")));
    }

    // Casts sûrs
    final String nom = (clinique?['nom'] ?? 'Centre médical').toString();
    final String ville = (clinique?['ville'] ?? 'Ville inconnue').toString();
    final String specialites =
        (clinique?['specialites'] ?? clinique?['description'] ?? 'Spécialité non renseignée').toString();
    final List<String> images = _imagesFromClinique();
    final String horaires = (clinique?['horaires'] ??
            "Lundi - Vendredi : 8h à 18h\nSamedi : 8h à 13h\nDimanche : Fermé")
        .toString();
    final String tel = (clinique?['tel'] ?? '').toString();

    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(nom, style: const TextStyle(color: Color(0xFF009460), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF009460)),
        elevation: 1,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // -------- Carrousel + miniatures + compteur --------
              if (images.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: isWide ? 290 : 220,
                        width: double.infinity,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _currentIndex = i),
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () => _openFullScreenGallery(images, index),
                            child: Hero(
                              tag: 'clinique_$index',
                              child: Image.network(
                                images[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${images.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (images.length > 1)
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isActive = index == _currentIndex;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOut,
                            );
                            setState(() => _currentIndex = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isActive ? const Color(0xFF113CFC) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Image.network(
                              images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ] else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 220,
                    color: Colors.grey.shade300,
                    child: const Center(child: Icon(Icons.local_hospital, size: 70, color: Colors.grey)),
                  ),
                ),
              // ---------------------------------------------------

              const SizedBox(height: 22),
              Text(
                nom,
                style: TextStyle(
                  fontSize: isWide ? 30 : 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF113CFC),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.location_city, color: Color(0xFFCE1126)),
                const SizedBox(width: 8),
                Text(ville),
              ]),
              const SizedBox(height: 20),

              const Text("Spécialités :", style: TextStyle(fontWeight: FontWeight.w600)),
              Text(specialites),
              const SizedBox(height: 18),

              const Text("Horaires :", style: TextStyle(fontWeight: FontWeight.w600)),
              Text(horaires),
              const SizedBox(height: 28),

              Row(children: [
                if (tel.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.call),
                      label: const Text("Contacter"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009460),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () => _contacterCentre(tel),
                    ),
                  ),
                if (tel.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: const Text("Rendez-vous"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCE1126),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _prendreRendezVous,
                  ),
                ),
              ]),
              const SizedBox(height: 22),

              ElevatedButton.icon(
                onPressed: _ouvrirCarte,
                icon: const Icon(Icons.map),
                label: const Text("Localiser sur la carte"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFCD116),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
