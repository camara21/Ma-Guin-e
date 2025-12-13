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

  static const LinearGradient _topGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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
  Timer? _debounce;

  List<Map<String, dynamic>> _lieux = [];
  List<Map<String, dynamic>> _filtered = [];

  // État
  bool _loading = true; // skeleton si cold start sans cache
  bool _syncing = false; // sync réseau silencieuse
  bool _hasAnyCache = false;

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

  // ---------- Grid responsive (même carte que Santé/Tourisme) ----------
  int _columnsForWidth(double w) {
    if (w >= 1600) return 6;
    if (w >= 1400) return 5;
    if (w >= 1100) return 4;
    if (w >= 800) return 3;
    return 2;
  }

  double _ratioFor(
      double screenWidth, int cols, double spacing, double paddingH) {
    final usableWidth = screenWidth - paddingH * 2 - spacing * (cols - 1);
    final itemWidth = usableWidth / cols;

    final imageH = itemWidth * (3 / 4); // ✅ image 4/3
    double infoH;
    if (itemWidth < 220) {
      infoH = 118;
    } else if (itemWidth < 280) {
      infoH = 112;
    } else if (itemWidth < 340) {
      infoH = 108;
    } else {
      infoH = 104;
    }

    final totalH = imageH + infoH;
    return itemWidth / totalH;
  }

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

      for (final l in list) {
        final id = (l['id'] ?? '').toString();
        final c = cnt[id] ?? 0;
        l['_count'] = c;
        l['_avg'] = (c == 0) ? null : (sum[id]! / c);
      }
    } catch (_) {}
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
    if (_syncing) return;

    if (!Hive.isBoxOpen(_hiveBoxName)) {
      unawaited(Hive.openBox(_hiveBoxName));
    }

    if (!forceNetwork) {
      // Hive snapshot prioritaire si pas de cache affiché
      if (!_hasAnyCache) {
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

      // AppCache fallback (mémoire/disque)
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
      if (mounted) setState(() => _loading = _hasAnyCache ? false : true);
    }

    // localisation en parallèle
    unawaited(_getLocationNonBlocking());

    if (mounted) setState(() => _syncing = true);

    try {
      final response = await Supabase.instance.client.from('lieux').select('''
        id, nom, ville, type, categorie, description,
        images, latitude, longitude, adresse, created_at
      ''').eq('type', 'divertissement').order('nom', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);

      // distance + tri si position dispo
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

      _lieux = list;
      _memoryCache = list.map((e) => Map<String, dynamic>.from(e)).toList();
      _applyFilter(_searchCtrl.text, setStateNow: false);
      _hasAnyCache = true;
      _loading = false;
      if (mounted) setState(() {});

      // ratings + persist caches
      unawaited(() async {
        await _fillRatingsFor(list);

        final toCache = list.map((e) {
          final c = Map<String, dynamic>.from(e);
          c.remove('_distance');
          return c;
        }).toList(growable: false);

        AppCache.I.setList(_cacheKey, toCache, persist: true);
        await _writeHiveSnapshot(toCache);

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

  // ---------- Images ----------
  bool _validUrl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final u = Uri.tryParse(s.trim());
    return u != null && (u.isScheme('http') || u.isScheme('https'));
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => _validUrl(s))
          .toList();
    }
    if (raw is String && _validUrl(raw)) return [raw.trim()];
    return const [];
  }

  // ---------- UI images premium (même que Santé/Tourisme) ----------
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

  Widget _premiumImage(String url) {
    return LayoutBuilder(
      builder: (context, c) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final w = c.maxWidth.isFinite ? c.maxWidth : 360.0;
        final h = c.maxHeight.isFinite ? c.maxHeight : 240.0;

        final safeUrl = _validUrl(url)
            ? url.trim()
            : 'https://via.placeholder.com/600x400?text=Divertissement';

        return CachedNetworkImage(
          key: ValueKey('divert_img_$safeUrl'),
          imageUrl: safeUrl,
          cacheKey: safeUrl,
          memCacheWidth: (w * dpr).round(),
          memCacheHeight: (h * dpr).round(),
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          imageBuilder: (_, provider) => Image(
            image: provider,
            fit: BoxFit.cover, // ✅ pas déformé
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          ),
          placeholder: (_, __) => _imagePremiumPlaceholder(),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFFE5E7EB),
            alignment: Alignment.center,
            child: Icon(Icons.nightlife,
                size: 44, color: primaryColor.withOpacity(.35)),
          ),
        );
      },
    );
  }

  Widget _stars(double value, {double size = 14}) {
    final full = value.floor().clamp(0, 5);
    final half = (value - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return Icon(Icons.star, size: size, color: Colors.amber);
        if (i == full && half) {
          return Icon(Icons.star_half, size: size, color: Colors.amber);
        }
        return Icon(Icons.star_border, size: size, color: Colors.amber);
      }),
    );
  }

  // ---------- Skeleton ----------
  Widget _skeletonGrid(
      int cols, double ratio, double spacing, double paddingH) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: ratio,
      ),
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: 4),
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

    final gridCols = _columnsForWidth(screenW);
    const double gridSpacing = 4.0;
    const double gridHPadding = 6.0;
    final ratio = _ratioFor(screenW, gridCols, gridSpacing, gridHPadding);

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
                  decoration: BoxDecoration(gradient: _topGradient)),
            ),
          ),
        ),
        body: Column(
          children: [
            // ✅ Bandeau (sans overflow)
            Padding(
              padding: const EdgeInsets.only(
                  left: 12, right: 12, top: 12, bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 72),
                  decoration: const BoxDecoration(gradient: _topGradient),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Bars, clubs, lounges et sorties en Guinée",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      if (subtitleInfo != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitleInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: onPrimary,
                            fontSize: 12,
                            height: 1.05,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Recherche (debounce)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un lieu, une ville, une catégorie…',
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  filled: true,
                  fillColor: _neutralSurface,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: _neutralBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: _neutralBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: primaryColor, width: 1.4),
                  ),
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

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: coldStart
                    ? _skeletonGrid(gridCols, ratio, gridSpacing, gridHPadding)
                    : (_filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 200),
                              Center(child: Text("Aucun lieu trouvé.")),
                            ],
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadAllSWR(forceNetwork: true),
                            child: GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridCols,
                                mainAxisSpacing: gridSpacing,
                                crossAxisSpacing: gridSpacing,
                                childAspectRatio: ratio,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: gridHPadding,
                                vertical: 4,
                              ),
                              cacheExtent: 900,
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final lieu = _filtered[index];

                                final images = _imagesFrom(lieu['images']);
                                final img = images.isNotEmpty
                                    ? images.first
                                    : 'https://via.placeholder.com/600x400?text=Divertissement';

                                final String cat =
                                    (lieu['categorie'] ?? lieu['type'] ?? '')
                                        .toString()
                                        .trim();

                                final double? avg =
                                    (lieu['_avg'] as num?)?.toDouble();
                                final int nb = (lieu['_count'] as int?) ?? 0;

                                final dist = (lieu['_distance'] as double?);

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DivertissementDetailPage(
                                                lieu: lieu),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    color: _neutralSurface,
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: const BorderSide(
                                          color: _neutralBorder),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // ✅✅✅ MÊME CARTE : image 4/3 (pas déformée)
                                        AspectRatio(
                                          aspectRatio: 4 / 3,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              _premiumImage(img),
                                              if ((lieu['ville'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)
                                                Positioned(
                                                  left: 8,
                                                  top: 8,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.55),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.location_on,
                                                          size: 14,
                                                          color: Colors.white,
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        ConstrainedBox(
                                                          constraints:
                                                              const BoxConstraints(
                                                                  maxWidth:
                                                                      120),
                                                          child: Text(
                                                            (lieu['ville'] ??
                                                                    '')
                                                                .toString(),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 12,
                                                              height: 1.0,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Infos
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                10, 8, 10, 8),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (lieu['nom'] ?? '')
                                                      .toString(),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    height: 1.15,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),

                                                // Note
                                                Row(
                                                  children: [
                                                    _stars(avg ?? 0.0),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      nb > 0
                                                          ? (avg ?? 0.0)
                                                              .toStringAsFixed(
                                                                  1)
                                                          : '—',
                                                      style: TextStyle(
                                                        color: Colors.black
                                                            .withOpacity(.85),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 12.5,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                    if (nb > 0) ...[
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '($nb)',
                                                        style: TextStyle(
                                                          color: Colors.black
                                                              .withOpacity(.6),
                                                          fontSize: 12,
                                                          height: 1.0,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),

                                                const SizedBox(height: 4),

                                                // Ville + distance
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        (lieu['ville'] ?? '')
                                                            .toString(),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                                        overflow:
                                                            TextOverflow.fade,
                                                        style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 13,
                                                          height: 1.0,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),

                                                // Catégorie
                                                if (cat.isNotEmpty) ...[
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    cat,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: primaryColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

// ------------------ Skeleton Card (même format que Santé/Tourisme) --------------------
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: _DivertissementPageState._neutralSurface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _DivertissementPageState._neutralBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(color: Colors.grey.shade200),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 120,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 90,
                    color: Colors.grey.shade200,
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
