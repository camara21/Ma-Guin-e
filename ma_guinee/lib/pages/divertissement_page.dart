// lib/pages/divertissement_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/app_cache.dart';
import '../services/geoloc_service.dart';
import 'divertissement_detail_page.dart';

class DivertissementPage extends StatefulWidget {
  const DivertissementPage({super.key});

  @override
  State<DivertissementPage> createState() => _DivertissementPageState();
}

class _DivertissementPageState extends State<DivertissementPage>
    with AutomaticKeepAliveClientMixin {
  // Couleurs
  static const Color primaryColor = Color(0xFF7B1FA2);
  static const Color secondaryColor = Color(0xFF00C9FF);
  static const Color onPrimary = Colors.white;

  static const Color _neutralBg = Color(0xFFF7F7F9);
  static const Color _neutralSurface = Color(0xFFFFFFFF);
  static const Color _neutralBorder = Color(0xFFE5E7EB);

  // Cache (AppCache)
  static const String _cacheKey = 'divertissement:list:v1';
  static const Duration _memMaxAge = Duration(days: 7);
  static const Duration _diskMaxAge = Duration(days: 14);

  // ✅ Cache mémoire global (retour écran instant)
  static List<Map<String, dynamic>> _memoryCache = [];

  // ✅ Hive persistant (relance app instant)
  static const String _hiveBoxName = 'lieux_box';
  static const String _hiveKey = 'divertissement_snapshot_v1';

  // Données
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _lieux = [];
  List<Map<String, dynamic>> _filtered = [];

  // État
  bool _loading = true; // skeleton si cold start sans cache
  bool _syncing = false; // sync réseau silencieuse
  bool _hasAnyCache = false;

  // Recherche (debounce)
  Timer? _debounce;

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();

    // 0) cache mémoire global (instant)
    if (_memoryCache.isNotEmpty) {
      _lieux = _memoryCache.map((e) => Map<String, dynamic>.from(e)).toList();
      _applyFilter(_searchCtrl.text, setStateNow: false);
      _hasAnyCache = true;
      _loading = false;
    }

    _loadAllSWR(); // cache instantané + sync réseau
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // ====== Distance précise (Haversine) ======
  double? _distanceMeters(
      double? lat1, double? lon1, double? lat2, double? lon2) {
    if ([lat1, lon1, lat2, lon2].any((v) => v == null)) return null;

    const R = 6371000.0;
    final dLat = (lat2! - lat1!) * (pi / 180.0);
    final dLon = (lon2! - lon1!) * (pi / 180.0);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ---------- Hive snapshot helpers ----------
  List<Map<String, dynamic>>? _readHiveSnapshot() {
    try {
      if (!Hive.isBoxOpen(_hiveBoxName)) return null;
      final box = Hive.box(_hiveBoxName);
      final raw = box.get(_hiveKey);
      if (raw is! Map) return null;

      final ts = raw['ts'] as int?;
      final data = raw['data'] as List?;
      if (ts == null || data == null) return null;

      final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
      if (ageMs > _diskMaxAge.inMilliseconds) return null;

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

  // ---------- Localisation non bloquante ----------
  Future<void> _getLocationNonBlocking() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        _locationDenied = true;
        if (mounted) setState(() {});
        return;
      }

      // 1) last known → instantané
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _position = last;
        unawaited(_resolveCity(last));
        _recomputeDistancesAndSort();
      }

      // 2) position actuelle → en arrière-plan
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
          .then((pos) async {
        _position = pos;
        unawaited(GeolocService.reportPosition(pos));
        await _resolveCity(pos);
        _recomputeDistancesAndSort();
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<void> _resolveCity(Position pos) async {
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final city = (m.locality?.isNotEmpty == true)
            ? m.locality
            : (m.subAdministrativeArea?.isNotEmpty == true
                ? m.subAdministrativeArea
                : null);
        _villeGPS = city?.toLowerCase().trim();
      }
    } catch (_) {}
  }

  // ---------- Ratings batched (évite join lourd) ----------
  Future<void> _fillRatingsFor(List<Map<String, dynamic>> list) async {
    final ids = list
        .map((e) => (e['id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    try {
      const int batchSize = 20;
      final Map<String, int> sum = {};
      final Map<String, int> cnt = {};

      for (var i = 0; i < ids.length; i += batchSize) {
        final batch = ids.sublist(i, min(i + batchSize, ids.length));
        final orFilter = batch.map((id) => 'lieu_id.eq.$id').join(',');

        final rows = await Supabase.instance.client
            .from('avis_lieux')
            .select('lieu_id, etoiles')
            .or(orFilter);

        for (final r in List<Map<String, dynamic>>.from(rows)) {
          final id = (r['lieu_id'] ?? '').toString();
          final n = (r['etoiles'] as num?)?.toInt() ?? 0;
          if (id.isEmpty || n <= 0) continue;
          sum[id] = (sum[id] ?? 0) + n;
          cnt[id] = (cnt[id] ?? 0) + 1;
        }
      }

      // injecte _avg / _count dans les items (compat avec ton UI existant)
      for (final l in list) {
        final id = (l['id'] ?? '').toString();
        final c = cnt[id] ?? 0;
        l['_count'] = c;
        l['_avg'] = (c == 0) ? null : (sum[id]! / c);
      }
    } catch (_) {
      // silencieux
    }
  }

  // ---------- Tri (même ville > distance > nom) ----------
  void _sortByDistance(List<Map<String, dynamic>> arr) {
    int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());

    if ((_villeGPS ?? '').isNotEmpty) {
      arr.sort((a, b) {
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
      arr.sort((a, b) {
        final ad = (a['_distance'] as double?);
        final bd = (b['_distance'] as double?);
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return byName(a, b);
      });
    }
  }

  // ---------- SWR : cache instantané + sync réseau ----------
  Future<void> _loadAllSWR({bool forceNetwork = false}) async {
    // anti double-call
    if (_syncing) return;

    // ouvre Hive si besoin (non bloquant)
    if (!Hive.isBoxOpen(_hiveBoxName)) {
      unawaited(Hive.openBox(_hiveBoxName));
    }

    // 1) snapshot cache (instant) si pas forcé
    if (!forceNetwork) {
      if (!_hasAnyCache) {
        // a) Hive
        final hiveSnap = _readHiveSnapshot();
        if (hiveSnap != null && hiveSnap.isNotEmpty) {
          _lieux = hiveSnap.map((e) => Map<String, dynamic>.from(e)).toList();
          _memoryCache =
              _lieux.map((e) => Map<String, dynamic>.from(e)).toList();
          _applyFilter(_searchCtrl.text, setStateNow: false);
          _hasAnyCache = true;
          _loading = false;
          if (mounted) setState(() {});
        }
      }

      // b) AppCache (mémoire/disque)
      if (!_hasAnyCache) {
        final mem = AppCache.I.getListMemory(_cacheKey, maxAge: _memMaxAge);
        List<Map<String, dynamic>>? disk;
        if (mem == null) {
          disk = await AppCache.I
              .getListPersistent(_cacheKey, maxAge: _diskMaxAge);
        }
        final snapshot = mem ?? disk;

        if (snapshot != null && snapshot.isNotEmpty) {
          _lieux = snapshot.map((e) => Map<String, dynamic>.from(e)).toList();
          _memoryCache =
              _lieux.map((e) => Map<String, dynamic>.from(e)).toList();
          _applyFilter(_searchCtrl.text, setStateNow: false);
          _hasAnyCache = true;
          _loading = false;
          if (mounted) setState(() {});
        } else {
          if (mounted && !_hasAnyCache) setState(() => _loading = true);
        }
      }
    } else {
      // refresh manuel : pas de skeleton global
      if (mounted) setState(() => _loading = _hasAnyCache ? false : true);
    }

    // 2) localisation en parallèle (non bloquante)
    unawaited(_getLocationNonBlocking());

    // 3) réseau (SWR) en arrière-plan
    if (mounted) setState(() => _syncing = true);

    try {
      final response = await Supabase.instance.client.from('lieux').select('''
        id, nom, ville, type, categorie, description,
        images, latitude, longitude, adresse, created_at
      ''').eq('type', 'divertissement').order('nom', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);

      // distances si on a déjà une position
      if (_position != null) {
        for (final l in list) {
          final lat = (l['latitude'] as num?)?.toDouble();
          final lon = (l['longitude'] as num?)?.toDouble();
          l['_distance'] = _distanceMeters(
            _position!.latitude,
            _position!.longitude,
            lat,
            lon,
          );
        }
        _sortByDistance(list);
      }

      // affiche tout de suite (sans attendre les ratings)
      _lieux = list;
      _memoryCache = list.map((e) => Map<String, dynamic>.from(e)).toList();
      _applyFilter(_searchCtrl.text, setStateNow: false);
      _hasAnyCache = true;
      _loading = false;
      if (mounted) setState(() {});

      // ratings en fond (puis re-cache)
      unawaited(() async {
        await _fillRatingsFor(list);

        // persist caches (retire champs volatils)
        final toCache = list.map((e) {
          final c = Map<String, dynamic>.from(e);
          c.remove('_distance');
          return c;
        }).toList(growable: false);

        AppCache.I.setList(_cacheKey, toCache, persist: true);
        await _writeHiveSnapshot(toCache);

        // update UI (si encore là)
        if (!mounted) return;
        _applyFilter(_searchCtrl.text, setStateNow: false);
        setState(() {});
      }());
    } catch (e) {
      debugPrint('Erreur réseau divertissement: $e');
      if (mounted && !_hasAnyCache) {
        _loading = false;
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _recomputeDistancesAndSort() {
    if (_lieux.isEmpty || _position == null) {
      if (mounted) setState(() {});
      return;
    }

    for (final l in _lieux) {
      final lat = (l['latitude'] as num?)?.toDouble();
      final lon = (l['longitude'] as num?)?.toDouble();
      l['_distance'] = _distanceMeters(
        _position!.latitude,
        _position!.longitude,
        lat,
        lon,
      );
    }

    _sortByDistance(_lieux);
    _applyFilter(_searchCtrl.text, setStateNow: true);
  }

  // ---------- Filtre ----------
  void _applyFilter(String value, {bool setStateNow = true}) {
    final q = value.toLowerCase().trim();
    final filtered = q.isEmpty
        ? _lieux
        : _lieux.where((lieu) {
            final nom = (lieu['nom'] ?? '').toString().toLowerCase();
            final ville = (lieu['ville'] ?? '').toString().toLowerCase();
            final tag =
                (lieu['type'] ?? lieu['categorie'] ?? lieu['description'] ?? '')
                    .toString()
                    .toLowerCase();
            return nom.contains(q) || ville.contains(q) || tag.contains(q);
          }).toList();

    _filtered = filtered;
    if (setStateNow && mounted) setState(() {});
  }

  // ---------- Helpers ----------
  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  Widget _skeletonGrid(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
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
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);

    final screenW = media.size.width;
    final crossCount = screenW < 600
        ? max(2, (screenW / 200).floor())
        : max(3, (screenW / 240).floor());
    final totalHGap = (crossCount - 1) * 8.0 + 16.0;
    final itemW = (screenW - totalHGap) / crossCount;
    final itemH = itemW * (11 / 16) + 112.0;
    final ratio = itemW / itemH;

    final subtitleInfo = (_position != null && _villeGPS != null)
        ? 'Autour de ${_villeGPS!.isEmpty ? "vous" : _villeGPS}'
        : (_locationDenied ? 'Localisation refusée — tri par défaut' : null);

    final coldStart = !_hasAnyCache && _loading;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: _neutralBg,
        appBar: AppBar(
          title: const Text(
            'Divertissement',
            style: TextStyle(color: onPrimary, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          elevation: 1.2,
          actions: [
            if (_syncing)
              const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => _loadAllSWR(forceNetwork: true),
                tooltip: 'Rafraîchir',
              ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(3),
            child: SizedBox(
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Bandeau
            Padding(
              padding: const EdgeInsets.only(
                  left: 12, right: 12, top: 12, bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Bars, clubs, lounges et sorties en Guinée",
                            style: TextStyle(
                              color: onPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (subtitleInfo != null)
                            Text(
                              subtitleInfo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: const TextStyle(
                                color: onPrimary,
                                fontSize: 12,
                                height: 1.1,
                                decoration: TextDecoration.none,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Recherche (debounce)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Rechercher un lieu, une catégorie, une ville...',
                  prefixIcon: const Icon(Icons.search, color: primaryColor),
                  filled: true,
                  fillColor: _neutralSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (txt) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 230), () {
                    _applyFilter(txt);
                  });
                },
              ),
            ),
            const SizedBox(height: 6),

            // Grille
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: coldStart
                    ? _skeletonGrid(context)
                    : (_filtered.isEmpty
                        ? const Center(child: Text("Aucun lieu trouvé."))
                        : RefreshIndicator(
                            onRefresh: () => _loadAllSWR(forceNetwork: true),
                            child: GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: ratio,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              cacheExtent: 900,
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final lieu = _filtered[index];
                                final images = _imagesFrom(lieu['images']);
                                final image = images.isNotEmpty
                                    ? images.first
                                    : 'https://via.placeholder.com/300x200.png?text=Divertissement';

                                final String tag =
                                    (lieu['type'] ?? lieu['categorie'] ?? '')
                                        .toString();
                                final double? avg =
                                    (lieu['_avg'] as num?)?.toDouble();
                                final int nb = (lieu['_count'] as int?) ?? 0;

                                return _LieuCardTight(
                                  lieu: lieu,
                                  imageUrl: image,
                                  tag: tag,
                                  avg: avg,
                                  nbAvis: nb,
                                );
                              },
                            ),
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================== Carte ===========================
class _LieuCardTight extends StatelessWidget {
  final Map<String, dynamic> lieu;
  final String imageUrl;
  final String tag;
  final double? avg;
  final int nbAvis;

  const _LieuCardTight({
    required this.lieu,
    required this.imageUrl,
    required this.tag,
    required this.avg,
    required this.nbAvis,
  });

  static const Color primaryColor = _DivertissementPageState.primaryColor;
  static const Color _neutralSurface = _DivertissementPageState._neutralSurface;
  static const Color _neutralBorder = _DivertissementPageState._neutralBorder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DivertissementDetailPage(lieu: lieu)),
        );
      },
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _neutralBorder),
        ),
        elevation: 1.5,
        color: _neutralSurface,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE (premium, sans spinner)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final w = constraints.maxWidth;
                  final h = w * (11 / 16);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheKey: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: w.isFinite ? (w * dpr).round() : null,
                        memCacheHeight: h.isFinite ? (h * dpr).round() : null,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholderFadeInDuration: Duration.zero,
                        useOldImageOnUrlChange: true,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey.shade200),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: Icon(Icons.broken_image,
                              size: 40, color: Colors.grey.shade500),
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
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 140),
                                  child: Text(
                                    (lieu['ville'] ?? '').toString(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (lieu['ville'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                      if (lieu['_distance'] != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${(lieu['_distance'] / 1000).toStringAsFixed(1)} km',
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  if (tag.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        _Stars(avg: avg),
                        Text(
                          avg == null
                              ? 'Aucune note'
                              : '${avg!.toStringAsFixed(2)} / 5',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '($nbAvis avis)',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
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

class _Stars extends StatelessWidget {
  final double? avg;
  const _Stars({this.avg});

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
          color: _DivertissementPageState.primaryColor,
        ),
      ),
    );
  }
}

// ------------------ Skeleton Card --------------------
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
              aspectRatio: 16 / 11,
              child: ColoredBox(color: Color(0xFFE5E7EB))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 14, width: 140, color: const Color(0xFFE5E7EB)),
                const SizedBox(height: 6),
                Container(
                    height: 12, width: 90, color: const Color(0xFFE5E7EB)),
                const SizedBox(height: 6),
                Container(
                    height: 12, width: 70, color: const Color(0xFFE5E7EB)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
