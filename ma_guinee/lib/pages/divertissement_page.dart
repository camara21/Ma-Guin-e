// lib/pages/divertissement_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/app_cache.dart';
import '../services/geoloc_service.dart';
import 'divertissement_detail_page.dart';

class DivertissementPage extends StatefulWidget {
  const DivertissementPage({super.key});

  @override
  State<DivertissementPage> createState() => _DivertissementPageState();
}

class _DivertissementPageState extends State<DivertissementPage> {
  // Couleurs
  static const Color primaryColor = Color(0xFF7B1FA2);
  static const Color secondaryColor = Color(0xFF00C9FF);
  static const Color onPrimary = Colors.white;

  static const Color _neutralBg = Color(0xFFF7F7F9);
  static const Color _neutralSurface = Color(0xFFFFFFFF);
  static const Color _neutralBorder = Color(0xFFE5E7EB);

  // Cache
  static const String _cacheKey = 'divertissement:list:v1';

  // Données
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _lieux = [];
  List<Map<String, dynamic>> _filtered = [];

  // État
  bool _loading = true; // skeleton quand pas encore de data
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
    _loadAllSWR(); // cache instantané + sync réseau
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ====== Distance précise (Haversine, même logique que Resto) ======
  double? _distanceMeters(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    if ([lat1, lon1, lat2, lon2].any((v) => v == null)) return null;

    const R = 6371000.0; // rayon Terre en mètres
    final dLat = (lat2! - lat1!) * (pi / 180.0);
    final dLon = (lon2! - lon1!) * (pi / 180.0);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    // ✅ formule correcte: atan2(sqrt(a), sqrt(1 - a))
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ---------- Localisation non bloquante ----------
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

      // 1) last known → instantané
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _position = last;
        _recomputeDistancesAndSort(); // distances quasi immédiates
      }

      // 2) position actuelle → en arrière-plan
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
          .then((pos) async {
        _position = pos;

        try {
          await GeolocService.reportPosition(pos); // silencieux si erreur
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
    } catch (e) {
      debugPrint('Erreur localisation divertissement: $e');
    }
  }

  // ---------- SWR : cache instantané + sync réseau ----------
  Future<void> _loadAllSWR() async {
    // 1) Lecture cache mémoire / disque
    final mem =
        AppCache.I.getListMemory(_cacheKey, maxAge: const Duration(days: 7));
    List<Map<String, dynamic>>? disk;
    if (mem == null) {
      disk = await AppCache.I
          .getListPersistent(_cacheKey, maxAge: const Duration(days: 14));
    }
    final snapshot = mem ?? disk;

    if (snapshot != null) {
      _lieux = List<Map<String, dynamic>>.from(snapshot);
      _applyFilter(_searchCtrl.text);
      _hasAnyCache = true;
      if (mounted) setState(() => _loading = false);
    } else {
      // premier chargement sans cache → skeleton
      if (mounted) setState(() => _loading = true);
    }

    // 2) Sync réseau en arrière-plan
    if (mounted) setState(() => _syncing = true);
    unawaited(_getLocation());

    try {
      final response = await Supabase.instance.client.from('lieux').select('''
        id, nom, ville, type, categorie, description,
        images, latitude, longitude, adresse, created_at,
        avis_lieux(etoiles)
      ''').eq('type', 'divertissement').order('nom', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);

      // moyenne & nb_avis
      for (final l in list) {
        final List avis = (l['avis_lieux'] as List?) ?? const [];
        int sum = 0;
        for (final a in avis) {
          sum += (a['etoiles'] as num?)?.toInt() ?? 0;
        }
        final count = avis.length;
        final avg = count == 0 ? null : (sum / count);
        l['_avg'] = avg;
        l['_count'] = count;
      }

      // Ajout distance si on a déjà une position
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
      }

      // Tri (même ville > distance > nom)
      void sortByDistance(List<Map<String, dynamic>> arr) {
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

      sortByDistance(list);

      // Écrit dans le cache (mémoire + disque)
      AppCache.I.setList(_cacheKey, list, persist: true);

      _lieux = list;
      _applyFilter(_searchCtrl.text);
      _hasAnyCache = true;

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Erreur réseau divertissement: $e');
      if (mounted && !_hasAnyCache) {
        _loading = false;
        setState(() {});
      }
    } finally {
      if (mounted) {
        _syncing = false;
        setState(() {});
      }
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

    int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());

    if ((_villeGPS ?? '').isNotEmpty) {
      _lieux.sort((a, b) {
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
      _lieux.sort((a, b) {
        final ad = (a['_distance'] as double?);
        final bd = (b['_distance'] as double?);
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return byName(a, b);
      });
    }

    _applyFilter(_searchCtrl.text);
  }

  // ---------- Filtre ----------
  void _applyFilter(String value) {
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

    if (mounted) {
      setState(() {
        _filtered = filtered;
      });
    } else {
      _filtered = filtered;
    }
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

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: _neutralBg,
        appBar: AppBar(
          title: const Text(
            'Divertissement',
            style: TextStyle(
              color: onPrimary,
              fontWeight: FontWeight.w700,
            ),
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
                icon: const Icon(Icons.refresh),
                onPressed: _loadAllSWR,
                tooltip: 'Rafraîchir',
                color: Colors.white,
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
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

            // Grille
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _loading
                    ? _skeletonGrid(context)
                    : (_filtered.isEmpty
                        ? const Center(child: Text("Aucun lieu trouvé."))
                        : RefreshIndicator(
                            onRefresh: _loadAllSWR,
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
            builder: (_) => DivertissementDetailPage(lieu: lieu),
          ),
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
            // IMAGE
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = w * (11 / 16);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: w.isFinite ? (w * 2).round() : null,
                      memCacheHeight: h.isFinite ? (h * 2).round() : null,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image, size: 36),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image, size: 40),
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
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (lieu['ville'] ?? '').toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (lieu['ville'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (lieu['_distance'] != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${(lieu['_distance'] / 1000).toStringAsFixed(1)} km',
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '($nbAvis avis)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
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
            child: Container(color: Colors.grey.shade200),
          ),
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
