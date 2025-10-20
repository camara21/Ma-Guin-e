// lib/pages/hotel_detail_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'hotel_reservation_page.dart';

class HotelDetailPage extends StatefulWidget {
  final dynamic hotelId; // UUID (String) ou autre -> stringifié
  const HotelDetailPage({super.key, required this.hotelId});

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  final _sb = Supabase.instance.client;

  // ===== Palette Hôtels (spécifique à cette page) =====
  static const Color hotelsPrimary   = Color(0xFF264653);
  static const Color hotelsSecondary = Color(0xFF2A9D8F);
  static const Color onPrimary       = Color(0xFFFFFFFF);
  static const Color neutralBorder   = Color(0xFFE5E7EB);

  Map<String, dynamic>? hotel;
  bool loading = true;
  String? _error;

  // Avis
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  double _noteMoyenne = 0;
  List<Map<String, dynamic>> _avis = [];
  final Map<String, Map<String, dynamic>> _userCache = {};

  // Carrousel
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  String get _id => widget.hotelId.toString();

  bool _isUuid(String id) {
    final r = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return r.hasMatch(id);
  }

  @override
  void initState() {
    super.initState();
    _loadHotel();
    _loadAvisBloc();
  }

  @override
  void dispose() {
    _avisController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ---------------- Hôtel ----------------
  Future<void> _loadHotel() async {
    setState(() {
      loading = true;
      _error = null;
    });
    try {
      final data =
          await _sb.from('hotels').select().eq('id', _id).maybeSingle();
      if (!mounted) return;
      setState(() {
        hotel = data == null ? null : Map<String, dynamic>.from(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _error = e.toString();
      });
    }
  }

  // ---------------- Avis ----------------
  Future<void> _loadAvisBloc() async {
    try {
      final rows = await _sb
          .from('avis_hotels')
          .select('auteur_id, etoiles, commentaire, created_at')
          .eq('hotel_id', _id)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(rows);

      double moyenne = 0.0;
      if (list.isNotEmpty) {
        final notes =
            list.map((e) => (e['etoiles'] as num?)?.toDouble() ?? 0.0).toList();
        final s = notes.fold<double>(0.0, (a, b) => a + b);
        moyenne = s / notes.length;
      }

      final ids = list
          .map((e) => e['auteur_id'])
          .whereType<String>()
          .where(_isUuid)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> fetched = {};
      if (ids.isNotEmpty) {
        final orFilter = ids.map((id) => 'id.eq.$id').join(',');
        final profs = await _sb
            .from('utilisateurs')
            .select('id, nom, prenom, photo_url')
            .or(orFilter);

        for (final p in List<Map<String, dynamic>>.from(profs)) {
          final id = (p['id'] ?? '').toString();
          fetched[id] = {
            'nom': p['nom'],
            'prenom': p['prenom'],
            'photo_url': p['photo_url'],
          };
        }
      }

      if (!mounted) return;
      setState(() {
        _avis = list;
        _noteMoyenne = moyenne;
        _userCache
          ..clear()
          ..addAll(fetched);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement avis: $e')),
      );
    }
  }

  Future<void> _envoyerAvis() async {
    final commentaire = _avisController.text.trim();
    if (_noteUtilisateur == 0 || commentaire.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez donner une note et un avis.")),
      );
      return;
    }

    final user = _sb.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connectez-vous pour laisser un avis.")),
      );
      return;
    }
    if (!_isUuid(_id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID hôtel invalide.")),
      );
      return;
    }

    try {
      await _sb.from('avis_hotels').upsert(
        {
          'hotel_id': _id,
          'auteur_id': user.id,
          'etoiles': _noteUtilisateur,
          'commentaire': commentaire,
        },
        onConflict: 'hotel_id,auteur_id',
      );

      _avisController.clear();
      setState(() => _noteUtilisateur = 0);
      await _loadAvisBloc();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci pour votre avis !")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur envoi avis: $e")),
      );
    }
  }

  // ---------------- Contact / localisation ----------------
  void _contacter() async {
    final tel = (hotel?['telephone'] ?? hotel?['tel'] ?? '').toString().trim();
    if (tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro indisponible.")),
      );
      return;
    }
    final cleaned = tel.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _localiser() async {
    final lat = (hotel?['latitude'] as num?)?.toDouble();
    final lon = (hotel?['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coordonnées indisponibles.")),
      );
      return;
    }
    final uri =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ---------------- UI helpers ----------------
  Widget _buildStars(int rating, {void Function(int)? onTap}) {
    return Row(
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(index < rating ? Icons.star : Icons.star_border,
              color: Colors.amber),
          onPressed: onTap != null ? () => onTap(index + 1) : null,
          iconSize: 28,
          splashRadius: 20,
        );
      }),
    );
  }

  Widget _buildAvisList() {
    if (_avis.isEmpty) return const Text("Pas encore d'avis");

    return Column(
      children: _avis.map((avis) {
        final uid = (avis['auteur_id'] ?? '').toString();
        // >>> correction de typage ici
        final Map<String, dynamic> u =
            _userCache[uid] ?? const <String, dynamic>{};
        final nom =
            "${(u['prenom'] ?? '').toString()} ${(u['nom'] ?? '').toString()}".trim();
        final note = (avis['etoiles'] as num?)?.toInt() ?? 0;
        final commentaire = (avis['commentaire'] ?? '').toString();
        final photo = (u['photo_url'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: neutralBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom.isEmpty ? 'Utilisateur' : nom,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(i < note ? Icons.star : Icons.star_border,
                              size: 16, color: Colors.amber),
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (commentaire.isNotEmpty) Text(commentaire),
                    ]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // -------- images helpers ----------
  List<String> _imagesFromHotel() {
    final raw = hotel?['images'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    final p = (hotel?['photo_url'] ?? '').toString();
    return p.isNotEmpty ? [p] : [];
  }

  void _openFullScreenGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) {
        final controller = PageController(initialPage: initialIndex);
        int current = initialIndex;
        return StatefulBuilder(builder: (context, setS) {
          return Stack(
            children: [
              PhotoViewGallery.builder(
                itemCount: images.length,
                pageController: controller,
                builder: (_, i) => PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(images[i]),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: PhotoViewHeroAttributes(tag: 'hotel_$i'),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${current + 1}/${images.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          decoration: TextDecoration.none),
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
          );
        });
      },
    );
  }
  // -----------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (hotel == null) {
      return const Scaffold(body: Center(child: Text("Hôtel introuvable")));
    }

    final images = _imagesFromHotel();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text((hotel!['nom'] ?? '').toString()),
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: hotelsPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: hotelsPrimary),
        elevation: 1,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: SizedBox(
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [hotelsPrimary, hotelsSecondary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // -------- carrousel + miniatures + compteur --------
          if (images.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  SizedBox(
                    height: 230,
                    width: double.infinity,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => _openFullScreenGallery(images, index),
                        child: Hero(
                          tag: 'hotel_$index',
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${images.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            decoration: TextDecoration.none),
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
                            color: isActive ? hotelsPrimary : Colors.transparent,
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
                child:
                    const Center(child: Icon(Icons.image_not_supported, size: 60)),
              ),
            ),
          // -----------------------------------------------------

          const SizedBox(height: 16),

          Text("Ville : ${(hotel!['ville'] ?? 'Non précisé').toString()}",
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            "Prix moyen : ${(hotel!['prix'] ?? 'Non précisé').toString()} ${(hotel!['devise'] ?? '').toString()}",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text("Description :\n${(hotel!['description'] ?? 'Aucune description').toString()}"),
          const SizedBox(height: 12),

          // bouton Localiser
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _localiser,
              icon: const Icon(Icons.map),
              label: const Text("Localiser"),
              style: ElevatedButton.styleFrom(
                backgroundColor: hotelsSecondary,
                foregroundColor: onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text("Avis client :", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(_avis.isEmpty ? "Pas d'avis" : "${_noteMoyenne.toStringAsFixed(1)} / 5"),

          const SizedBox(height: 10),
          const Text("Notez cet hôtel :", style: TextStyle(fontWeight: FontWeight.bold)),
          _buildStars(_noteUtilisateur,
              onTap: (val) => setState(() => _noteUtilisateur = val)),
          TextField(
            controller: _avisController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Partagez votre expérience avec cet hôtel...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _envoyerAvis,
            icon: const Icon(Icons.send),
            label: const Text("Envoyer mon avis"),
            style: ElevatedButton.styleFrom(
              backgroundColor: hotelsSecondary,
              foregroundColor: onPrimary,
            ),
          ),

          const SizedBox(height: 20),
          _buildAvisList(),
          const SizedBox(height: 16),
        ]),
      ),

      // ------ Barre collée en bas ------
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
                  onPressed: _contacter,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text("Contacter"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hotelsSecondary,
                    foregroundColor: onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _ouvrirReservation,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text("Réserver"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hotelsPrimary,
                    foregroundColor: onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------- Navigation Vers Réservation --------
  void _ouvrirReservation() {
    final nom = (hotel?['nom'] ?? 'Hôtel').toString();
    final telRaw = (hotel?['telephone'] ?? hotel?['tel'] ?? '').toString().trim();
    final address = (hotel?['adresse'] ?? hotel?['ville'] ?? '').toString();
    final images = _imagesFromHotel();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelReservationPage(
          hotelName: nom.isEmpty ? 'Hôtel' : nom,
          phone: telRaw.isEmpty ? null : telRaw,
          address: address.isEmpty ? null : address,
          coverImage: images.isNotEmpty ? images.first : null,
          primaryColor: hotelsPrimary, // <-- palette Hôtels
        ),
      ),
    );
  }
}
