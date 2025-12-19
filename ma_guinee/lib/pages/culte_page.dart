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
import 'culte_detail_page.dart';

// ✅ Centralisation erreurs (offline/supabase/timeout + overlay anti-spam)
import 'package:ma_guinee/utils/error_messages_fr.dart';

class CultePage extends StatefulWidget {
  const CultePage({super.key});

  @override
  State<CultePage> createState() => _CultePageState();
}

class _CultePageState extends State<CultePage>
    with AutomaticKeepAliveClientMixin {
  // ====== Couleur page ======
  static const primaryColor = Color(0xFF113CFC);

  // ====== Cache (SWR) ======
  static const _CACHE_KEY = 'culte:lieux:v1';
  static const _CACHE_MAX_AGE = Duration(hours: 24);

  // ✅ Cache mémoire global (retour écran instant)
  static List<Map<String, dynamic>> _memoryCacheCulte = [];

  // ✅ Hive persistant (relance app instant)
  static const String _hiveBoxName = 'lieux_box';
  static const String _hiveKey = 'culte_snapshot_v1';

  // Données
  List<Map<String, dynamic>> _allLieux = [];
  List<Map<String, dynamic>> _filtered = [];

  // État
  bool _loading = true; // skeleton uniquement si cold start sans cache
  bool _syncing = false; // sync réseau silencieuse
  bool _hasAnyCache = false;

  // Recherche
  String _query = '';

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;
  bool _resorting = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void initState() {
    super.initState();

    // 0) cache mémoire global (instant)
    if (_memoryCacheCulte.isNotEmpty) {
      _allLieux =
          _memoryCacheCulte.map((e) => Map<String, dynamic>.from(e)).toList();
      _applyFilter(_query, setStateNow: false);
      _hasAnyCache = true;
      _loading = false;
    }

    _loadAllSWR(); // ⚡ SWR : cache instantané + réseau en arrière-plan
  }

  @override
  bool get wantKeepAlive => true;

  // ---------------- Hive snapshot helpers ----------------
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
      if (ageMs > _CACHE_MAX_AGE.inMilliseconds) return null;

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

  // ---------------- Localisation ultra-rapide (non bloquante) ----------------
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

      _locationDenied = false;

      // 1) last known → instantané
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _position = last;
        unawaited(GeolocService.reportPosition(last));
        unawaited(_resolveCity(last));
        _resortNowIfPossible();
      }

      // 2) current position → en fond, avec timeLimit (ne bloque pas)
      Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(milliseconds: 800),
      ).then((pos) {
        _position = pos;
        unawaited(GeolocService.reportPosition(pos));
        unawaited(_resolveCity(pos).then((_) => _resortNowIfPossible()));
      }).catchError((_) {});
    } catch (_) {
      _locationDenied = true;
      if (mounted) setState(() {});
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
    if (_isEglise(l)) return const Color(0xFF0F6EFD);
    return Colors.indigo;
  }

  // --------------- SWR: Cache -> Réseau ---------------
  Future<void> _loadAllSWR({bool forceNetwork = false}) async {
    // ouvre Hive si besoin (non bloquant)
    if (!Hive.isBoxOpen(_hiveBoxName)) {
      unawaited(Hive.openBox(_hiveBoxName));
    }

    // 1) Snapshot cache instantané si pas "forceNetwork"
    if (!forceNetwork && !_hasAnyCache) {
      // a) Hive
      final hiveSnap = _readHiveSnapshot();
      if (hiveSnap != null && hiveSnap.isNotEmpty) {
        _allLieux = hiveSnap.map((e) => Map<String, dynamic>.from(e)).toList();
        _memoryCacheCulte =
            _allLieux.map((e) => Map<String, dynamic>.from(e)).toList();
        _applyFilter(_query, setStateNow: false);
        _hasAnyCache = true;
        _loading = false;
        if (mounted) setState(() {});
      }

      // b) AppCache (mémoire/disque)
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
          _allLieux =
              snapshot.map((e) => Map<String, dynamic>.from(e)).toList();
          _memoryCacheCulte =
              _allLieux.map((e) => Map<String, dynamic>.from(e)).toList();
          _applyFilter(_query, setStateNow: false);
          _hasAnyCache = true;
          _loading = false;
          if (mounted) setState(() {});
        } else {
          if (mounted) setState(() => _loading = true);
        }
      }

      // géoloc en parallèle (non bloquante)
      unawaited(_getLocationFast());
    }

    // 2) Réseau en arrière-plan
    if (mounted) setState(() => _syncing = true);
    unawaited(_getLocationFast());

    try {
      final res = await Supabase.instance.client
          .from('lieux')
          .select(
              'id, nom, ville, type, categorie, sous_categorie, description, images, latitude, longitude, created_at')
          .eq('type', 'culte')
          .order('nom', ascending: true);

      final list = List<Map<String, dynamic>>.from(res);

      _allLieux = list;
      _memoryCacheCulte =
          list.map((e) => Map<String, dynamic>.from(e)).toList();
      _applyFilter(_query, setStateNow: false);

      _hasAnyCache = true;
      _loading = false;
      if (mounted) setState(() {});

      _resortNowIfPossible();

      final toCache = list.map((m) {
        final c = Map<String, dynamic>.from(m);
        c.remove('_distance');
        return c;
      }).toList(growable: false);

      AppCache.I.setList(_CACHE_KEY, toCache, persist: true);
      unawaited(_writeHiveSnapshot(toCache));

      // ✅ Réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      // ✅ Centralisation
      SoneyaErrorCenter.showException(e as Object, st);

      // ✅ Si aucun cache affiché, on montre un message FR
      if (mounted && !_hasAnyCache) {
        setState(() => _loading = false);
        _snack(frMessageFromError(e as Object, st));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Enrichit la liste actuelle avec la distance + tri (si position dispo).
  void _resortNowIfPossible() {
    if (_resorting) return;
    if (_allLieux.isEmpty) return;
    if (_position == null) return;

    _resorting = true;
    Future(() async {
      final cloned =
          _allLieux.map((e) => Map<String, dynamic>.from(e)).toList();
      final enriched = await _enrichAndSort(cloned);
      if (!mounted) return;

      _allLieux = enriched;
      _memoryCacheCulte =
          enriched.map((e) => Map<String, dynamic>.from(e)).toList();
      _applyFilter(_query, setStateNow: false);
      setState(() {});
    }).whenComplete(() => _resorting = false);
  }

  Future<List<Map<String, dynamic>>> _enrichAndSort(
      List<Map<String, dynamic>> list) async {
    if (_position != null) {
      for (final l in list) {
        final lat = (l['latitude'] as num?)?.toDouble();
        final lon = (l['longitude'] as num?)?.toDouble();
        l['_distance'] = _distanceMeters(
            _position!.latitude, _position!.longitude, lat, lon);
      }

      list.sort((a, b) {
        final aMosq = _isMosquee(a);
        final bMosq = _isMosquee(b);
        if (aMosq != bMosq) return aMosq ? -1 : 1;

        final v = _villeGPS;
        if ((v ?? '').isNotEmpty) {
          final aSame = (a['ville'] ?? '').toString().toLowerCase().trim() == v;
          final bSame = (b['ville'] ?? '').toString().toLowerCase().trim() == v;
          if (aSame != bSame) return aSame ? -1 : 1;
        }

        final ad = (a['_distance'] as double?);
        final bd = (b['_distance'] as double?);
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;

        return (a['nom'] ?? '')
            .toString()
            .compareTo((b['nom'] ?? '').toString());
      });
    } else {
      list.sort((a, b) {
        final aMosq = _isMosquee(a);
        final bMosq = _isMosquee(b);
        if (aMosq != bMosq) return aMosq ? -1 : 1;
        return (a['nom'] ?? '')
            .toString()
            .compareTo((b['nom'] ?? '').toString());
      });
    }
    return list;
  }

  // ---------------- Filtre -----------------------
  void _applyFilter(String q, {bool setStateNow = true}) {
    final lower = _folded(q);
    _query = q;

    _filtered = _allLieux.where((l) {
      if (lower.isEmpty) return true;
      final nom = _folded(l['nom']);
      final ville = _folded(l['ville']);
      final type = _folded(l['type']);
      final cat = _folded(l['categorie']);
      final sous = _folded(l['sous_categorie']);
      final desc = _folded(l['description']);
      final all = '$nom $ville $type $cat $sous $desc';
      return all.contains(lower);
    }).toList();

    if (setStateNow && mounted) setState(() {});
  }

  String _folded(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    if (s.isEmpty) return '';
    const map = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'œ': 'oe',
    };
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return const [];
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);

    // Grille responsive
    final screenW = media.size.width;
    final crossCount = screenW < 600
        ? max(2, (screenW / 200).floor())
        : max(3, (screenW / 240).floor());
    final totalHGap = (crossCount - 1) * 8.0 + 28.0;
    final itemW = (screenW - totalHGap) / crossCount;
    final itemH = itemW * (11 / 16) + 110.0;
    final ratio = itemW / itemH;

    final coldStart = !_hasAnyCache && _loading;

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
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_syncing)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child:
                      Icon(Icons.check_circle, size: 14, color: Colors.white70),
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
              onPressed: () => _loadAllSWR(forceNetwork: true),
              tooltip: 'Rafraîchir',
            ),
          ],
        ),

        // ✅ Tap partout = ferme le clavier (sans casser le scroll)
        body: Listener(
          onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          child: coldStart
              ? _skeletonGrid(context, crossCount, ratio)
              : Column(
                  children: [
                    // Bandeau intro
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            primaryColor,
                            primaryColor.withOpacity(0.65)
                          ],
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
                          height: 1.2,
                        ),
                      ),
                    ),

                    // Recherche
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher par nom, type ou ville...',
                          prefixIcon:
                              const Icon(Icons.search, color: primaryColor),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) => _applyFilter(v),
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

                    // Grille
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(
                              child: Text("Aucun lieu de culte trouvé."))
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: ratio,
                              ),
                              cacheExtent: 1200,
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final lieu = _filtered[index];
                                final images = _imagesFrom(lieu['images']);
                                final image = images.isNotEmpty
                                    ? images.first
                                    : 'https://via.placeholder.com/600x400.png?text=Culte';

                                final ville = (lieu['ville'] ?? '').toString();
                                final distM = (lieu['_distance'] as double?);
                                final distLabel = (distM != null)
                                    ? '${(distM / 1000).toStringAsFixed(1)} km'
                                    : null;

                                return _CulteCardTight(
                                  lieu: lieu,
                                  imageUrl: image,
                                  ville: ville,
                                  distLabel: distLabel,
                                  icon: _iconFor(lieu),
                                  iconColor: _iconColor(lieu),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // -------------- Skeleton --------------
  Widget _skeletonGrid(BuildContext context, int crossCount, double ratio) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

  Widget _premiumPlaceholder() {
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
            // ✅ IMAGE NETTE (AspectRatio fixe + decode à la vraie taille)
            AspectRatio(
              aspectRatio: 16 / 11,
              child: LayoutBuilder(
                builder: (context, c) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final w = c.maxWidth;
                  final h = c.maxHeight;

                  final memW = (w.isFinite && w > 0) ? (w * dpr).round() : null;
                  final memH = (h.isFinite && h > 0) ? (h * dpr).round() : null;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheKey: imageUrl,
                        memCacheWidth: memW,
                        memCacheHeight: memH,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholderFadeInDuration: Duration.zero,
                        useOldImageOnUrlChange: true,
                        imageBuilder: (_, provider) => Image(
                          image: provider,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.high,
                        ),
                        placeholder: (_, __) => _premiumPlaceholder(),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFE5E7EB),
                          alignment: Alignment.center,
                          child: Icon(Icons.broken_image,
                              size: 40, color: Colors.grey.shade500),
                        ),
                      ),
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
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 140),
                                  child: Text(
                                    ville,
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
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ville,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                      if (distLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          distLabel!,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
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
          const AspectRatio(
            aspectRatio: 16 / 11,
            child: ColoredBox(color: Color(0xFFE5E7EB)),
          ),
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
