// lib/pages/sante_detail_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'sante_rdv_page.dart';

/// Palette Santé
const kHealthYellow  = Color(0xFFFCD116);
const kHealthGreen   = Color(0xFF009460);
const kNeutralBorder = Color(0xFFE5E7EB);

class SanteDetailPage extends StatefulWidget {
  /// Identifiant de la clinique (BIGINT en base). Peut être int, num, String, etc.
  final dynamic cliniqueId;
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

    // ✅ Conversion sûre -> int (compatible BIGINT)
    final int? idForQuery = (widget.cliniqueId is num)
        ? (widget.cliniqueId as num).toInt()
        : int.tryParse(widget.cliniqueId.toString());

    if (idForQuery == null) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID de clinique invalide.')),
      );
      return;
    }

    final data = await Supabase.instance.client
        .from('cliniques')
        .select()
        .eq('id', idForQuery)
        .maybeSingle();

    if (!mounted) return;
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
                bottom: 24, left: 0, right: 0,
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
                top: 24, right: 8,
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

  // -------- Actions --------
  Future<void> _contacterCentre(String numero) async {
    final cleaned = numero.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Numéro indisponible.")));
      return;
    }
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _ouvrirCarte() async {
    final lat = (clinique?['latitude'] as num?)?.toDouble();
    final lng = (clinique?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Coordonnées non disponibles.")));
      return;
    }
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _ouvrirRdv() {
    final nom     = (clinique?['nom'] ?? 'Centre médical').toString();
    final tel     = (clinique?['tel'] ?? clinique?['telephone'] ?? '').toString();
    final address = (clinique?['adresse'] ?? clinique?['ville'] ?? '').toString();
    final images  = _imagesFromClinique();

    // ✅ Convertit l’ID en int pour la page RDV
    final int? cliniqueIdInt = (widget.cliniqueId is num)
        ? (widget.cliniqueId as num).toInt()
        : int.tryParse(widget.cliniqueId.toString());

    if (cliniqueIdInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID de clinique invalide.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SanteRdvPage(
          cliniqueId: cliniqueIdInt, // <- IMPORTANT
          cliniqueName: nom.isEmpty ? 'Centre médical' : nom,
          phone: tel.trim().isEmpty ? null : tel.trim(),
          address: address.trim().isEmpty ? null : address.trim(),
          coverImage: images.isNotEmpty ? images.first : null,
          primaryColor: kHealthGreen,
        ),
      ),
    );
  }
  // ------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (clinique == null) {
      return const Scaffold(body: Center(child: Text("Centre de santé introuvable.")));
    }

    // Données
    final String nom = (clinique?['nom'] ?? 'Centre médical').toString();
    final String ville = (clinique?['ville'] ?? 'Ville inconnue').toString();
    final String specialites = (clinique?['specialites'] ??
            clinique?['description'] ??
            'Spécialité non renseignée')
        .toString();
    final List<String> images = _imagesFromClinique();
    final String horaires = (clinique?['horaires'] ??
            "Lundi - Vendredi : 8h – 18h\nSamedi : 8h – 13h\nDimanche : Fermé")
        .toString();
    final String tel = (clinique?['tel'] ?? clinique?['telephone'] ?? '').toString();

    final isWide = MediaQuery.of(context).size.width > 600;

    const bottomGradient = LinearGradient(
      colors: [kHealthGreen, kHealthYellow],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: kHealthGreen),
        title: Text(
          nom,
          style: const TextStyle(color: kHealthGreen, fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: SizedBox(
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: bottomGradient),
            ),
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------- Carrousel + miniatures + compteur --------
                if (images.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        SizedBox(
                          height: isWide ? 300 : 230,
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
                                  color: isActive ? kHealthGreen : Colors.transparent,
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
                      height: 230,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.local_hospital, size: 70, color: Colors.grey),
                      ),
                    ),
                  ),
                // ---------------------------------------------------

                const SizedBox(height: 16),
                Text(
                  nom,
                  style: TextStyle(
                    fontSize: isWide ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: kHealthGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.location_on, color: kHealthYellow, size: 18),
                    SizedBox(width: 6),
                  ],
                ),
                Text(ville),

                const SizedBox(height: 16),
                const Divider(),

                // Spécialités
                const SizedBox(height: 6),
                const Text("Spécialités", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(specialites),

                const SizedBox(height: 16),
                const Text("Horaires", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(horaires),

                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _ouvrirCarte,
                  icon: const Icon(Icons.map),
                  label: const Text("Localiser sur la carte"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kHealthYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // -------- Barre d’actions collée en bas --------
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: tel.trim().isEmpty ? null : () => _contacterCentre(tel),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text("Appeler"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kHealthGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _ouvrirRdv,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text("Rendez-vous"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kHealthYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
