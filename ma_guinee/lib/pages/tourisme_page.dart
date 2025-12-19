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

// ✅ Cache persistant (comme annonces)
import 'package:hive_flutter/hive_flutter.dart';

import '../services/geoloc_service.dart';
import 'tourisme_detail_page.dart';

// ✅ Centralisation erreurs (offline/supabase/timeout + overlay anti-spam)
import 'package:ma_guinee/utils/error_messages_fr.dart';

const Color tourismePrimary = Color(0xFFDAA520);
const Color tourismeSecondary = Color(0xFFFFD700);
const Color neutralBg = Color(0xFFF7F7F9);
const Color neutralSurface = Color(0xFFFFFFFF);
const Color neutralBorder = Color(0xFFE5E7EB);

const LinearGradient _tourismeGradient = LinearGradient(
  colors: [tourismePrimary, tourismeSecondary],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

class TourismePage extends StatefulWidget {
  const TourismePage({super.key});

  /// (optionnel) préload 1 page pour affichage instant
  static const int pageSize = 30;

  static Future<void> preload() async {
    try {
      final sb = Supabase.instance.client;
      final raw = await sb.from('lieux').select('''
              id, nom, ville, type, categorie,
              images, latitude, longitude, photo_url
            ''').eq('type', 'tourisme').order('nom').range(0, pageSize - 1);

      final list = (raw as List).cast<Map<String, dynamic>>();

      _TourismePageState.setGlobalCache(list);

      try {
        if (Hive.isBoxOpen('tourisme_box')) {
          await Hive.box('tourisme_box').put('lieux', list);
        }
      } catch (_) {}
    } catch (_) {
      // preload silencieux
    }
  }

  @override
  State<TourismePage> createState() => _TourismePageState();
}

class _TourismePageState extends State<TourismePage>
    with AutomaticKeepAliveClientMixin {
  final _sb = Supabase.instance.client;

  // ✅ Hive
  static const String _hiveBoxName = 'tourisme_box';
  static const String _hiveKey = 'lieux';

  // ✅ Cache mémoire global (retour écran rapide)
  static List<Map<String, dynamic>> _cacheLieux = [];
  static void setGlobalCache(List<Map<String, dynamic>> list) {
    _cacheLieux = List<Map<String, dynamic>>.from(list);
  }

  List<Map<String, dynamic>> _allLieux = [];
  List<Map<String, dynamic>> _filteredLieux = [];

  bool _loading = true; // skeleton uniquement si aucun cache affiché
  bool _syncing = false;
  bool _initialFetchDone = false;

  // recherche
  String searchQuery = '';
  Timer? _debounce;

  // localisation rapide (non bloquante)
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  // notes
  final Map<String, double> _avgByLieuId = {};
  final Map<String, int> _countByLieuId = {};
  String? _lastRatingsKey;

  // pré-cache images
  bool _didPrecache = false;

  // ---------- Grid (même logique que Annonces/Santé) ----------
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

    final imageH = itemWidth * (3 / 4); // ✅ image 4/3 (pas déformée)

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

  @override
  void initState() {
    super.initState();

    // 1) Cache instant
    _loadCacheInstant();

    // 2) Réseau en fond (SWR)
    unawaited(_reloadAll());

    // 3) après 1er rendu (precache + ratings)
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstPaint());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------- Cache instant (Hive -> mémoire) --------------------
  void _loadCacheInstant() {
    // 1) Disque
    try {
      if (Hive.isBoxOpen(_hiveBoxName)) {
        final box = Hive.box(_hiveBoxName);
        final cached = box.get(_hiveKey) as List?;
        if (cached != null && cached.isNotEmpty) {
          _allLieux = cached
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _cacheLieux = List<Map<String, dynamic>>.from(_allLieux);

          _filterLieuxCore(searchQuery, notify: false);
          _loading = false;
          _initialFetchDone = true;
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (_) {}

    // 2) Mémoire
    if (_cacheLieux.isNotEmpty) {
      _allLieux = List<Map<String, dynamic>>.from(_cacheLieux);
      _filterLieuxCore(searchQuery, notify: false);
      _loading = false;
      _initialFetchDone = true;
      if (mounted) setState(() {});
    }
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
        _locationDenied = true;
        if (mounted) setState(() {});
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(milliseconds: 600),
      );
      _position = pos;

      // fire-and-forget
      unawaited(GeolocService.reportPosition(pos));
      unawaited(_resolveCity(pos));
    } catch (_) {
      // silencieux
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

        // retri après coup
        _resortByDistanceInBackground();
      }
    } catch (_) {}
  }

  // -------------------- Réseau SWR : remplace en fond --------------------
  Future<void> _reloadAll() async {
    final hadData = _allLieux.isNotEmpty;

    if (mounted) {
      setState(() {
        if (!hadData) {
          _loading = true;
        } else {
          _syncing = true;
        }
      });
    }

    unawaited(_getLocationFast());

    try {
      final response = await _sb.from('lieux').select('''
        id, nom, ville, type, categorie,
        images, latitude, longitude, photo_url
      ''').eq('type', 'tourisme').order('nom');

      final list = List<Map<String, dynamic>>.from(response);

      // tri par nom immédiatement
      list.sort((a, b) =>
          (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString()));

      // caches (mémoire + disque)
      _cacheLieux = List<Map<String, dynamic>>.from(list);
      try {
        if (Hive.isBoxOpen(_hiveBoxName)) {
          await Hive.box(_hiveBoxName).put(_hiveKey, list);
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _allLieux = list;
        _filterLieuxCore(searchQuery, notify: false);
        _loading = false;
        _syncing = false;
        _initialFetchDone = true;
      });

      // ✅ Réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();

      // après affichage : tri distance/ville en fond si position dispo
      _resortByDistanceInBackground();

      // relance precache/ratings
      _didPrecache = false;
      _afterFirstPaint();
    } catch (e, st) {
      // ✅ centralisation erreurs (pas d’erreur brute)
      SoneyaErrorCenter.showException(e as Object, st);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncing = false;
        _initialFetchDone = true;
      });

      // ✅ Si aucun cache affiché : message FR simple
      if (_allLieux.isEmpty) {
        _snack(frMessageFromError(e as Object, st));
      }
    }
  }

  Future<void> _refresh() async => _reloadAll();

  // Tri distance/ville dans un isolate (ne bloque pas l’UI)
  Future<void> _resortByDistanceInBackground() async {
    if (_position == null || _allLieux.isEmpty) return;

    final payload = _SortPayload(
      items: _allLieux,
      userLat: _position!.latitude,
      userLon: _position!.longitude,
      villeLower: _villeGPS,
    );

    final sorted = await compute<_SortPayload, List<Map<String, dynamic>>>(
      _sortPlacesByProximity,
      payload,
    );

    if (!mounted) return;
    setState(() {
      _allLieux = sorted;
      _filterLieuxCore(searchQuery, notify: false);
    });
  }

  // -------------------- Recherche (debounce) --------------------
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), () {
      _filterLieuxCore(q);
      _didPrecache = false;
      _afterFirstPaint();
    });
  }

  void _filterLieuxCore(String query, {bool notify = true}) {
    final q = query.toLowerCase().trim();
    searchQuery = query;

    final filtered = _allLieux.where((lieu) {
      final nom = (lieu['nom'] ?? '').toString().toLowerCase();
      final ville = (lieu['ville'] ?? '').toString().toLowerCase();
      final tag =
          (lieu['categorie'] ?? lieu['type'] ?? '').toString().toLowerCase();
      return q.isEmpty ||
          nom.contains(q) ||
          ville.contains(q) ||
          tag.contains(q);
    }).toList();

    _filteredLieux = filtered;
    if (mounted && notify) setState(() {});
  }

  // -------------------- Notes (throttled) --------------------
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

      // ✅ Réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      // ✅ centralisation (silencieux côté UI)
      SoneyaErrorCenter.showException(e as Object, st);
    }
  }

  // Post-affichage : pré-cache images + charger notes
  void _afterFirstPaint() {
    if (_didPrecache || _filteredLieux.isEmpty) return;
    _didPrecache = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // precache 8 premières images
      for (final l in _filteredLieux.take(8)) {
        final url = _bestImage(l);
        if (url.isNotEmpty && mounted) {
          try {
            await precacheImage(CachedNetworkImageProvider(url), context);
          } catch (_) {}
        }
      }

      // notes
      final ids = _filteredLieux
          .map((l) => (l['id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
      _loadRatingsFor(ids);
    });
  }

  // -------------------- Helpers images premium --------------------
  List<String> _imagesFrom(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      return raw
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    final s = (raw ?? '').toString().trim();
    return s.isNotEmpty ? [s] : const [];
  }

  String _bestImage(Map<String, dynamic> lieu) {
    final imgs = _imagesFrom(lieu['images']);
    if (imgs.isNotEmpty) return imgs.first;
    return (lieu['photo_url'] ?? '').toString().trim();
  }

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

        final safeUrl = url.trim().isNotEmpty
            ? url.trim()
            : 'https://via.placeholder.com/600x400?text=Tourisme';

        return CachedNetworkImage(
          key: ValueKey('tourisme_img_$safeUrl'),
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
            fit: BoxFit.cover, // ✅ pas de déformation
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          ),
          placeholder: (_, __) => _imagePremiumPlaceholder(),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFFE5E7EB),
            alignment: Alignment.center,
            child: const Icon(Icons.landscape, size: 44, color: Colors.grey),
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

    final showSkeleton = !_initialFetchDone && _loading && _allLieux.isEmpty;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: neutralBg,
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          title: const Text(
            "Sites touristiques",
            style: TextStyle(
              color: tourismePrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: neutralSurface,
          elevation: 1,
          foregroundColor: tourismePrimary,
          actions: [
            if (_syncing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.check_circle, size: 16, color: Colors.black26),
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: tourismePrimary),
              tooltip: 'Rafraîchir',
              onPressed: _refresh,
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(3),
            child: SizedBox(
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: _tourismeGradient),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Bandeau
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _tourismeGradient,
              ),
              clipBehavior: Clip.hardEdge,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  "Découvrez les plus beaux sites touristiques de Guinée"
                  "${_locationDenied ? " (localisation refusée)" : ""}",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),

            // Recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher un site, une ville, une catégorie…',
                  prefixIcon: Icon(Icons.search, color: tourismePrimary),
                  filled: true,
                  fillColor: neutralSurface,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: neutralBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: neutralBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: tourismePrimary, width: 1.4),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: showSkeleton
                  ? GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCols,
                        mainAxisSpacing: gridSpacing,
                        crossAxisSpacing: gridSpacing,
                        childAspectRatio: ratio,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: gridHPadding,
                        vertical: 4,
                      ),
                      itemCount: 8,
                      itemBuilder: (_, __) => const _SkeletonCard(),
                    )
                  : (_filteredLieux.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 200),
                            Center(child: Text("Aucun site trouvé.")),
                          ],
                        )
                      : GridView.builder(
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
                          itemCount: _filteredLieux.length,
                          itemBuilder: (context, index) {
                            final lieu = _filteredLieux[index];
                            final id = (lieu['id'] ?? '').toString();
                            final img = _bestImage(lieu);
                            final dist = lieu['_distance'] as double?;

                            final rating = _avgByLieuId[id] ?? 0.0;
                            final count = _countByLieuId[id] ?? 0;

                            return InkWell(
                              onTap: () async {
                                try {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TourismeDetailPage(lieu: lieu),
                                    ),
                                  );
                                } catch (e, st) {
                                  SoneyaErrorCenter.showException(
                                      e as Object, st);
                                  _snack(frMessageFromError(e as Object, st));
                                }
                              },
                              child: Card(
                                margin: EdgeInsets.zero,
                                color: neutralSurface,
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: neutralBorder),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.55),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
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
                                                    const SizedBox(width: 4),
                                                    ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                              maxWidth: 120),
                                                      child: Text(
                                                        (lieu['ville'] ?? '')
                                                            .toString(),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
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
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            10, 8, 10, 8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (lieu['nom'] ?? '').toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                _stars(rating),
                                                const SizedBox(width: 6),
                                                Text(
                                                  count > 0
                                                      ? rating
                                                          .toStringAsFixed(1)
                                                      : '—',
                                                  style: TextStyle(
                                                    color: Colors.black
                                                        .withOpacity(.85),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12.5,
                                                    height: 1.0,
                                                  ),
                                                ),
                                                if (count > 0) ...[
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '($count)',
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
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    (lieu['ville'] ?? '')
                                                        .toString(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                            if ((lieu['categorie'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                (lieu['categorie'] ?? '')
                                                    .toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: tourismePrimary,
                                                  fontWeight: FontWeight.w600,
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
                        )),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: neutralSurface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: neutralBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 4 / 3,
            child: SizedBox(),
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
                    color: Color(0xFFE5E7EB),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 120,
                    color: Color(0xFFE5E7EB),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 90,
                    color: Color(0xFFE5E7EB),
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
  final list = List<Map<String, dynamic>>.from(
    p.items.map((e) => Map<String, dynamic>.from(e)),
  );

  for (final l in list) {
    final lat = (l['latitude'] as num?)?.toDouble();
    final lon = (l['longitude'] as num?)?.toDouble();
    l['_distance'] = _distIso(lat, lon, p.userLat, p.userLon);
  }

  int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
      (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());

  if ((p.villeLower ?? '').isNotEmpty) {
    list.sort((a, b) {
      final aSame =
          (a['ville'] ?? '').toString().toLowerCase().trim() == p.villeLower;
      final bSame =
          (b['ville'] ?? '').toString().toLowerCase().trim() == p.villeLower;
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

double? _distIso(double? lat1, double? lon1, double? lat2, double? lon2) {
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
