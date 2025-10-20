// lib/pages/tourisme_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'tourisme_detail_page.dart';

/// === Palette Tourisme (donnée) ===
const Color tourismePrimary = Color(0xFFDAA520);
const Color tourismeSecondary = Color(0xFFFFD700);
const Color tourismeOnPrimary = Color(0xFF000000);
const Color tourismeOnSecondary = Color(0xFF000000);

class TourismePage extends StatefulWidget {
  const TourismePage({super.key});

  @override
  State<TourismePage> createState() => _TourismePageState();
}

class _TourismePageState extends State<TourismePage> {
  // Données
  List<Map<String, dynamic>> _allLieux = [];
  List<Map<String, dynamic>> _filteredLieux = [];
  bool _loading = true;

  // Recherche
  String searchQuery = '';

  // Localisation
  Position? _position;
  String? _villeGPS;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ---------------- Localisation ----------------
  Future<void> _getLocation() async {
    _position = null;
    _villeGPS = null;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _position = pos;

      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = (p.locality?.isNotEmpty == true)
            ? p.locality
            : (p.subAdministrativeArea?.isNotEmpty == true
                ? p.subAdministrativeArea
                : null);
        _villeGPS = city?.toLowerCase().trim();
      }
    } catch (e) {
      debugPrint('Erreur localisation tourisme: $e');
    }
  }

  double? _distanceMeters(
      double? lat1, double? lon1, double? lat2, double? lon2) {
    if ([lat1, lon1, lat2, lon2].any((v) => v == null)) return null;
    const R = 6371000.0; // m
    final dLat = (lat2! - lat1!) * (pi / 180);
    final dLon = (lon2! - lon1!) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
  // ----------------------------------------------

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await _getLocation();

      // Adapter les colonnes à ta table "lieux"
      final response = await Supabase.instance.client
          .from('lieux')
          .select('''
            id, nom, ville, description, type, categorie,
            images, latitude, longitude, created_at,
            contact, photo_url
          ''')
          .eq('type', 'tourisme') // ou .eq('categorie', 'tourisme') selon ton schéma
          .order('nom');

      final list = List<Map<String, dynamic>>.from(response);

      // Ajoute la distance + tri intelligent (ville GPS prioritaire)
      if (_position != null) {
        for (final l in list) {
          final lat = (l['latitude'] as num?)?.toDouble();
          final lon = (l['longitude'] as num?)?.toDouble();
          l['_distance'] = _distanceMeters(
              _position!.latitude, _position!.longitude, lat, lon);
        }

        int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
            (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());

        if ((_villeGPS ?? '').isNotEmpty) {
          list.sort((a, b) {
            final aSame = (a['ville'] ?? '').toString().toLowerCase().trim() == _villeGPS;
            final bSame = (b['ville'] ?? '').toString().toLowerCase().trim() == _villeGPS;
            if (aSame != bSame) return aSame ? -1 : 1;

            final ad = (a['_distance'] as double?);
            final bd = (b['_distance'] as double?);
            if (ad != null && bd != null) return ad.compareTo(bd);
            if (ad != null) return -1;
            if (bd != null) return 1;

            return byName(a, b);
          });
        } else {
          list.sort((a, b) {
            final ad = (a['_distance'] as double?);
            final bd = (b['_distance'] as double?);
            if (ad != null && bd != null) return ad.compareTo(bd);
            if (ad != null) return -1;
            if (bd != null) return 1;
            return byName(a, b);
          });
        }
      }

      _allLieux = list;
      _filterLieux(searchQuery);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur chargement sites : $e')));
      _allLieux = [];
      _filteredLieux = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterLieux(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      searchQuery = query;
      _filteredLieux = _allLieux.where((lieu) {
        final nom = (lieu['nom'] ?? '').toString().toLowerCase();
        final ville = (lieu['ville'] ?? '').toString().toLowerCase();
        final desc = (lieu['description'] ?? '').toString().toLowerCase();
        final tag =
            (lieu['categorie'] ?? lieu['type'] ?? '').toString().toLowerCase();
        return nom.contains(q) ||
            ville.contains(q) ||
            desc.contains(q) ||
            tag.contains(q);
      }).toList();
    });
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      return raw.map<String>((e) => e.toString()).toList();
    }
    return const [];
  }

  String _bestImage(Map<String, dynamic> lieu) {
    final imgs = _imagesFrom(lieu['images']);
    if (imgs.isNotEmpty) return imgs.first;
    final photo = (lieu['photo_url'] ?? '').toString();
    if (photo.isNotEmpty) return photo;
    return 'https://via.placeholder.com/300x200.png?text=Tourisme';
  }

  @override
  Widget build(BuildContext context) {
    // Dégradé Tourisme pour AppBar
    const appBarGradient = LinearGradient(
      colors: [tourismePrimary, tourismeSecondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // Responsive simple : 1 colonne sur petit écran
    int crossAxisCount = 2;
    final width = MediaQuery.of(context).size.width;
    if (width < 380) crossAxisCount = 1;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light, // status bar claire
        title: const Text(
          "Sites touristiques",
          style: TextStyle(color: tourismeOnPrimary, fontWeight: FontWeight.w700),
        ),
        elevation: 0.0,
        foregroundColor: tourismeOnPrimary,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: appBarGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: tourismeOnPrimary),
            tooltip: 'Rafraîchir',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Bandeau promo
                Container(
                  width: double.infinity,
                  height: 75,
                  margin: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [tourismePrimary, tourismeSecondary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tourismePrimary.withOpacity(.18),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Découvrez les plus beaux sites touristiques de Guinée",
                        style: TextStyle(
                          color: tourismeOnPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),

                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un site, une ville…',
                      prefixIcon: const Icon(Icons.search, color: tourismePrimary),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: tourismeSecondary),
                      ),
                    ),
                    onChanged: _filterLieux,
                  ),
                ),
                const SizedBox(height: 10),

                // Grille
                Expanded(
                  child: _filteredLieux.isEmpty
                      ? const Center(child: Text("Aucun site trouvé."))
                      : RefreshIndicator(
                          onRefresh: _loadAll,
                          child: GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: crossAxisCount == 1 ? 2.0 : 0.77,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemCount: _filteredLieux.length,
                            itemBuilder: (context, index) {
                              final lieu = _filteredLieux[index];
                              final image = _bestImage(lieu);
                              final hasVille = (lieu['ville'] ?? '').toString().isNotEmpty;
                              final hasDesc = (lieu['description'] ?? '').toString().isNotEmpty;
                              final dist = (lieu['_distance'] as double?);

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TourismeDetailPage(lieu: lieu),
                                    ),
                                  );
                                },
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image + badge ville
                                      AspectRatio(
                                        aspectRatio: 16 / 11,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: Image.network(
                                                image,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: Colors.grey.shade300,
                                                  child: const Icon(Icons.landscape, size: 50),
                                                ),
                                              ),
                                            ),
                                            if (hasVille)
                                              Positioned(
                                                left: 8,
                                                top: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.55),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.location_on,
                                                          size: 14, color: Colors.white),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        lieu['ville'].toString(),
                                                        style: const TextStyle(
                                                            color: Colors.white, fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Texte
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (lieu['nom'] ?? '').toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            // Ville + distance
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    (lieu['ville'] ?? '').toString(),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                if (dist != null) ...[
                                                  const Text('  •  ',
                                                      style: TextStyle(
                                                          color: Colors.grey, fontSize: 13)),
                                                  Text(
                                                    '${(dist / 1000).toStringAsFixed(1)} km',
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (hasDesc)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  lieu['description'].toString(),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: tourismePrimary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
