// lib/pages/tourisme_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/app_cache.dart';
import '../services/geoloc_service.dart';
import 'tourisme_detail_page.dart';

const Color tourismePrimary = Color(0xFFDAA520);
const Color tourismeSecondary = Color(0xFFFFD700);
const Color neutralBg = Color(0xFFF7F7F9);
const Color neutralSurface = Color(0xFFFFFFFF);
const Color neutralBorder = Color(0xFFE5E7EB);

class TourismePage extends StatefulWidget {
  const TourismePage({super.key});
  @override
  State<TourismePage> createState() => _TourismePageState();
}

class _TourismePageState extends State<TourismePage> {
  final _sb = Supabase.instance.client;
  static const _cacheKey = 'tourisme:lieux:list:v2';

  List<Map<String, dynamic>> _allLieux = [];
  List<Map<String, dynamic>> _filteredLieux = [];
  bool _loading = true;   // skeletons si true
  bool _syncing = false;

  // recherche
  String searchQuery = '';
  Timer? _debounce;

  // localisation rapide (non bloquante)
  Position? _position;
  String? _villeGPS;

  // notes
  final Map<String, double> _avgByLieuId = {};
  final Map<String, int> _countByLieuId = {};
  String? _lastRatingsKey;

  // pré-cache images
  bool _didPrecache = false;

  @override
  void initState() {
    super.initState();
    _loadAllSWR();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ----------- Localisation ultra-rapide (timeout + no-block) -----------
  Future<void> _getLocationFast() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      // ⏱️ temps max 600ms – si ça dépasse, on continue sans position
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(milliseconds: 600),
      );
      _position = pos;

      // Push backend, mais sans await (fire-&-forget)
      unawaited(GeolocService.reportPosition(pos));

      // Reverse geocoding en fond, sans bloquer l’UI.
      unawaited(_resolveCity(pos));
    } catch (_) {
      // silencieux : jamais bloquant
    }
  }

  Future<void> _resolveCity(Position pos) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final city = (p.locality?.isNotEmpty == true)
            ? p.locality
            : (p.subAdministrativeArea?.isNotEmpty == true
                ? p.subAdministrativeArea
                : null);
        setState(() => _villeGPS = city?.toLowerCase().trim());
        // On rejoue un tri par distance + ville après coup
        _resortByDistanceInBackground();
      }
    } catch (_) {}
  }

  // ---------- Haversine ----------
  static double? _dist(double? lat1, double? lon1, double? lat2, double? lon2) {
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

  // ---------- SWR : instant + sync ----------
  Future<void> _loadAllSWR() async {
    // 1) Afficher immédiatement le cache (instantané)
    final cached =
        AppCache.I.getList(_cacheKey, maxAge: const Duration(hours: 12));
    if (cached != null) {
      setState(() {
        _loading = false;
        _allLieux = cached;
        _filterLieuxCore(searchQuery);
      });
      _afterFirstPaint();
    } else {
      setState(() => _loading = true); // skeletons
    }

    if (_syncing) return;
    _syncing = true;

    // On lance localisation en // sans bloquer
    unawaited(_getLocationFast());

    try {
      // Requête minimale (colonnes utiles)
      final response = await _sb.from('lieux').select('''
        id, nom, ville, type, categorie,
        images, latitude, longitude, photo_url
      ''').eq('type', 'tourisme').order('nom');

      final list = List<Map<String, dynamic>>.from(response);

      // Tri par nom d’abord (instantané)
      list.sort((a, b) =>
          (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString()));

      // On affiche tout de suite
      if (!mounted) return;
      setState(() {
        _allLieux = list;
        _filterLieuxCore(searchQuery);
        _loading = false;
      });

      AppCache.I.setList(_cacheKey, list);

      // Après affichage : tri distance/ville en arrière-plan si position dispo
      _resortByDistanceInBackground();

      _afterFirstPaint();
    } catch (_) {
      if (!mounted) return;
      if (_allLieux.isEmpty) setState(() => _loading = true); // skeletons
    } finally {
      _syncing = false;
    }
  }

  // Tri distance/ville dans un isolate pour ne pas bloquer l’UI
  Future<void> _resortByDistanceInBackground() async {
    if (_position == null || _allLieux.isEmpty) return;
    final payload = _SortPayload(
      items: _allLieux,
      userLat: _position!.latitude,
      userLon: _position!.longitude,
      villeLower: _villeGPS,
    );
    final sorted = await compute<_SortPayload, List<Map<String, dynamic>>>(
        _sortPlacesByProximity, payload);
    if (!mounted) return;
    setState(() {
      _allLieux = sorted;
      _filterLieuxCore(searchQuery);
    });
  }

  // Post-affichage : pré-cache images + charger notes
  void _afterFirstPaint() {
    if (!_didPrecache && _filteredLieux.isNotEmpty) {
      _didPrecache = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Pré-charger les 8 premières images
        for (final l in _filteredLieux.take(8)) {
          final url = _bestImage(l);
          if (url.isNotEmpty && mounted) {
            try {
              await precacheImage(CachedNetworkImageProvider(url), context);
            } catch (_) {}
          }
        }
        // Charger les notes après l’affichage
        final ids = _filteredLieux
            .map((l) => (l['id'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
        _loadRatingsFor(ids);
      });
    }
  }

  // ---------- Recherche (debounce) ----------
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      _filterLieuxCore(q);
      // pré-cache un petit lot après filtrage
      _didPrecache = false;
      _afterFirstPaint();
    });
  }

  void _filterLieuxCore(String query) {
    final q = query.toLowerCase().trim();
    searchQuery = query;
    _filteredLieux = _allLieux.where((lieu) {
      final nom = (lieu['nom'] ?? '').toString().toLowerCase();
      final ville = (lieu['ville'] ?? '').toString().toLowerCase();
      final tag =
          (lieu['categorie'] ?? lieu['type'] ?? '').toString().toLowerCase();
      return q.isEmpty || nom.contains(q) || ville.contains(q) || tag.contains(q);
    }).toList();
  }

  // ---------- Notes (throttled) ----------
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
        final batch = ids.sublist(i, min(i + batchSize, ids.length));
        final orFilter = batch.map((id) => 'lieu_id.eq.$id').join(',');
        final rows = await _sb
            .from('avis_lieux')
            .select('lieu_id, etoiles')
            .or(orFilter);

        for (final r in List<Map<String, dynamic>>.from(rows)) {
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

  // --------- Helpers images ----------
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
    return photo;
  }

  Widget _stars(double value, {double size = 14}) {
    final full = value.floor();
    final half = (value - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return Icon(Icons.star, size: size, color: Colors.amber);
        if (i == full && half) return Icon(Icons.star_half, size: size, color: Colors.amber);
        return Icon(Icons.star_border, size: size, color: Colors.amber);
      }),
    );
  }

  // --------- Skeleton grid ----------
  Widget _skeletonGrid(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final crossCount = screenW < 600
        ? max(2, (screenW / 200).floor())
        : max(3, (screenW / 240).floor());
    final totalHGap = (crossCount - 1) * 8.0 + 16.0;
    final itemW = (screenW - totalHGap) / crossCount;
    final itemH = itemW * (11 / 16) + 112.0;
    final ratio = itemW / itemH;

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: ratio,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: 8,
      itemBuilder: (_, __) => Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1.5,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bottomGradient = LinearGradient(
      colors: [tourismePrimary, tourismeSecondary],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);
    final screenW = media.size.width;
    final crossCount = screenW < 600
        ? (screenW / 200).floor().clamp(2, 6)
        : (screenW / 240).floor().clamp(3, 6);
    final totalHGap = (crossCount - 1) * 8.0 + 16.0;
    final itemW = (screenW - totalHGap) / crossCount;
    final itemH = itemW * (11 / 16) + 112.0;
    final ratio = itemW / itemH;

    // Throttle notes après rendu (si nouvelle liste)
    final visibleIds = _filteredLieux
        .map((l) => (l['id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    final k = visibleIds.join(',');
    if (k != _lastRatingsKey && !_loading) {
      // on ne bloque pas l'UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRatingsFor(visibleIds);
      });
    }

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: neutralBg,
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          title: const Text(
            "Sites touristiques",
            style: TextStyle(color: tourismePrimary, fontWeight: FontWeight.w700),
          ),
          backgroundColor: neutralSurface,
          elevation: 1,
          foregroundColor: tourismePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: tourismePrimary),
              tooltip: 'Rafraîchir',
              onPressed: _loadAllSWR,
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(3),
            child: SizedBox(
              height: 3,
              child: DecoratedBox(decoration: BoxDecoration(gradient: bottomGradient)),
            ),
          ),
        ),
        body: Column(
          children: [
            // Bandeau
            Container(
              width: double.infinity,
              height: 72,
              margin: const EdgeInsets.only(left: 8, right: 8, top: 10, bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [tourismePrimary, tourismeSecondary]),
              ),
              clipBehavior: Clip.hardEdge,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Découvrez les plus beaux sites touristiques de Guinée",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2, decoration: TextDecoration.none),
                  ),
                ),
              ),
            ),

            // Recherche (debounce)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher un site ou une ville…',
                  prefixIcon: Icon(Icons.search, color: tourismePrimary),
                  filled: true,
                  fillColor: neutralSurface,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 6),

            // grille
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: _loading
                    ? _skeletonGrid(context)
                    : (_filteredLieux.isEmpty
                        ? const Center(child: Text("Aucun site trouvé."))
                        : GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossCount,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: ratio,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            itemCount: _filteredLieux.length,
                            itemBuilder: (context, index) {
                              final lieu = _filteredLieux[index];
                              final id = (lieu['id'] ?? '').toString();
                              final image = _bestImage(lieu);
                              final dist = (lieu['_distance'] as double?);
                              final rating = _avgByLieuId[id] ?? 0.0;
                              final count = _countByLieuId[id] ?? 0;

                              return InkWell(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TourismeDetailPage(lieu: lieu)));
                                },
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color: neutralSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(color: neutralBorder),
                                  ),
                                  elevation: 1.5,
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image 16:11
                                      Expanded(
                                        child: LayoutBuilder(
                                          builder: (context, cons) {
                                            final w = cons.maxWidth;
                                            final h = w * (11 / 16);
                                            return Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                CachedNetworkImage(
                                                  imageUrl: image.isEmpty
                                                      ? 'https://via.placeholder.com/300x200.png?text=Tourisme'
                                                      : image,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: w.isFinite ? (w * 2).round() : null,
                                                  memCacheHeight: h.isFinite ? (h * 2).round() : null,
                                                  fadeInDuration: Duration.zero,
                                                  fadeOutDuration: Duration.zero,
                                                  placeholderFadeInDuration: Duration.zero,
                                                  placeholder: (_, __) =>
                                                      Container(color: Colors.grey.shade300),
                                                  errorWidget: (_, __, ___) =>
                                                      const Icon(Icons.landscape, size: 40, color: Colors.grey),
                                                ),
                                                if ((lieu['ville'] ?? '').toString().isNotEmpty)
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
                                                            (lieu['ville'] ?? '').toString(),
                                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),

                                      // Texte compact
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
                                                  Text('($count)',
                                                      style: TextStyle(color: Colors.black.withOpacity(.6), fontSize: 12)),
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
                                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                                  ),
                                                ),
                                                if (dist != null) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${(dist / 1000).toStringAsFixed(1)} km',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.fade,
                                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== Isolate helpers ===================
class _SortPayload {
  final List<Map<String, dynamic>> items;
  final double userLat;
  final double userLon;
  final String? villeLower;
  _SortPayload({
    required this.items,
    required this.userLat,
    required this.userLon,
    required this.villeLower,
  });
}

List<Map<String, dynamic>> _sortPlacesByProximity(_SortPayload p) {
  final list = List<Map<String, dynamic>>.from(p.items.map((e) => Map<String, dynamic>.from(e)));

  for (final l in list) {
    final lat = (l['latitude'] as num?)?.toDouble();
    final lon = (l['longitude'] as num?)?.toDouble();
    final d = _dist(lat, lon, p.userLat, p.userLon);
    l['_distance'] = d;
  }

  int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
      (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());

  if ((p.villeLower ?? '').isNotEmpty) {
    list.sort((a, b) {
      final aSame = (a['ville'] ?? '').toString().toLowerCase().trim() == p.villeLower;
      final bSame = (b['ville'] ?? '').toString().toLowerCase().trim() == p.villeLower;
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
  return list;
}

// distance util pour isolate
double? _dist(double? lat1, double? lon1, double? lat2, double? lon2) {
  if ([lat1, lon1, lat2, lon2].any((v) => v == null)) return null;
  const R = 6371000.0;
  final dLat = (lat2! - lat1!) * (pi / 180);
  final dLon = (lon2! - lon1!) * (pi / 180);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) * sin(dLon / 2) * sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}
