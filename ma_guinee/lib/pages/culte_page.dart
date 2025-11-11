// lib/pages/culte_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/app_cache.dart';
import '../services/geoloc_service.dart';
import 'culte_detail_page.dart';

class CultePage extends StatefulWidget {
  const CultePage({super.key});

  @override
  State<CultePage> createState() => _CultePageState();
}

class _CultePageState extends State<CultePage> {
  // ====== Couleur page ======
  static const primaryColor = Color(0xFF113CFC);

  // ====== Cache (SWR) ======
  static const _CACHE_KEY = 'culte:lieux:v1';
  static const _CACHE_MAX_AGE = Duration(hours: 24);

  // Données
  List<Map<String, dynamic>> _allLieux = [];
  List<Map<String, dynamic>> _filtered = [];

  // État
  bool _loading = true;   // seulement pour 1er rendu sans cache -> skeleton
  bool _syncing = false;  // sync réseau silencieuse (aucun spinner affiché)

  // Recherche
  String _query = '';

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    _loadAllSWR(); // ⚡ instantané (cache) + réseau en arrière-plan
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

      // push position (silencieux)
      try {
        await GeolocService.reportPosition(pos);
      } catch (_) {}

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

  bool _isMosquee(Map<String, dynamic> l) {
    final s = _folded(
        '${l['type']} ${l['sous_categorie']} ${l['categorie']} ${l['description']} ${l['nom']}');
    return s.contains('mosquee');
  }

  bool _isEglise(Map<String, dynamic> l) {
    final s = _folded(
        '${l['type']} ${l['sous_categorie']} ${l['categorie']} ${l['description']} ${l['nom']}');
    return s.contains('eglise') || s.contains('cathedrale');
  }

  bool _isSanctuaire(Map<String, dynamic> l) {
    final s = _folded(
        '${l['type']} ${l['sous_categorie']} ${l['categorie']} ${l['description']} ${l['nom']}');
    return s.contains('sanctuaire') || s.contains('temple');
  }

  IconData _iconFor(Map<String, dynamic> l) {
    if (_isMosquee(l)) return Icons.mosque;
    if (_isEglise(l)) return Icons.church;
    if (_isSanctuaire(l)) return Icons.shield_moon;
    return Icons.place;
  }

  Color _iconColor(Map<String, dynamic> l) {
    if (_isMosquee(l)) return const Color(0xFF009460);
    if (_isEglise(l)) return const Color(0xFF0F6EFD); // bleu discret (pas de rouge)
    return Colors.indigo;
  }

  // --------------- SWR: Cache -> Réseau ---------------
  Future<void> _loadAllSWR() async {
    // 1) Instantané: mémoire ou disque si non expiré
    final mem = AppCache.I.getListMemory(_CACHE_KEY, maxAge: _CACHE_MAX_AGE);
    List<Map<String, dynamic>>? disk;
    if (mem == null) {
      disk = await AppCache.I.getListPersistent(_CACHE_KEY, maxAge: _CACHE_MAX_AGE);
    }
    final snapshot = mem ?? disk;

    if (snapshot != null) {
      final snapClone = snapshot.map((e) => Map<String, dynamic>.from(e)).toList();
      // enrichissements distance + tri
      await _getLocation();
      final enriched = await _enrichAndSort(snapClone);
      _allLieux = enriched;
      _applyFilter(_query);
      if (mounted) setState(() => _loading = false);
    } else {
      // premier affichage sans données -> skeleton (pas de spinner)
      if (mounted) setState(() => _loading = true);
    }

    // 2) Réseau en arrière-plan: met à jour l’UI et recache
    if (mounted) setState(() => _syncing = true);
    try {
      await _getLocation();

      final res = await Supabase.instance.client
          .from('lieux')
          .select('id, nom, ville, type, categorie, sous_categorie, description, images, latitude, longitude, created_at')
          .eq('type', 'culte')
          .order('nom', ascending: true);

      final list = List<Map<String, dynamic>>.from(res);
      final enriched = await _enrichAndSort(list);

      _allLieux = enriched;
      _applyFilter(_query);

      // retire champs volatils avant cache
      final toCache = enriched.map((m) {
        final c = Map<String, dynamic>.from(m);
        c.remove('_distance');
        return c;
      }).toList(growable: false);

      AppCache.I.setList(_CACHE_KEY, toCache, persist: true);
    } catch (e) {
      // silencieux: on reste sur le cache/skeleton
    } finally {
      if (mounted) {
        _syncing = false;
        _loading = false;
        setState(() {});
      }
    }
  }

  Future<List<Map<String, dynamic>>> _enrichAndSort(
      List<Map<String, dynamic>> list) async {
    if (_position != null) {
      for (final l in list) {
        final lat = (l['latitude'] as num?)?.toDouble();
        final lon = (l['longitude'] as num?)?.toDouble();
        l['_distance'] =
            _distanceMeters(_position!.latitude, _position!.longitude, lat, lon);
      }
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
      list.sort((a, b) {
        final aMosq = _isMosquee(a);
        final bMosq = _isMosquee(b);
        if (aMosq != bMosq) return aMosq ? -1 : 1;
        return (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());
      });
    }
    return list;
  }

  // ---------------- Filtre -----------------------
  void _applyFilter(String q) {
    final lower = _folded(q);
    _query = q;
    _filtered = _allLieux.where((l) {
      final nom = _folded(l['nom']);
      final ville = _folded(l['ville']);
      final type = _folded(l['type']);
      final cat = _folded(l['categorie']);
      final sous = _folded(l['sous_categorie']);
      final desc = _folded(l['description']);
      final all = '$nom $ville $type $cat $sous $desc';
      return all.contains(lower);
    }).toList();
    if (mounted) setState(() {});
  }

  String _folded(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    if (s.isEmpty) return '';
    const map = {
      'à': 'a','á': 'a','â': 'a','ä': 'a','ã': 'a','å': 'a',
      'ç': 'c',
      'è': 'e','é': 'e','ê': 'e','ë': 'e',
      'ì': 'i','í': 'i','î': 'i','ï': 'i',
      'ñ': 'n',
      'ò': 'o','ó': 'o','ô': 'o','ö': 'o','õ': 'o',
      'ù': 'u','ú': 'u','û': 'u','ü': 'u',
      'ý': 'y','ÿ': 'y','œ': 'oe',
    };
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    // Clamp léger du textScale
    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);

    // Grille responsive + espacement serré (8)
    final screenW = media.size.width;
    final crossCount = screenW < 600
        ? max(2, (screenW / 200).floor())
        : max(3, (screenW / 240).floor());
    final totalHGap = (crossCount - 1) * 8.0 + 28.0; // gaps + padding latéral
    final itemW = (screenW - totalHGap) / crossCount;
    final itemH = itemW * (11 / 16) + 110.0; // image 16:11 + zone texte
    final ratio = itemW / itemH;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8FB),
        appBar: AppBar(
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Lieux de culte',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // aucune roue/loader : on peut afficher un petit point vert/bleu si on veut
              if (_syncing)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle, size: 14, color: Colors.white70),
                ),
            ],
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 1.2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadAllSWR, // ⚡ instant + sync silencieuse
              tooltip: 'Rafraîchir',
            ),
          ],
        ),
        body: _loading
            ? _skeletonGrid(context, crossCount, ratio) // ✅ pas de spinner
            : Column(
                children: [
                  // Bandeau intro (léger)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.65)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Text(
                      "Mosquées, églises et lieux de prière près de vous",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.2),
                    ),
                  ),

                  // Recherche
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

                  // Grille (pas de RefreshIndicator => pas de spinner)
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(child: Text("Aucun lieu de culte trouvé."))
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossCount,
                              mainAxisSpacing: 8, // serré
                              crossAxisSpacing: 8, // serré
                              childAspectRatio: ratio,
                            ),
                            cacheExtent: 1200, // meilleure perf défilement
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final lieu = _filtered[index];
                              final images = _imagesFrom(lieu['images']);
                              final image = images.isNotEmpty
                                  ? images.first
                                  : 'https://via.placeholder.com/300x200.png?text=Culte';

                              final ville = (lieu['ville'] ?? '').toString();
                              final distM = (lieu['_distance'] as double?);
                              final distLabel = (distM != null)
                                  ? '${(distM / 1000).toStringAsFixed(1)} km'
                                  : null;

                              final icon = _iconFor(lieu);
                              final iconColor = _iconColor(lieu);

                              return _CulteCardTight(
                                lieu: lieu,
                                imageUrl: image,
                                ville: ville,
                                distLabel: distLabel,
                                icon: icon,
                                iconColor: iconColor,
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // -------------- Skeleton --------------
  Widget _skeletonGrid(BuildContext context, int crossCount, double ratio) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: ratio,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

// ======================== Carte adaptative ===========================
class _CulteCardTight extends StatelessWidget {
  final Map<String, dynamic> lieu;
  final String imageUrl;
  final String ville;
  final String? distLabel;
  final IconData icon;
  final Color iconColor;

  const _CulteCardTight({
    required this.lieu,
    required this.imageUrl,
    required this.ville,
    required this.distLabel,
    required this.icon,
    required this.iconColor,
  });

  static const primaryColor = _CultePageState.primaryColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CulteDetailPage(lieu: lieu)),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE + BADGES
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                final h = w * (11 / 16);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // ✅ Image de haute qualité sans spinner (placeholder gris)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: w.isFinite ? (w * 2).round() : null,
                      memCacheHeight: h.isFinite ? (h * 2).round() : null,
                      placeholder: (_, __) => Container(color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image, size: 40, color: Colors.grey.shade500),
                      ),
                    ),
                    if (ville.isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                ville,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                    ),
                  ],
                );
              }),
            ),

            // TEXTE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (lieu['nom'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ville,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                      if (distLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(distLabel!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ],
                  ),
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
  }
}

// --------------- Skeleton Card (aucun spinner) ----------------
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 16 / 11, child: Container(color: Colors.grey.shade200)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 140, color: Colors.grey.shade200),
                const SizedBox(height: 6),
                Container(height: 12, width: 90, color: Colors.grey.shade200),
                const SizedBox(height: 6),
                Container(height: 12, width: 70, color: Colors.grey.shade200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
