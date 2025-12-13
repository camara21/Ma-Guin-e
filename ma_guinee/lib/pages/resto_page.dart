// lib/pages/resto_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Cache disque (comme annonces)
import 'package:hive_flutter/hive_flutter.dart';

import '../routes.dart';
import '../services/geoloc_service.dart'; // centralisation envoi position

class RestoPage extends StatefulWidget {
  const RestoPage({super.key});

  /// Taille “préload” (pour affichage instant)
  static const int pageSize = 30;

  /// Précharge 1 page et remplit le cache (comme annonces)
  static Future<void> preload() async {
    try {
      final sb = Supabase.instance.client;

      final raw = await sb
          .from('v_restaurants_ratings') // adapte si nécessaire
          .select()
          .order('nom')
          .range(0, pageSize - 1);

      final list = (raw as List).cast<Map<String, dynamic>>();

      _RestoPageState.setGlobalCache(list);

      try {
        if (Hive.isBoxOpen('restaurants_box')) {
          final box = Hive.box('restaurants_box');
          await box.put('restaurants', list);
        }
      } catch (_) {}
    } catch (_) {}
  }

  @override
  State<RestoPage> createState() => _RestoPageState();
}

class _RestoPageState extends State<RestoPage> {
  // Couleurs — Restaurants
  static const Color _restoPrimary = Color(0xFFE76F51);
  static const Color _restoSecondary = Color(0xFFF4A261);
  static const Color _restoOnPrimary = Color(0xFFFFFFFF);

  // Neutres
  static const Color _neutralBg = Color(0xFFF7F7F9);
  static const Color _neutralSurface = Color(0xFFFFFFFF);
  static const Color _neutralBorder = Color(0xFFE5E7EB);

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // ✅ Cache global mémoire (comme annonces)
  static List<Map<String, dynamic>> _cacheRestos = [];
  static void setGlobalCache(List<Map<String, dynamic>> list) {
    _cacheRestos = List<Map<String, dynamic>>.from(list);
  }

  // Données
  List<Map<String, dynamic>> _restos = [];
  List<Map<String, dynamic>> _filtered = [];

  // État d’affichage
  bool _loading = true; // skeleton quand rien affiché
  bool _syncing = false; // sync réseau silencieuse
  bool _initialFetchDone = false;

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  // ---------- Helpers ----------
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

  String _formatGNF(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remaining = s.length - i - 1;
      buf.write(s[i]);
      if (remaining > 0 && remaining % 3 == 0) buf.write('\u202F');
    }
    return '$buf GNF';
  }

  void _applyFilter(String value) {
    final q = value.toLowerCase().trim();
    final filtered = q.isEmpty
        ? _restos
        : _restos.where((r) {
            final nom = (r['nom'] ?? '').toString().toLowerCase();
            final ville = (r['ville'] ?? '').toString().toLowerCase();
            return nom.contains(q) || ville.contains(q);
          }).toList();

    if (!mounted) {
      _filtered = filtered;
      return;
    }
    setState(() => _filtered = filtered);
  }

  void _sortRestos(List<Map<String, dynamic>> list) {
    int byName(a, b) =>
        (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());

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
  }

  // ---------- Localisation (non bloquante) ----------
  Future<void> _getLocation() async {
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

      // last known (instant)
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _position = last;
        _recomputeDistancesAndSort();
      }

      // position actuelle (meilleure)
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
          .then((pos) async {
        _position = pos;

        try {
          await GeolocService.reportPosition(pos);
        } catch (_) {}

        try {
          final marks =
              await placemarkFromCoordinates(pos.latitude, pos.longitude);
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

        _recomputeDistancesAndSort();
      }).catchError((_) {});
    } catch (_) {}
  }

  void _recomputeDistancesAndSort() {
    if (_restos.isEmpty || _position == null) {
      if (mounted) setState(() {});
      return;
    }

    for (final r in _restos) {
      final lat = (r['latitude'] as num?)?.toDouble();
      final lon = (r['longitude'] as num?)?.toDouble();
      r['_distance'] =
          _distanceMeters(_position!.latitude, _position!.longitude, lat, lon);
    }

    _sortRestos(_restos);
    _applyFilter(_searchCtrl.text);
  }

  // ---------- Cache disque (Hive) + cache mémoire ----------
  void _loadCacheInstant() {
    // 1) cache disque
    try {
      if (Hive.isBoxOpen('restaurants_box')) {
        final box = Hive.box('restaurants_box');
        final cached = box.get('restaurants') as List?;
        if (cached != null && cached.isNotEmpty) {
          _restos = cached
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _cacheRestos = List<Map<String, dynamic>>.from(_restos);
          _loading = false;
          _initialFetchDone = true;
          _applyFilter(_searchCtrl.text);
          return;
        }
      }
    } catch (_) {}

    // 2) cache mémoire
    if (_cacheRestos.isNotEmpty) {
      _restos = List<Map<String, dynamic>>.from(_cacheRestos);
      _loading = false;
      _initialFetchDone = true;
      _applyFilter(_searchCtrl.text);
    }
  }

  Future<void> _reloadAll() async {
    final hadData = _restos.isNotEmpty;

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
      final raw = await Supabase.instance.client
          .from('v_restaurants_ratings') // adapte si nécessaire
          .select()
          .order('nom');

      final restos = List<Map<String, dynamic>>.from(raw);

      // enrich distance + note
      if (_position != null) {
        for (final r in restos) {
          final lat = (r['latitude'] as num?)?.toDouble();
          final lon = (r['longitude'] as num?)?.toDouble();
          r['_distance'] = _distanceMeters(
              _position!.latitude, _position!.longitude, lat, lon);
        }
      }
      for (final r in restos) {
        final avg = (r['note_moyenne'] as num?)?.toDouble();
        if (avg != null) r['_avg_int'] = avg.round();
      }

      _sortRestos(restos);

      // ✅ écrit cache mémoire + disque
      _cacheRestos = List<Map<String, dynamic>>.from(restos);
      try {
        if (Hive.isBoxOpen('restaurants_box')) {
          final box = Hive.box('restaurants_box');
          await box.put('restaurants', restos);
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _restos = restos;
        _loading = false;
        _syncing = false;
        _initialFetchDone = true;
      });

      _applyFilter(_searchCtrl.text);
    } catch (e) {
      // si on avait déjà du cache affiché, on ne casse pas l’UI
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncing = false;
        _initialFetchDone = true;
      });
      if (_restos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur réseau restos: $e')),
        );
      }
    }
  }

  // ---------- UI (images nettes + placeholder premium) ----------
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
          key: ValueKey('resto_img_$url'),
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
            child: const Icon(Icons.restaurant, size: 44, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildStarsInt(int n) {
    final c = n.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < c ? Icons.star : Icons.star_border,
          size: 14,
          color: _restoSecondary,
        ),
      ),
    );
  }

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

  @override
  void initState() {
    super.initState();

    // ✅ Affichage instant depuis cache (Hive -> mémoire)
    _loadCacheInstant();

    // ✅ Sync réseau (ne bloque pas si déjà du cache)
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
  Widget build(BuildContext context) {
    const bottomGradient = LinearGradient(
      colors: [_restoPrimary, _restoSecondary],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

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

    final showSkeleton = !_initialFetchDone && _loading && _restos.isEmpty;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: _neutralBg,
        appBar: AppBar(
          title: const Text(
            'Restaurants',
            style: TextStyle(
              color: _restoPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: _neutralSurface,
          foregroundColor: _restoPrimary,
          elevation: 1,
          actions: [
            if (_syncing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.check_circle, size: 16, color: Colors.black26),
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: _restoPrimary),
              tooltip: 'Rafraîchir',
              onPressed: _reloadAll,
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
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              // Bandeau
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 72,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_restoPrimary, _restoSecondary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Découvrez les meilleurs restaurants de Guinée',
                              style: TextStyle(
                                color: _restoOnPrimary,
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
                                  color: _restoOnPrimary,
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

              // Recherche
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un resto ou une ville…',
                    prefixIcon: Icon(Icons.search, color: _restoPrimary),
                    filled: true,
                    fillColor: _neutralSurface,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

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
                            horizontal: gridHPadding, vertical: 4),
                        itemCount: 8,
                        itemBuilder: (_, __) => const _SkeletonRestoCard(),
                      )
                    : (_filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 200),
                              Center(child: Text('Aucun restaurant trouvé.')),
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
                                horizontal: gridHPadding, vertical: 4),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final r = _filtered[i];

                              final images = _imagesFrom(r['images']);
                              final image = images.isNotEmpty
                                  ? images.first
                                  : 'https://via.placeholder.com/600x400?text=Restaurant';

                              final hasPrix = (r['prix'] is num) ||
                                  ((r['prix'] is String) &&
                                      (r['prix'] as String).trim().isNotEmpty);
                              final prixVal = (r['prix'] is num)
                                  ? (r['prix'] as num).toInt()
                                  : int.tryParse((r['prix'] ?? '').toString());

                              final avgInt = (r['_avg_int'] as int?) ??
                                  ((r['note_moyenne'] is num)
                                      ? (r['note_moyenne'] as num).round()
                                      : null) ??
                                  ((r['etoiles'] is int)
                                      ? r['etoiles'] as int
                                      : null);

                              return InkWell(
                                onTap: () {
                                  final String restoId = r['id'].toString();
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.restoDetail,
                                    arguments: restoId,
                                  );
                                },
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color: _neutralSurface,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side:
                                        const BorderSide(color: _neutralBorder),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ✅ Image PREMIUM (comme annonces)
                                      AspectRatio(
                                        aspectRatio: 4 / 3,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            _premiumImage(image),

                                            // badge ville
                                            if ((r['ville'] ?? '')
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
                                                      vertical: 4),
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
                                                          color: Colors.white),
                                                      const SizedBox(width: 4),
                                                      ConstrainedBox(
                                                        constraints:
                                                            const BoxConstraints(
                                                                maxWidth: 120),
                                                        child: Text(
                                                          r['ville'].toString(),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Texte
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              10, 8, 10, 8),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (r['nom'] ?? 'Sans nom')
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
                                                      (r['ville'] ?? '')
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
                                                  if (r['_distance'] !=
                                                      null) ...[
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${((r['_distance'] as double) / 1000).toStringAsFixed(1)} km',
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
                                              if (hasPrix &&
                                                  prixVal != null) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Prix : ${_formatGNF(prixVal)} (plat)',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _restoPrimary,
                                                    fontSize: 12,
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ],
                                              const Spacer(),
                                              if (avgInt != null)
                                                _buildStarsInt(avgInt),
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
      ),
    );
  }
}

// Skeleton card (même style)
class _SkeletonRestoCard extends StatelessWidget {
  const _SkeletonRestoCard();

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
                  const Spacer(),
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
