// lib/pages/resto_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../routes.dart';
import '../services/app_cache.dart';
import '../services/geoloc_service.dart'; // centralisation envoi position

class RestoPage extends StatefulWidget {
  const RestoPage({super.key});
  @override
  State<RestoPage> createState() => _RestoPageState();
}

class _RestoPageState extends State<RestoPage> {
  // Couleurs — Restaurants
  static const Color _restoPrimary   = Color(0xFFE76F51);
  static const Color _restoSecondary = Color(0xFFF4A261);
  static const Color _restoOnPrimary = Color(0xFFFFFFFF);

  // Neutres
  static const Color _neutralBg      = Color(0xFFF7F7F9);
  static const Color _neutralSurface = Color(0xFFFFFFFF);
  static const Color _neutralBorder  = Color(0xFFE5E7EB);

  // Cache
  static const String _cacheKey = 'restaurants:list:v1';

  final _searchCtrl = TextEditingController();

  // Données
  List<Map<String, dynamic>> _restos   = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true; // pour afficher les squelettes

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAllSWR(); // instantané (cache) + sync réseau
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ======= Distance précise (Haversine) =======
  double? _distanceMeters(double? lat1, double? lon1, double? lat2, double? lon2) {
    if ([lat1, lon1, lat2, lon2].any((v) => v == null)) return null;
    const R = 6371000.0;
    final dLat = (lat2! - lat1!) * (pi / 180);
    final dLon = (lon2! - lon1!) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
        sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
  // ============================================

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

  // ---------- Localisation non bloquante ----------
  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        _locationDenied = true;
        return;
      }

      // 1) last known → instantané
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _position = last;
        _recomputeDistancesAndSort(); // affiche distance tout de suite
      }

      // 2) position actuelle en arrière-plan → retri quand dispo
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium).then((pos) async {
        _position = pos;

        try {
          await GeolocService.reportPosition(pos); // silencieux si erreur
        } catch (_) {}

        try {
          final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (marks.isNotEmpty) {
            final m = marks.first;
            final city = (m.locality?.isNotEmpty == true)
                ? m.locality
                : (m.subAdministrativeArea?.isNotEmpty == true ? m.subAdministrativeArea : null);
            _villeGPS = city?.toLowerCase().trim();
          }
        } catch (_) {}

        _recomputeDistancesAndSort();
      }).catchError((_) {});
    } catch (e) {
      debugPrint('Erreur localisation resto: $e');
    }
  }

  // ---------- SWR : montre le cache immédiatement puis synchronise ----------
  Future<void> _loadAllSWR() async {
    // 1) Mémoire → instant
    final mem = AppCache.I.getListMemory(_cacheKey, maxAge: const Duration(days: 7));
    if (mem != null && mem.isNotEmpty) {
      _restos = List<Map<String, dynamic>>.from(mem);
      _applyFilter(_searchCtrl.text);
      if (mounted) setState(() => _loading = false);
    } else {
      // 2) Disque (persistance) → quasi instant
      final disk = await AppCache.I.getListPersistent(_cacheKey, maxAge: const Duration(days: 14));
      if (disk != null && disk is List && disk.isNotEmpty) {
        _restos = List<Map<String, dynamic>>.from(disk);
        _applyFilter(_searchCtrl.text);
        if (mounted) setState(() => _loading = false);
      } else {
        if (mounted) setState(() => _loading = true); // squelettes si aucun cache
      }
    }

    // 3) Sync réseau en arrière-plan (ne bloque pas l’UI)
    unawaited(_loadFromNetwork());
    // 4) Géoloc en parallèle
    unawaited(_getLocation());
  }

  Future<void> _loadFromNetwork() async {
    try {
      final data = await Supabase.instance.client
          .from('v_restaurants_ratings') // adapte si nécessaire
          .select()
          .order('nom');

      final restos = List<Map<String, dynamic>>.from(data);

      // Ajout distance + note arrondie
      if (_position != null) {
        for (final r in restos) {
          final lat = (r['latitude'] as num?)?.toDouble();
          final lon = (r['longitude'] as num?)?.toDouble();
          r['_distance'] = _distanceMeters(_position!.latitude, _position!.longitude, lat, lon);
        }
      }
      for (final r in restos) {
        final avg = (r['note_moyenne'] as num?)?.toDouble();
        if (avg != null) r['_avg_int'] = avg.round();
      }

      // Tri (ville courante > distance > nom)
      void sortByDistance(List<Map<String, dynamic>> list) {
        int byName(a, b) => (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());
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

      sortByDistance(restos);

      // Écrit dans le cache (mémoire + disque)
      AppCache.I.setList(_cacheKey, restos, persist: true);

      _restos = restos;
      _applyFilter(_searchCtrl.text);
      if (mounted && _loading) setState(() => _loading = false);
    } catch (e) {
      // On garde le cache à l’écran, pas de spinner
      debugPrint('Erreur réseau restos: $e');
      if (_restos.isEmpty && mounted) setState(() => _loading = false);
    }
  }

  void _recomputeDistancesAndSort() {
    if (_restos.isEmpty || _position == null) {
      if (mounted) setState(() {}); // petit rebuild
      return;
    }
    for (final r in _restos) {
      final lat = (r['latitude'] as num?)?.toDouble();
      final lon = (r['longitude'] as num?)?.toDouble();
      r['_distance'] = _distanceMeters(_position!.latitude, _position!.longitude, lat, lon);
    }

    // Tri cohérent
    _restos.sort((a, b) {
      final aSame = (a['ville'] ?? '').toString().toLowerCase().trim() == _villeGPS;
      final bSame = (b['ville'] ?? '').toString().toLowerCase().trim() == _villeGPS;
      if ((_villeGPS ?? '').isNotEmpty && aSame != bSame) return aSame ? -1 : 1;
      final ad = (a['_distance'] as double?);
      final bd = (b['_distance'] as double?);
      if (ad != null && bd != null) return ad.compareTo(bd);
      if (ad != null) return -1;
      if (bd != null) return 1;
      return (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());
    });

    _applyFilter(_searchCtrl.text);
  }

  // ---------- Filtre ----------
  void _applyFilter(String value) {
    final q = value.toLowerCase().trim();
    final filtered = q.isEmpty
        ? _restos
        : _restos.where((r) {
            final nom = (r['nom'] ?? '').toString().toLowerCase();
            final ville = (r['ville'] ?? '').toString().toLowerCase();
            return nom.contains(q) || ville.contains(q);
          }).toList();
    if (mounted) {
      setState(() => _filtered = filtered);
    } else {
      _filtered = filtered;
    }
  }

  // ---------- UI helpers ----------
  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  Widget _buildStarsInt(int n) {
    final c = n.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(i < c ? Icons.star : Icons.star_border, size: 14, color: _restoSecondary),
      ),
    );
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

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    const bottomGradient = LinearGradient(
      colors: [_restoPrimary, _restoSecondary],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    // Grille “serrée” identique à Divertissement/Santé
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
          title: const Text('Restaurants',
              style: TextStyle(color: _restoPrimary, fontWeight: FontWeight.w700)),
          backgroundColor: _neutralSurface,
          foregroundColor: _restoPrimary,
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: _restoPrimary),
              tooltip: 'Rafraîchir',
              onPressed: _loadAllSWR, // ⚡ instantané
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
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              // ----- Bandeau compact (fix débordement 1px) -----
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
              // -----------------------------------------------

              // Recherche (debounce léger pour éviter rebuilds)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un resto ou une ville…',
                    prefixIcon: Icon(Icons.search, color: _restoPrimary),
                    filled: true,
                    fillColor: _neutralSurface,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (t) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 220), () {
                      _applyFilter(t);
                    });
                  },
                ),
              ),

              // Grille — squelettes si _loading
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _loading
                      ? _skeletonGrid(context)
                      : RefreshIndicator(
                          color: _restoPrimary,
                          onRefresh: _loadAllSWR, // ⚡ instant + sync
                          child: _filtered.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 200),
                                    Center(child: Text('Aucun restaurant trouvé.')),
                                  ],
                                )
                              : GridView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossCount,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: ratio,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, i) {
                                    final resto = _filtered[i];
                                    final images = _imagesFrom(resto['images']);
                                    final image = images.isNotEmpty
                                        ? images.first
                                        : 'https://via.placeholder.com/300x200.png?text=Restaurant';

                                    final hasPrix = (resto['prix'] is num) ||
                                        (resto['prix'] is String && (resto['prix'] as String).trim().isNotEmpty);
                                    final prixVal = (resto['prix'] is num)
                                        ? (resto['prix'] as num).toInt()
                                        : int.tryParse((resto['prix'] ?? '').toString());

                                    final avgInt =
                                        (resto['_avg_int'] as int?) ??
                                        ((resto['note_moyenne'] is num)
                                            ? (resto['note_moyenne'] as num).round()
                                            : null) ??
                                        ((resto['etoiles'] is int) ? resto['etoiles'] as int : null);

                                    return InkWell(
                                      onTap: () {
                                        final String restoId = resto['id'].toString();
                                        Navigator.pushNamed(context, AppRoutes.restoDetail, arguments: restoId);
                                      },
                                      child: Card(
                                        margin: EdgeInsets.zero, // cartes serrées
                                        color: _neutralSurface,
                                        elevation: 1.5,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          side: const BorderSide(color: _neutralBorder),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // IMAGE 16:11 + badge ville (cached)
                                            Expanded(
                                              child: LayoutBuilder(
                                                builder: (context, cons) {
                                                  final w = cons.maxWidth;
                                                  final h = w * (11 / 16);
                                                  return Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      CachedNetworkImage(
                                                        imageUrl: image,
                                                        fit: BoxFit.cover,
                                                        memCacheWidth: w.isFinite ? (w * 2).round() : null,
                                                        memCacheHeight: h.isFinite ? (h * 2).round() : null,
                                                        placeholder: (_, __) =>
                                                            Container(color: Colors.grey[200]),
                                                        errorWidget: (_, __, ___) => Container(
                                                          color: Colors.grey[200],
                                                          child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                                                        ),
                                                      ),
                                                      if ((resto['ville'] ?? '').toString().isNotEmpty)
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
                                                                  resto['ville'].toString(),
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

                                            // TEXTE compact
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    (resto['nom'] ?? 'Sans nom').toString(),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          (resto['ville'] ?? '').toString(),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                                        ),
                                                      ),
                                                      if (resto.containsKey('_distance') && resto['_distance'] != null) ...[
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '${(resto['_distance'] / 1000).toStringAsFixed(1)} km',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.fade,
                                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (hasPrix && prixVal != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Text(
                                                        'Prix : ${_formatGNF(prixVal)} (plat)',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(color: _restoPrimary, fontSize: 12),
                                                      ),
                                                    ),
                                                  if (avgInt != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: _buildStarsInt(avgInt),
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
              ),
            ],
          ),
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
    );
  }
}
