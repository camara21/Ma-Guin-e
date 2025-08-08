import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'tourisme_detail_page.dart';

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

  static const primaryColor = Color(0xFF113CFC);

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

      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
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
    const R = 6371000.0;
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

      // ✅ Only columns that exist in your "lieux" table
      final response = await Supabase.instance.client
          .from('lieux')
          .select('''
            id, nom, ville, description, type, categorie,
            images, latitude, longitude, created_at,
            contact, photo_url
          ''')
          .eq('type', 'tourisme') // ou .eq('categorie','tourisme') selon ton schéma
          .order('nom');

      final list = List<Map<String, dynamic>>.from(response);

      // Calcule la distance + tri
      if (_position != null) {
        for (final l in list) {
          final lat = (l['latitude'] as num?)?.toDouble();
          final lon = (l['longitude'] as num?)?.toDouble();
          l['_distance'] =
              _distanceMeters(_position!.latitude, _position!.longitude, lat, lon);
        }

        if ((_villeGPS ?? '').isNotEmpty) {
          list.sort((a, b) {
            final aSame =
                (a['ville'] ?? '').toString().toLowerCase().trim() == _villeGPS;
            final bSame =
                (b['ville'] ?? '').toString().toLowerCase().trim() == _villeGPS;
            if (aSame != bSame) return aSame ? -1 : 1;

            final ad = (a['_distance'] as double?);
            final bd = (b['_distance'] as double?);
            if (ad != null && bd != null) return ad.compareTo(bd);
            if (ad != null) return -1;
            if (bd != null) return 1;

            return (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());
          });
        } else {
          list.sort((a, b) {
            final ad = (a['_distance'] as double?);
            final bd = (b['_distance'] as double?);
            if (ad != null && bd != null) return ad.compareTo(bd);
            if (ad != null) return -1;
            if (bd != null) return 1;
            return (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());
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
        final tag = (lieu['categorie'] ?? lieu['type'] ?? '').toString().toLowerCase();
        return nom.contains(q) || ville.contains(q) || desc.contains(q) || tag.contains(q);
      }).toList();
    });
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      return raw.map<String>((e) => e.toString()).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Sites touristiques",
        ),
        backgroundColor: Colors.white,
        elevation: 0.7,
        foregroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Bandeau
                Container(
                  width: double.infinity,
                  height: 75,
                  margin: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [primaryColor, Color(0xFF2EC4F1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Découvrez les plus beaux sites touristiques de Guinée",
                        style: TextStyle(
                          color: Colors.white,
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
                      hintText: 'Rechercher un site, une ville...',
                      prefixIcon: const Icon(Icons.search, color: primaryColor),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
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
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.77,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemCount: _filteredLieux.length,
                            itemBuilder: (context, index) {
                              final lieu = _filteredLieux[index];
                              final imgs = _imagesFrom(lieu['images']);
                              final image = imgs.isNotEmpty
                                  ? imgs.first
                                  : 'https://via.placeholder.com/300x200.png?text=Tourisme';

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
                                            if ((lieu['ville'] ?? '').toString().isNotEmpty)
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
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
                                                if (lieu['_distance'] != null) ...[
                                                  const Text('  •  ',
                                                      style: TextStyle(
                                                          color: Colors.grey, fontSize: 13)),
                                                  Text(
                                                    '${(lieu['_distance'] / 1000).toStringAsFixed(1)} km',
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if ((lieu['description'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  lieu['description'].toString(),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: primaryColor,
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
