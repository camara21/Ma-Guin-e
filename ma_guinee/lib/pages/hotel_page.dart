// lib/pages/hotel_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'hotel_detail_page.dart';

// ⬇️ AppCache (SWR)
import '../services/app_cache.dart';
// ⬇️ centralisation envoi position
import '../services/geoloc_service.dart';

class HotelPage extends StatefulWidget {
  const HotelPage({super.key});

  @override
  State<HotelPage> createState() => _HotelPageState();
}

class _HotelPageState extends State<HotelPage>
    with AutomaticKeepAliveClientMixin {
  // ===== Couleurs (Hôtels) — page spécifique =====
  static const Color hotelsPrimary = Color(0xFF264653);
  static const Color hotelsSecondary = Color(0xFF2A9D8F);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Neutres
  static const Color neutralBg = Color(0xFFF7F7F9);
  static const Color neutralSurface = Color(0xFFFFFFFF);
  static const Color neutralBorder = Color(0xFFE5E7EB);

  // Cache SWR
  static const String _CACHE_KEY = 'hotels_v1';
  static const Duration _CACHE_MAX_AGE = Duration(hours: 12);

  // ✅ Cache mémoire global (retour écran instant)
  static List<Map<String, dynamic>> _memoryCacheHotels = [];

  // ✅ Hive persistant (instant même après relance)
  static const String _hiveBoxName = 'hotels_box';
  static const String _hiveKey = 'hotels_snapshot_v1';

  // Données
  List<Map<String, dynamic>> hotels = [];
  List<Map<String, dynamic>> filteredHotels = [];

  // État
  bool _hasAnyCache = false;
  bool _syncing = false;

  // ⭐️ notes moyennes (batch)
  final Map<String, double> _avgByHotelId = {};
  final Map<String, int> _countByHotelId = {};
  String? _lastRatingsKey;

  // Recherche
  String searchQuery = '';

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();

    // 0) mémoire global (instant)
    if (_memoryCacheHotels.isNotEmpty) {
      hotels = List<Map<String, dynamic>>.from(_memoryCacheHotels);
      filteredHotels = hotels;
      _hasAnyCache = true;
    }

    // 1) cache disque (Hive/AppCache) + 2) sync réseau SWR
    _loadAllSWR();
  }

  @override
  bool get wantKeepAlive => true;

  // ------- format prix (espaces) -------
  String _formatGNF(dynamic value) {
    if (value == null) return '—';
    final n = (value is num)
        ? value.toInt()
        : int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  // ---------------- Localisation (non bloquante) ----------------
  Future<void> _getLocationNonBlocking() async {
    _position = null;
    _villeGPS = null;
    _locationDenied = false;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      // last known = instant
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _position = last;
        unawaited(_resolveCity(last));
        _recomputeDistancesAndSort();
      }

      // permission + position fraîche (en fond)
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationDenied = true;
        if (mounted) setState(() {});
        return;
      }

      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
          .then((pos) async {
        _position = pos;
        unawaited(GeolocService.reportPosition(pos));
        await _resolveCity(pos);
        _recomputeDistancesAndSort();
      }).catchError((_) {});
    } catch (_) {
      // silencieux
    }
  }

  Future<void> _resolveCity(Position pos) async {
    try {
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
    } catch (_) {}
  }

  // ⚠️ On NE TOUCHE PAS à ta logique de distance
  double? _distanceMeters(
      double? lat1, double? lon1, double? lat2, double? lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }
    const R = 6371000.0;
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon1 - lon2) * (pi / 180);
    dLon = -dLon;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // ========= tri (villeGPS puis distance puis nom) =========
  void _sortHotelsInPlace(List<Map<String, dynamic>> list) {
    int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());

    if (_position != null) {
      for (final h in list) {
        final lat = (h['latitude'] as num?)?.toDouble();
        final lon = (h['longitude'] as num?)?.toDouble();
        h['_distance'] = _distanceMeters(
            _position!.latitude, _position!.longitude, lat, lon);
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
    } else {
      list.sort(byName);
    }
  }

  void _recomputeDistancesAndSort() {
    if (hotels.isEmpty) return;
    final list = hotels.map((e) => Map<String, dynamic>.from(e)).toList();
    _sortHotelsInPlace(list);
    hotels = list;
    _filterHotels(searchQuery, setStateNow: true);
  }

  // --------- ⭐️ moyennes en batch (évite filtre OR énorme) ----------
  Future<void> _preloadAveragesBatched(List<String> ids) async {
    _avgByHotelId.clear();
    _countByHotelId.clear();
    if (ids.isEmpty) return;

    final key = ids.join(',');
    if (key == _lastRatingsKey) return;
    _lastRatingsKey = key;

    try {
      const int batchSize = 20;
      final Map<String, double> sums = {};
      final Map<String, int> counts = {};

      for (var i = 0; i < ids.length; i += batchSize) {
        final batch = ids.sublist(i, min(i + batchSize, ids.length));
        final orFilter = batch.map((id) => 'hotel_id.eq.$id').join(',');

        final rows = await Supabase.instance.client
            .from('avis_hotels')
            .select('hotel_id, etoiles')
            .or(orFilter);

        final list = List<Map<String, dynamic>>.from(rows);
        for (final r in list) {
          final id = (r['hotel_id'] ?? '').toString();
          final n = (r['etoiles'] as num?)?.toDouble() ?? 0.0;
          if (id.isEmpty || n <= 0) continue;
          sums[id] = (sums[id] ?? 0.0) + n;
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        for (final id in counts.keys) {
          final c = counts[id] ?? 0;
          final s = sums[id] ?? 0.0;
          _avgByHotelId[id] = c > 0 ? (s / c) : 0.0;
          _countByHotelId[id] = c;
        }
      });
    } catch (_) {}
  }

  // ----------------- Filtre -----------------
  void _filterHotels(String value, {bool setStateNow = false}) {
    final q = value.toLowerCase().trim();
    searchQuery = value;

    if (q.isEmpty) {
      filteredHotels = hotels;
    } else {
      filteredHotels = hotels.where((hotel) {
        final nom = (hotel['nom'] ?? '').toString().toLowerCase();
        final ville = (hotel['ville'] ?? '').toString().toLowerCase();
        return nom.contains(q) || ville.contains(q);
      }).toList();
    }

    if (setStateNow && mounted) setState(() {});
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return const [];
  }

  // ===================== colonnes + ratio (même logique que Restaurants) =====================
  int _columnsForWidth(double w) {
    if (w >= 1600) return 6;
    if (w >= 1400) return 5;
    if (w >= 1100) return 4;
    if (w >= 800) return 3;
    return 2;
  }

  // ✅✅✅ IMPORTANT : on aligne la carte Hôtel sur Restaurants => image 4/3
  double _ratioFor(
      double screenWidth, int cols, double spacing, double paddingH) {
    final usableWidth = screenWidth - paddingH * 2 - spacing * (cols - 1);
    final itemWidth = usableWidth / cols;

    // ✅ image 4/3 (même forme que Restaurants)
    final imageH = itemWidth * (3 / 4);

    // hauteur zone texte (compacte) : inchangé
    double infoH;
    if (itemWidth < 220) {
      infoH = 134;
    } else if (itemWidth < 280) {
      infoH = 126;
    } else if (itemWidth < 340) {
      infoH = 120;
    } else {
      infoH = 116;
    }

    final totalH = imageH + infoH;
    return itemWidth / totalH;
  }

  // ===================== Premium placeholder (même rendu) =====================
  Widget _imagePremiumPlaceholder() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.60),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, v, __) {
        return Container(
          color:
              Color.lerp(const Color(0xFFE5E7EB), const Color(0xFFF3F4F6), v),
        );
      },
    );
  }

  // ======================= Hive snapshot helpers =======================
  List<Map<String, dynamic>>? _readHiveSnapshot() {
    try {
      if (!Hive.isBoxOpen(_hiveBoxName)) return null;
      final box = Hive.box(_hiveBoxName);
      final raw = box.get(_hiveKey);
      if (raw is! Map) return null;

      final ts = raw['ts'] as int?;
      final data = raw['data'] as List?;
      if (ts == null || data == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _CACHE_MAX_AGE.inMilliseconds) return null;

      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeHiveSnapshot(List<Map<String, dynamic>> list) async {
    try {
      if (!Hive.isBoxOpen(_hiveBoxName)) return;
      await Hive.box(_hiveBoxName).put(_hiveKey, {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': list,
      });
    } catch (_) {}
  }

  // ======================= CHARGEMENT SWR — instantané & sync réseau =======================
  Future<void> _loadAllSWR({bool forceNetwork = false}) async {
    // Ouvre Hive si nécessaire (non bloquant)
    if (!Hive.isBoxOpen(_hiveBoxName)) {
      unawaited(Hive.openBox(_hiveBoxName));
    }

    // 1) Snapshot cache (instant) si pas forcé
    if (!forceNetwork) {
      // a) mémoire global déjà appliquée initState
      // b) Hive
      if (!_hasAnyCache) {
        final hiveSnap = _readHiveSnapshot();
        if (hiveSnap != null && hiveSnap.isNotEmpty) {
          hotels = hiveSnap;
          _memoryCacheHotels = List<Map<String, dynamic>>.from(hiveSnap);
          _hasAnyCache = true;
          _filterHotels(searchQuery);
          if (mounted) setState(() {});
        }
      }

      // c) AppCache (mémoire/disque) si toujours rien
      if (!_hasAnyCache) {
        final mem =
            AppCache.I.getListMemory(_CACHE_KEY, maxAge: _CACHE_MAX_AGE);
        List<Map<String, dynamic>>? disk;
        if (mem == null) {
          disk = await AppCache.I
              .getListPersistent(_CACHE_KEY, maxAge: _CACHE_MAX_AGE);
        }
        final snapshot = mem ?? disk;
        if (snapshot != null && snapshot.isNotEmpty) {
          hotels = snapshot.map((e) => Map<String, dynamic>.from(e)).toList();
          _memoryCacheHotels = List<Map<String, dynamic>>.from(hotels);
          _hasAnyCache = true;
          _filterHotels(searchQuery);
          if (mounted) setState(() {});
        }
      }
    }

    // 2) localisation en parallèle (ne bloque jamais l’UI)
    unawaited(_getLocationNonBlocking());

    // 3) réseau en arrière-plan
    try {
      if (mounted) setState(() => _syncing = true);

      final data = await Supabase.instance.client.from('hotels').select('''
        id, nom, ville, adresse, prix,
        latitude, longitude, images, description, created_at
      ''');

      final list = List<Map<String, dynamic>>.from(data);

      // Affichage immédiat : tri nom (rapide)
      list.sort((a, b) =>
          (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString()));

      hotels = list;
      _memoryCacheHotels = List<Map<String, dynamic>>.from(list);
      _hasAnyCache = true;
      _filterHotels(searchQuery);

      if (mounted) setState(() {});

      // Après affichage : tri distance/ville si on a position
      _recomputeDistancesAndSort();

      // Notes moyennes (après rendu)
      final ids = hotels
          .map((e) => (e['id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
      unawaited(_preloadAveragesBatched(ids));

      // Persist caches (sans _distance)
      final toCache = hotels.map((h) {
        final clone = Map<String, dynamic>.from(h);
        clone.remove('_distance');
        return clone;
      }).toList(growable: false);

      AppCache.I.setList(_CACHE_KEY, toCache, persist: true);
      await _writeHiveSnapshot(toCache);
    } catch (_) {
      // silencieux : si cache présent, on ne gêne pas
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ===================== Skeleton grid (même taille de carte) =====================
  Widget _skeletonGrid(
      int crossCount, double ratio, double spacing, double padH) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: ratio,
      ),
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: 4),
      itemCount: 8,
      itemBuilder: (_, __) => const _HotelSkeletonCardTight(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // clamp léger du textScale
    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);

    // ✅ même grille / spacing / padding que Restaurants
    final screenW = media.size.width;
    final gridCols = _columnsForWidth(screenW);
    const double gridSpacing = 4.0;
    const double gridHPadding = 6.0;
    final ratio = _ratioFor(screenW, gridCols, gridSpacing, gridHPadding);

    final coldStart = !_hasAnyCache && hotels.isEmpty;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: neutralBg,
        appBar: AppBar(
          backgroundColor: neutralSurface,
          elevation: 1,
          foregroundColor: hotelsPrimary,
          title: Row(
            children: [
              const Text(
                'Hôtels',
                style: TextStyle(
                    color: hotelsPrimary, fontWeight: FontWeight.bold),
              ),
              if (_syncing) const SizedBox(width: 8),
              if (_syncing)
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: hotelsPrimary),
              tooltip: 'Rafraîchir',
              onPressed: () => _loadAllSWR(forceNetwork: true),
            ),
          ],
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
        body: coldStart
            ? _skeletonGrid(gridCols, ratio, gridSpacing, gridHPadding)
            : (hotels.isEmpty
                ? const Center(child: Text("Aucun hôtel trouvé."))
                : Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Column(
                      children: [
                        // Bandeau
                        Container(
                          width: double.infinity,
                          height: 75,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [hotelsPrimary, hotelsSecondary],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Trouvez l'hôtel parfait partout en Guinée",
                                style: TextStyle(
                                  color: onPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Barre de recherche
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Rechercher un hôtel, une ville...',
                            prefixIcon:
                                const Icon(Icons.search, color: hotelsPrimary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: neutralBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: neutralBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: hotelsSecondary, width: 1.5),
                            ),
                            filled: true,
                            fillColor: neutralSurface,
                          ),
                          onChanged: (v) => setState(() => _filterHotels(v)),
                        ),
                        const SizedBox(height: 10),

                        if (_locationDenied)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Active la localisation pour afficher la distance.",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          ),

                        // Grille
                        Expanded(
                          child: filteredHotels.isEmpty
                              ? const Center(child: Text("Aucun hôtel trouvé."))
                              : GridView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridCols,
                                    mainAxisSpacing: gridSpacing,
                                    crossAxisSpacing: gridSpacing,
                                    childAspectRatio: ratio,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: gridHPadding, vertical: 4),
                                  cacheExtent: 900,
                                  itemCount: filteredHotels.length,
                                  itemBuilder: (context, index) {
                                    final hotel = filteredHotels[index];
                                    final id = (hotel['id'] ?? '').toString();

                                    final avg = _avgByHotelId[id]; // nullable
                                    final count = _countByHotelId[id] ?? 0;

                                    final images = _imagesFrom(hotel['images']);
                                    final image = images.isNotEmpty
                                        ? images.first
                                        : 'https://via.placeholder.com/600x400.png?text=H%C3%B4tel';

                                    final prixRaw = hotel['prix'];
                                    final hasPrix = prixRaw != null &&
                                        prixRaw.toString().trim().isNotEmpty &&
                                        _formatGNF(prixRaw) != '—';

                                    return _HotelCardTight(
                                      hotel: hotel,
                                      imageUrl: image,
                                      avg: avg,
                                      count: count,
                                      hasPrix: hasPrix,
                                      priceLabel: hasPrix
                                          ? 'Prix : ${_formatGNF(prixRaw)} GNF / nuit'
                                          : null,
                                      placeholder: _imagePremiumPlaceholder,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => HotelDetailPage(
                                              hotelId: hotel['id']),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  )),
      ),
    );
  }
}

// ======================== Carte Tight (même “forme” que Restaurants) ===========================
class _HotelCardTight extends StatelessWidget {
  final Map<String, dynamic> hotel;
  final String imageUrl;

  final double? avg;
  final int count;

  final bool hasPrix;
  final String? priceLabel;

  final Widget Function() placeholder;
  final VoidCallback onTap;

  const _HotelCardTight({
    required this.hotel,
    required this.imageUrl,
    required this.avg,
    required this.count,
    required this.hasPrix,
    required this.priceLabel,
    required this.placeholder,
    required this.onTap,
  });

  static const Color hotelsPrimary = _HotelPageState.hotelsPrimary;
  static const Color hotelsSecondary = _HotelPageState.hotelsSecondary;
  static const Color neutralBorder = _HotelPageState.neutralBorder;
  static const Color neutralSurface = _HotelPageState.neutralSurface;

  @override
  Widget build(BuildContext context) {
    final city = (hotel['ville'] ?? '').toString();
    final dist = (hotel['_distance'] as double?);

    return InkWell(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.0,
        color: neutralSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: neutralBorder),
        ),
        // ✅✅✅ comme Restaurants (clip net)
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅✅✅ Image 4/3 (même forme que Restaurants) -> plus de déformation
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (ctx, c) {
                      final dpr = MediaQuery.of(ctx).devicePixelRatio;
                      final w = c.maxWidth;
                      final h = c.maxHeight;
                      final memW =
                          (w.isFinite && w > 0) ? (w * dpr).round() : null;
                      final memH =
                          (h.isFinite && h > 0) ? (h * dpr).round() : null;

                      return _HotelCachedImage(
                        url: imageUrl,
                        memW: memW,
                        memH: memH,
                        placeholder: placeholder,
                      );
                    },
                  ),

                  // badge ville (style restaurants)
                  if (city.trim().isNotEmpty)
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
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ✅ Texte compact (inchangé)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (hotel['nom'] ?? 'Sans nom').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.15,
                        color: hotelsPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              height: 1.0,
                            ),
                          ),
                        ),
                        if (dist != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${(dist / 1000).toStringAsFixed(1)} km',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (priceLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        priceLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: hotelsSecondary,
                          fontSize: 12,
                          height: 1.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        _HotelStars(avg: avg),
                        const SizedBox(width: 6),
                        Text(
                          (avg == null || count == 0)
                              ? '—'
                              : avg!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hotelsPrimary,
                            height: 1.0,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '($count)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- Cached image premium (sans spinner) -----------------
class _HotelCachedImage extends StatelessWidget {
  final String url;
  final int? memW;
  final int? memH;
  final Widget Function() placeholder;

  const _HotelCachedImage({
    required this.url,
    this.memW,
    this.memH,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    return CachedNetworkImage(
      imageUrl: u,
      cacheKey: u,
      memCacheWidth: memW,
      memCacheHeight: memH,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      imageBuilder: (_, provider) => Image(
        image: provider,
        fit: BoxFit.cover, // ✅ cover (pas de déformation)
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      ),
      placeholder: (_, __) => placeholder(),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFFE5E7EB),
        alignment: Alignment.center,
        child: Icon(Icons.broken_image, size: 40, color: Colors.grey.shade500),
      ),
    );
  }
}

// ----------------- Stars (compact) -----------------
class _HotelStars extends StatelessWidget {
  final double? avg;
  const _HotelStars({this.avg});

  @override
  Widget build(BuildContext context) {
    final n = ((avg ?? 0).round()).clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < n ? Icons.star : Icons.star_border,
          size: 14,
          color: Colors.amber,
        ),
      ),
    );
  }
}

// ------------------ Skeleton Card (même taille / même padding) --------------------
class _HotelSkeletonCardTight extends StatelessWidget {
  const _HotelSkeletonCardTight();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: _HotelPageState.neutralSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _HotelPageState.neutralBorder),
      ),
      elevation: 1.0,
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅✅✅ Skeleton aligné sur 4/3 (comme Restaurants)
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(color: const Color(0xFFE5E7EB)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 12,
                      width: double.infinity,
                      color: const Color(0xFFE5E7EB)),
                  const SizedBox(height: 6),
                  Container(
                      height: 10, width: 120, color: const Color(0xFFE5E7EB)),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                          height: 10,
                          width: 90,
                          color: const Color(0xFFE5E7EB)),
                      const SizedBox(width: 6),
                      Container(
                          height: 10,
                          width: 34,
                          color: const Color(0xFFE5E7EB)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
