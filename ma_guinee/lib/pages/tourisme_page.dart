import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/app_cache.dart';
import 'tourisme_detail_page.dart';
import '../services/geoloc_service.dart'; // ✅ NEW: centraliser l’envoi localisation

const Color tourismePrimary = Color(0xFFDAA520);
const Color tourismeSecondary = Color(0xFFFFD700);
const Color neutralBg      = Color(0xFFF7F7F9);
const Color neutralSurface = Color(0xFFFFFFFF);
const Color neutralBorder  = Color(0xFFE5E7EB);

class TourismePage extends StatefulWidget {
  const TourismePage({super.key});
  @override
  State<TourismePage> createState() => _TourismePageState();
}

class _TourismePageState extends State<TourismePage> {
  final _sb = Supabase.instance.client;

  static const _cacheKey = 'tourisme:lieux:list:v1';

  List<Map<String, dynamic>> _allLieux = [];
  List<Map<String, dynamic>> _filteredLieux = [];
  bool _loading = true;
  bool _syncing = false;

  String searchQuery = '';
  Position? _position;
  String? _villeGPS;

  final Map<String, double> _avgByLieuId = {};
  final Map<String, int> _countByLieuId = {};
  String? _lastRatingsKey;

  @override
  void initState() {
    super.initState();
    _loadAllSWR();
  }

  // ---------- Localisation ----------
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

      // ✅ NEW: envoyer la localisation comme sur les autres pages
      try { await GeolocService.reportPosition(pos); } catch (_) {}

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
    } catch (_) {}
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

  // ---------- SWR : montre le cache puis sync réseau ----------
  Future<void> _loadAllSWR() async {
    final cached = AppCache.I.getList(_cacheKey, maxAge: const Duration(hours: 24));
    if (cached != null) {
      setState(() {
        _loading = false;
        _allLieux = cached;
        _filterLieux(searchQuery);
      });
      _loadRatingsFor(_filteredLieux.map((l) => (l['id'] ?? '').toString()).toList());
    } else {
      setState(() => _loading = true);
    }

    setState(() => _syncing = true);
    try {
      await _getLocation();

      // ⚠️ description NON sélectionnée (moins de données)
      final response = await _sb
          .from('lieux')
          .select('''
            id, nom, ville, type, categorie,
            images, latitude, longitude, created_at,
            contact, photo_url
          ''')
          .eq('type', 'tourisme')
          .order('nom');

      final list = List<Map<String, dynamic>>.from(response);

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

      AppCache.I.setList(_cacheKey, list);

      if (!mounted) return;
      setState(() {
        _allLieux = list;
        _filterLieux(searchQuery);
      });

      _loadRatingsFor(_filteredLieux.map((l) => (l['id'] ?? '').toString()).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Réseau lent — cache affiché. ($e)')));
    } finally {
      if (mounted) setState(() => _syncing = false);
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  void _filterLieux(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      searchQuery = query;
      _filteredLieux = _allLieux.where((lieu) {
        final nom = (lieu['nom'] ?? '').toString().toLowerCase();
        final ville = (lieu['ville'] ?? '').toString().toLowerCase();
        final tag  = (lieu['categorie'] ?? lieu['type'] ?? '').toString().toLowerCase();
        // ❌ pas de recherche dans description
        return nom.contains(q) || ville.contains(q) || tag.contains(q);
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

  Future<void> _loadRatingsFor(List<String> ids) async {
    if (ids.isEmpty) return;
    final key = ids.join(',');
    if (key == _lastRatingsKey) return;
    _lastRatingsKey = key;

    try {
      const int batchSize = 20;
      final Map<String, int> sum = {};
      final Map<String, int> cnt = {};

      for (var i = 0; i < ids.length; i += batchSize) {
        final batch = ids.sublist(i, (i + batchSize > ids.length) ? ids.length : i + batchSize);
        final orFilter = batch.map((id) => 'lieu_id.eq.$id').join(',');

        final rows = await _sb
            .from('avis_lieux')
            .select('lieu_id, etoiles')
            .or(orFilter);

        final list = List<Map<String, dynamic>>.from(rows);
        for (final r in list) {
          final id = r['lieu_id']?.toString();
          final n = (r['etoiles'] as num?)?.toInt() ?? 0;
          if (id == null || id.isEmpty || n <= 0) continue;
          sum[id] = (sum[id] ?? 0) + n;
          cnt[id] = (cnt[id] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _avgByLieuId.clear();
        _countByLieuId.clear();
        for (final id in ids) {
          final c = cnt[id] ?? 0;
          final s = sum[id] ?? 0;
          _avgByLieuId[id] = c > 0 ? s / c : 0.0;
          _countByLieuId[id] = c;
        }
      });
    } catch (_) {}
  }

  Widget _stars(double value, {double size = 14}) {
    final full = value.floor();
    final half = (value - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) {
          return Icon(Icons.star, size: size, color: Colors.amber);
        } else if (i == full && half) {
          return Icon(Icons.star_half, size: size, color: Colors.amber);
        } else {
          return Icon(Icons.star_border, size: size, color: Colors.amber);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bottomGradient = LinearGradient(
      colors: [tourismePrimary, tourismeSecondary],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    int crossAxisCount = 2;
    final width = MediaQuery.of(context).size.width;
    if (width < 380) crossAxisCount = 1;

    final visibleIds = _filteredLieux.map((l) => (l['id'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
    final key = visibleIds.join(',');
    if (key != _lastRatingsKey && !_loading) {
      _loadRatingsFor(visibleIds);
    }

    return Scaffold(
      backgroundColor: neutralBg,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Row(
          children: [
            const Text(
              "Sites touristiques",
              style: TextStyle(color: tourismePrimary, fontWeight: FontWeight.w700),
            ),
            if (_syncing) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        backgroundColor: neutralSurface,
        elevation: 1,
        foregroundColor: tourismePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: tourismePrimary),
            tooltip: 'Rafraîchir',
            onPressed: _loadAllSWR, // instant + sync
          ),
        ],
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Bandeau
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: tourismePrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tourismePrimary.withOpacity(0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.terrain, color: tourismePrimary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Découvrez les plus beaux sites touristiques de Guinée",
                          style: TextStyle(
                            color: tourismePrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Recherche
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un site ou une ville…',
                      prefixIcon: const Icon(Icons.search, color: tourismePrimary),
                      filled: true,
                      fillColor: neutralSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: neutralBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: neutralBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: tourismeSecondary, width: 1.5),
                      ),
                    ),
                    onChanged: _filterLieux,
                  ),
                ),
                const SizedBox(height: 6),

                // Grille
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAllSWR, // instant + sync
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
                        final id = (lieu['id'] ?? '').toString();
                        final image = _bestImage(lieu);
                        final hasVille = (lieu['ville'] ?? '').toString().isNotEmpty;
                        final dist = (lieu['_distance'] as double?);
                        final rating = _avgByLieuId[id] ?? 0.0;
                        final count = _countByLieuId[id] ?? 0;

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
                            color: neutralSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: neutralBorder),
                            ),
                            elevation: 1.5,
                            clipBehavior: Clip.hardEdge,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image + ville (cached)
                                AspectRatio(
                                  aspectRatio: 16 / 11,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CachedNetworkImage(
                                          imageUrl: image,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: Colors.grey.shade300),
                                          errorWidget: (_, __, ___) => const Icon(Icons.landscape, size: 40),
                                        ),
                                      ),
                                      if (hasVille)
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
                                                  lieu['ville'].toString(),
                                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Texte (sans description)
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
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _stars(rating),
                                          const SizedBox(width: 6),
                                          Text(
                                            count > 0 ? rating.toStringAsFixed(1) : '—',
                                            style: TextStyle(
                                              color: Colors.black.withOpacity(.85),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          if (count > 0) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '($count)',
                                              style: TextStyle(
                                                color: Colors.black.withOpacity(.6),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (lieu['ville'] ?? '').toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.black.withOpacity(.54),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          if (dist != null) ...[
                                            Text('  •  ',
                                                style: TextStyle(color: Colors.black.withOpacity(.54), fontSize: 13)),
                                            Text(
                                              '${(dist / 1000).toStringAsFixed(1)} km',
                                              style: TextStyle(color: Colors.black.withOpacity(.54), fontSize: 13),
                                            ),
                                          ],
                                        ],
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
