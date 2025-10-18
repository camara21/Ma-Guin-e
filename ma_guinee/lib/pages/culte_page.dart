import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'culte_detail_page.dart';

class CultePage extends StatefulWidget {
  const CultePage({super.key});

  @override
  State<CultePage> createState() => _CultePageState();
}

class _CultePageState extends State<CultePage> {
  // Données
  List<Map<String, dynamic>> _allLieux = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  // Recherche
  String _query = '';

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

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
    _locationDenied = false;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationDenied = true;
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
    } catch (_) {
      _locationDenied = true;
    }
  }

  double? _distanceMeters(
      double? lat1, double? lon1, double? lat2, double? lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  // ----------------------------------------------

  // ---------------- Chargement -------------------
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await _getLocation();

      // ✅ Plus de colonne "tags" ici : on prend tout, c'est sûr et simple
      final res = await Supabase.instance.client
          .from('lieux')
          .select('*')
          .eq('type', 'culte')
          .order('nom', ascending: true);

      final list = List<Map<String, dynamic>>.from(res);

      // Ajout de la distance en mètres
      if (_position != null) {
        for (final l in list) {
          final lat = (l['latitude'] as num?)?.toDouble();
          final lon = (l['longitude'] as num?)?.toDouble();
          l['_distance'] =
              _distanceMeters(_position!.latitude, _position!.longitude, lat, lon);
        }

        // Mosquées d’abord, puis même ville, puis distance, puis nom
        list.sort((a, b) {
          final aMosq = _isMosquee(a);
          final bMosq = _isMosquee(b);
          if (aMosq != bMosq) return aMosq ? -1 : 1;

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
        // Pas de position : mosquées d’abord puis nom
        list.sort((a, b) {
          final aMosq = _isMosquee(a);
          final bMosq = _isMosquee(b);
          if (aMosq != bMosq) return aMosq ? -1 : 1;
          return (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());
        });
      }

      _allLieux = list;
      _applyFilter(_query);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  // ----------------------------------------------

  // ---------------- Filtre -----------------------
  void _applyFilter(String q) {
    final lower = _norm(q);
    setState(() {
      _query = q;
      _filtered = _allLieux.where((l) {
        final nom = _norm(l['nom']);
        final ville = _norm(l['ville']);
        final type = _norm(l['type']);
        final cat = _norm(l['categorie']);
        final sous = _norm(l['sous_categorie']);
        final desc = _norm(l['description']);
        final all = '$nom $ville $type $cat $sous $desc';
        return all.contains(lower);
      }).toList();
    });
  }
  // ----------------------------------------------

  // ---------- Détection & icônes (accent-proof) ----------
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

  bool _isMosquee(Map<String, dynamic> l) {
    final s = _norm('${l['type']} ${l['sous_categorie']} ${l['categorie']} ${l['description']} ${l['nom']}');
    return s.contains('mosquee');
  }

  bool _isEglise(Map<String, dynamic> l) {
    final s = _norm('${l['type']} ${l['sous_categorie']} ${l['categorie']} ${l['description']} ${l['nom']}');
    return s.contains('eglise') || s.contains('cathedrale');
  }

  bool _isSanctuaire(Map<String, dynamic> l) {
    final s = _norm('${l['type']} ${l['sous_categorie']} ${l['categorie']} ${l['description']} ${l['nom']}');
    return s.contains('sanctuaire') || s.contains('temple');
  }

  IconData _iconFor(Map<String, dynamic> l) {
    if (_isMosquee(l)) return Icons.mosque;
    if (_isEglise(l)) return Icons.church;
    if (_isSanctuaire(l)) return Icons.shield_moon;
    return Icons.place;
  }

  Color _iconColor(Map<String, dynamic> l) {
    if (_isMosquee(l)) return const Color(0xFF009460); // vert
    if (_isEglise(l)) return const Color(0xFFCE1126); // rouge
    return Colors.indigo; // par défaut
  }
  // --------------------------------------------------------

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        title: const Text(
          'Lieux de culte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1.2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAll,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Recherche
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom, type ou ville...',
                      prefixIcon: const Icon(Icons.search, color: primaryColor),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _applyFilter,
                  ),
                ),

                if (_locationDenied)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 6),
                    child: Text(
                      "Active la localisation pour afficher la distance.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),

                // Grille de cartes
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text("Aucun lieu de culte trouvé."))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.77,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final lieu = _filtered[index];
                            final images = _imagesFrom(lieu['images']);
                            final image = images.isNotEmpty
                                ? images.first
                                : 'https://via.placeholder.com/300x200.png?text=Culte';

                            final ville = (lieu['ville'] ?? '').toString();
                            final distM = (lieu['_distance'] as double?);
                            final distLabel =
                                (distM != null) ? '${(distM / 1000).toStringAsFixed(1)} km' : null;

                            final icon = _iconFor(lieu);
                            final iconColor = _iconColor(lieu);

                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CulteDetailPage(lieu: lieu),
                                ),
                              ),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                                clipBehavior: Clip.hardEdge,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // IMAGE + BADGES (ville à gauche, type à droite)
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
                                                child: const Icon(Icons.broken_image, size: 50),
                                              ),
                                            ),
                                          ),

                                          // Badge ville (gauche)
                                          if (ville.isNotEmpty)
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
                                                      ville,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                          // Badge icône type (droite) → 🕌 / ⛪ / 🛕
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(icon, color: iconColor, size: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // TEXTE
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
                                                  ville,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              if (distLabel != null) ...[
                                                const Text('  •  ',
                                                    style: TextStyle(
                                                        color: Colors.grey, fontSize: 13)),
                                                Text(
                                                  distLabel,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          // Tag (=type) bleu
                                          if ((lieu['type'] ?? '').toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                (lieu['type'] ?? '').toString(),
                                                maxLines: 1,
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
              ],
            ),
    );
  }
}
