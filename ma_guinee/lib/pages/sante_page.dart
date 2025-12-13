// lib/pages/sante_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'sante_detail_page.dart';
import '../services/geoloc_service.dart';

class SantePage extends StatefulWidget {
  const SantePage({super.key});

  static const int pageSize = 30;

  static Future<void> preload() async {
    try {
      final sb = Supabase.instance.client;
      final raw = await sb
          .from('cliniques')
          .select(
              'id, nom, ville, specialites, description, images, latitude, longitude')
          .order('nom')
          .range(0, pageSize - 1);

      final list = (raw as List).cast<Map<String, dynamic>>();
      _SantePageState.setGlobalCache(list);

      try {
        if (Hive.isBoxOpen(_SantePageState._hiveBoxName)) {
          final box = Hive.box(_SantePageState._hiveBoxName);
          await box.put(_SantePageState._hiveKey, list);
        }
      } catch (_) {}
    } catch (_) {}
  }

  @override
  State<SantePage> createState() => _SantePageState();
}

class _SantePageState extends State<SantePage>
    with AutomaticKeepAliveClientMixin {
  // ✅ Cache Hive
  static const String _hiveBoxName = 'sante_box';
  static const String _hiveKey = 'centres';

  // ✅ Cache mémoire global
  static List<Map<String, dynamic>> _cacheCentres = [];
  static void setGlobalCache(List<Map<String, dynamic>> list) {
    _cacheCentres = List<Map<String, dynamic>>.from(list);
  }

  // Palette Santé
  static const Color primaryColor = Color(0xFF009460); // vert
  static const Color secondaryColor = Color(0xFFFCD116); // jaune

  // Neutres (comme resto)
  static const Color _neutralBg = Color(0xFFF7F7F9);
  static const Color _neutralSurface = Color(0xFFFFFFFF);
  static const Color _neutralBorder = Color(0xFFE5E7EB);

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Données
  List<Map<String, dynamic>> _centres = [];
  List<Map<String, dynamic>> _filtered = [];

  // États
  bool _loading = true; // skeleton uniquement si aucun cache affiché
  bool _syncing = false; // sync réseau silencieuse
  bool _initialFetchDone = false;

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  // ---------- Utils ----------
  bool _validUrl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final u = Uri.tryParse(s.trim());
    return u != null && (u.isScheme('http') || u.isScheme('https'));
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => _validUrl(s))
          .toList();
    }
    final s = (raw ?? '').toString().trim();
    return _validUrl(s) ? [s] : const [];
  }

  double? _dist(double? lat1, double? lon1, double? lat2, double? lon2) {
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

  // ---------- Localisation (non bloquante) ----------
  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      // last known (instant)
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _position = last;
        unawaited(_reverseCity(last));
        _recomputeDistancesAndSort();
      }

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

      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
          .then((pos) async {
        _position = pos;

        try {
          await GeolocService.reportPosition(pos);
        } catch (_) {}

        await _reverseCity(pos);
        _recomputeDistancesAndSort();
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<void> _reverseCity(Position pos) async {
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

  // ---------- Cache instant (Hive -> mémoire) ----------
  void _loadCacheInstant() {
    // 1) disque
    try {
      if (Hive.isBoxOpen(_hiveBoxName)) {
        final box = Hive.box(_hiveBoxName);
        final cached = box.get(_hiveKey) as List?;
        if (cached != null && cached.isNotEmpty) {
          _centres = cached
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _cacheCentres = List<Map<String, dynamic>>.from(_centres);

          _loading = false;
          _initialFetchDone = true;
          _applyFilter(_searchCtrl.text, notify: false);
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (_) {}

    // 2) mémoire
    if (_cacheCentres.isNotEmpty) {
      _centres = List<Map<String, dynamic>>.from(_cacheCentres);
      _loading = false;
      _initialFetchDone = true;
      _applyFilter(_searchCtrl.text, notify: false);
      if (mounted) setState(() {});
    }
  }

  // ---------- Tri / enrich ----------
  void _enrichDistancesAndSort(List<Map<String, dynamic>> list) {
    int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());

    if (_position != null) {
      for (final c in list) {
        final lat = (c['latitude'] as num?)?.toDouble();
        final lon = (c['longitude'] as num?)?.toDouble();
        c['_distance'] =
            _dist(_position!.latitude, _position!.longitude, lat, lon);
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
    if (_centres.isEmpty) return;
    final list = _centres.map((e) => Map<String, dynamic>.from(e)).toList();
    _enrichDistancesAndSort(list);
    _centres = list;
    _applyFilter(_searchCtrl.text);
  }

  // ---------- Réseau (SWR) ----------
  Future<void> _reloadAll() async {
    final hadData = _centres.isNotEmpty;

    if (mounted) {
      setState(() {
        if (!hadData) {
          _loading = true;
        } else {
          _syncing = true;
        }
      });
    }

    unawaited(_getLocation());

    try {
      final data = await Supabase.instance.client
          .from('cliniques')
          .select(
              'id, nom, ville, specialites, description, images, latitude, longitude')
          .order('nom');

      final list = List<Map<String, dynamic>>.from(data);
      _enrichDistancesAndSort(list);

      // caches
      _cacheCentres = List<Map<String, dynamic>>.from(list);
      try {
        if (Hive.isBoxOpen(_hiveBoxName)) {
          final box = Hive.box(_hiveBoxName);
          await box.put(_hiveKey, list);
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _centres = list;
        _loading = false;
        _syncing = false;
        _initialFetchDone = true;
      });
      _applyFilter(_searchCtrl.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncing = false;
        _initialFetchDone = true;
      });
    }
  }

  Future<void> _refresh() async => _reloadAll();

  // ---------- Filtre ----------
  void _applyFilter(String value, {bool notify = true}) {
    final q = value.toLowerCase().trim();
    final filtered = q.isEmpty
        ? _centres
        : _centres.where((c) {
            final nom = (c['nom'] ?? '').toString().toLowerCase();
            final ville = (c['ville'] ?? '').toString().toLowerCase();
            final spec = (c['specialites'] ?? c['description'] ?? '')
                .toString()
                .toLowerCase();
            return nom.contains(q) || ville.contains(q) || spec.contains(q);
          }).toList();

    _filtered = filtered;
    if (mounted && notify) setState(() {});
  }

  // ---------- UI image premium ----------
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

        return CachedNetworkImage(
          key: ValueKey('sante_img_$url'),
          imageUrl: url,
          cacheKey: url,
          memCacheWidth: (w * dpr).round(),
          memCacheHeight: (h * dpr).round(),
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          imageBuilder: (ctx, provider) => Image(
            image: provider,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          ),
          placeholder: (_, __) => _imagePremiumPlaceholder(),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFFE5E7EB),
            alignment: Alignment.center,
            child:
                const Icon(Icons.local_hospital, size: 44, color: Colors.grey),
          ),
        );
      },
    );
  }

  // ---------- Grid responsive (comme resto) ----------
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
    final imageH = itemWidth * (3 / 4);

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

  // ✅ Bandeau SANS overflow (plus de height fixe)
  Widget _heroBanner(String? subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Container(
            width: double.infinity,
            // IMPORTANT: pas de height fixe -> évite "BOTTOM OVERFLOWED"
            constraints: const BoxConstraints(minHeight: 72),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [secondaryColor, primaryColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Découvrez tous les centres et cliniques de Guinée",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
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
    );
  }

  @override
  void initState() {
    super.initState();

    _loadCacheInstant();
    unawaited(_reloadAll());

    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        _applyFilter(_searchCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

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

    final showSkeleton = !_initialFetchDone && _loading && _centres.isEmpty;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: _neutralBg,
        appBar: AppBar(
          title: const Text(
            "Services de santé",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: _neutralSurface,
          iconTheme: const IconThemeData(color: primaryColor),
          elevation: 1,
          actions: [
            if (_syncing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.check_circle, size: 16, color: Colors.black26),
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: primaryColor),
              onPressed: _refresh,
              tooltip: 'Rafraîchir',
            ),
          ],
        ),
        body: Column(
          children: [
            // ✅ Bandeau corrigé (plus d’overflow)
            _heroBanner(subtitleInfo),

            // Recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText:
                      'Rechercher un centre, une ville, une spécialité...',
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
                  : (_filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 200),
                            Center(child: Text("Aucun centre trouvé.")),
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
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final c = _filtered[index];
                            final images = _imagesFrom(c['images']);
                            final img = images.isNotEmpty
                                ? images.first
                                : 'https://via.placeholder.com/600x400?text=Sant%C3%A9';

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SanteDetailPage(cliniqueId: c['id']),
                                  ),
                                );
                              },
                              child: Card(
                                margin: EdgeInsets.zero,
                                color: _neutralSurface,
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: _neutralBorder),
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
                                          if ((c['ville'] ?? '')
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
                                                        c['ville'].toString(),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
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
                                              (c['nom'] ?? "Sans nom")
                                                  .toString(),
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
                                                Expanded(
                                                  child: Text(
                                                    (c['ville'] ?? '')
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
                                                if (c['_distance'] != null) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${((c['_distance'] as double) / 1000).toStringAsFixed(1)} km',
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
                                            if ((c['specialites'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                c['specialites'].toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: primaryColor,
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
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
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
                      color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(
                      height: 10, width: 120, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 90, color: Colors.grey.shade200),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
