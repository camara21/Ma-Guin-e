// lib/pages/hotel_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'hotel_detail_page.dart';

// ⬇️ AppCache (SWR)
import '../services/app_cache.dart';
// ⬇️ NEW: centralisation de l’envoi vers la table `utilisateurs`
import '../services/geoloc_service.dart';

class HotelPage extends StatefulWidget {
  const HotelPage({super.key});

  @override
  State<HotelPage> createState() => _HotelPageState();
}

class _HotelPageState extends State<HotelPage> {
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

  // ✅ Cache mémoire global (pour affichage instantané quand on revient)
  static List<Map<String, dynamic>> _memoryCacheHotels = [];

  // Données
  List<Map<String, dynamic>> hotels = [];
  List<Map<String, dynamic>> filteredHotels = [];

  // État
  bool _hasAnyCache = false; // sait si on a au moins un snapshot pour afficher
  bool _syncing = false; // rafraîchissement en arrière-plan

  // ⭐️ notes moyennes calculées en batch
  final Map<String, double> _avgByHotelId = {};
  final Map<String, int> _countByHotelId = {};

  // Recherche
  String searchQuery = '';

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();

    // 0) Cache mémoire global (instantané, même session)
    if (_memoryCacheHotels.isNotEmpty) {
      hotels = List<Map<String, dynamic>>.from(_memoryCacheHotels);
      filteredHotels = hotels;
      _hasAnyCache = true;
    }

    // 1) SWR classique (AppCache + réseau en arrière-plan)
    _loadAll(); // ne bloque pas l’UI
  }

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
  // -------------------------------------

  // ---------------- Localisation ----------------
  Future<void> _getLocation() async {
    _position = null;
    _villeGPS = null;
    _locationDenied = false;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationDenied = true;
        return;
      }

      // Last known position = instantané
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _position = last;

      // Position actuelle en arrière-plan (améliore précision)
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
          .then((pos) async {
        _position = pos;
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
        _recomputeDistancesAndSort(); // met à jour tri dès qu’on a mieux
      }).catchError((_) {});

      // pousser la position côté serveur (silencieux)
      try {
        final used = _position;
        if (used != null) await GeolocService.reportPosition(used);
      } catch (_) {}
    } catch (e) {
      debugPrint('Erreur localisation hôtels: $e');
    }
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

  // ========= enrichissement distance + tri =========
  Future<List<Map<String, dynamic>>> _enrichAndSort(
      List<Map<String, dynamic>> list) async {
    await _getLocation();

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
          return (a['nom'] ?? '')
              .toString()
              .compareTo((b['nom'] ?? '').toString());
        });
      } else {
        list.sort((a, b) {
          final ad = (a['_distance'] as double?);
          final bd = (b['_distance'] as double?);
          if (ad != null && bd != null) return ad.compareTo(bd);
          if (ad != null) return -1;
          if (bd != null) return 1;
          return (a['nom'] ?? '')
              .toString()
              .compareTo((b['nom'] ?? '').toString());
        });
      }
    } else {
      list.sort((a, b) =>
          (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString()));
    }

    return list;
  }

  // --------- récupère moyennes ⭐️ en une requête ----------
  Future<void> _preloadAverages(List<String> ids) async {
    _avgByHotelId.clear();
    _countByHotelId.clear();
    if (ids.isEmpty) return;

    final orFilter = ids.map((id) => 'hotel_id.eq.$id').join(',');
    final rows = await Supabase.instance.client
        .from('avis_hotels')
        .select('hotel_id, etoiles')
        .or(orFilter);

    final list = List<Map<String, dynamic>>.from(rows);
    final Map<String, double> sums = {};
    final Map<String, int> counts = {};
    for (final r in list) {
      final id = (r['hotel_id'] ?? '').toString();
      final n = (r['etoiles'] as num?)?.toDouble() ?? 0.0;
      sums[id] = (sums[id] ?? 0.0) + n;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    for (final id in counts.keys) {
      _avgByHotelId[id] = (sums[id]! / counts[id]!.clamp(1, 1 << 30));
      _countByHotelId[id] = counts[id]!;
    }
  }

  void _filterHotels(String value) {
    final q = value.toLowerCase().trim();
    setState(() {
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
    });
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  Widget _starsFor(double? avg) {
    final val = (avg ?? 0);
    final filled = val.floor();
    return Row(
      children: List.generate(5, (i) {
        final icon = i < filled ? Icons.star : Icons.star_border;
        return Icon(icon, size: 14, color: Colors.amber);
      })
        ..add(
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(val == 0 ? '—' : val.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ),
    );
  }

  // =======================
  // CHARGEMENT SWR PRINCIPAL — instantané & sans gros spinner
  // =======================
  Future<void> _loadAll({bool forceNetwork = false}) async {
    // 1) Snapshot cache immédiat (AppCache) si pas forcé
    if (!forceNetwork && !_hasAnyCache) {
      final mem = AppCache.I.getListMemory(_CACHE_KEY, maxAge: _CACHE_MAX_AGE);
      List<Map<String, dynamic>>? disk;
      if (mem == null) {
        disk = await AppCache.I
            .getListPersistent(_CACHE_KEY, maxAge: _CACHE_MAX_AGE);
      }
      final snapshot = mem ?? disk;

      if (snapshot != null) {
        _hasAnyCache = true;

        final snapClone =
            snapshot.map((e) => Map<String, dynamic>.from(e)).toList();
        final enriched = await _enrichAndSort(snapClone);

        hotels = enriched;
        // ✅ met à jour le cache mémoire global
        _memoryCacheHotels = List<Map<String, dynamic>>.from(enriched);

        await _preloadAverages(
            enriched.map((e) => e['id'].toString()).toList());
        _filterHotels(searchQuery);
        if (mounted) setState(() {});
      }
    }

    // 2) Réseau en arrière-plan (UI inchangée)
    try {
      if (mounted) setState(() => _syncing = true);

      final data = await Supabase.instance.client.from('hotels').select('''
        id, nom, ville, adresse, prix,
        latitude, longitude, images, description, created_at
      ''');

      final list = List<Map<String, dynamic>>.from(data);

      final enriched = await _enrichAndSort(list);

      // Notes moyennes
      await _preloadAverages(enriched.map((e) => e['id'].toString()).toList());

      // Met à jour l'écran (sans bloquer)
      hotels = enriched;
      _memoryCacheHotels =
          List<Map<String, dynamic>>.from(enriched); // ✅ mémoire globale
      _filterHotels(searchQuery);

      // Persist cache (retire champs volatils)
      final toCache = enriched
          .map((h) {
            final clone = Map<String, dynamic>.from(h);
            clone.remove('_distance');
            return clone;
          })
          .toList(growable: false)
          .cast<Map<String, dynamic>>();

      AppCache.I.setList(_CACHE_KEY, toCache, persist: true);

      if (mounted) setState(() => _hasAnyCache = true);
    } catch (e) {
      if (mounted && !_hasAnyCache) {
        // cold start sans cache => on reste sur skeleton + snack discret
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Réseau lent — affichage du squelette. ($e)'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _recomputeDistancesAndSort() {
    if (hotels.isEmpty) return;
    // recompute
    if (_position != null) {
      for (final h in hotels) {
        final lat = (h['latitude'] as num?)?.toDouble();
        final lon = (h['longitude'] as num?)?.toDouble();
        h['_distance'] = _distanceMeters(
            _position!.latitude, _position!.longitude, lat, lon);
      }
    }
    // sort
    if ((_villeGPS ?? '').isNotEmpty && _position != null) {
      hotels.sort((a, b) {
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
        return (a['nom'] ?? '')
            .toString()
            .compareTo((b['nom'] ?? '').toString());
      });
    } else if (_position != null) {
      hotels.sort((a, b) {
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
      hotels.sort((a, b) =>
          (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString()));
    }
    _filterHotels(searchQuery);
  }

  // ---------- Skeleton grid (aucun spinner) ----------
  Widget _skeletonGrid(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final crossCount = screenW < 600
        ? max(2, (screenW / 200).floor())
        : max(3, (screenW / 240).floor());
    final totalHGap = (crossCount - 1) * 8.0 + 0;
    final itemW = (screenW - totalHGap - 28) / crossCount;
    final itemH = itemW * (11 / 16) + 118.0;
    final ratio = itemW / itemH;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: ratio,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => const _HotelSkeletonCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // clamp léger du textScale
    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);

    // grille responsive serrée
    final screenW = media.size.width;
    final crossCount = screenW < 600
        ? max(2, (screenW / 200).floor())
        : max(3, (screenW / 240).floor());
    final totalHGap = (crossCount - 1) * 8.0 + 0;
    final itemW = (screenW - totalHGap - 28) / crossCount;
    final itemH = itemW * (11 / 16) + 118.0;
    final ratio = itemW / itemH;

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
                  color: hotelsPrimary,
                  fontWeight: FontWeight.bold,
                ),
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
              onPressed: () => _loadAll(
                  forceNetwork: true), // instantané, UI conserve la grille
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
        body: (!_hasAnyCache && !_syncing)
            // Cold start sans cache => skeleton (aucun spinner global)
            ? _skeletonGrid(context)
            // Sinon, affiche la grille instantanément.
            : (hotels.isEmpty
                ? const Center(child: Text("Aucun hôtel trouvé."))
                : Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          onChanged: _filterHotels,
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

                        // Grille d'hôtels
                        Expanded(
                          child: filteredHotels.isEmpty
                              ? const Center(child: Text("Aucun hôtel trouvé."))
                              : GridView.builder(
                                  padding: EdgeInsets.zero,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossCount,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: ratio,
                                  ),
                                  cacheExtent: 900,
                                  itemCount: filteredHotels.length,
                                  itemBuilder: (context, index) {
                                    final hotel = filteredHotels[index];
                                    final id = hotel['id'].toString();
                                    final avg = _avgByHotelId[id];
                                    final count = _countByHotelId[id] ?? 0;

                                    final images = _imagesFrom(hotel['images']);
                                    final image = images.isNotEmpty
                                        ? images.first
                                        : 'https://via.placeholder.com/300x200.png?text=H%C3%B4tel';

                                    return Card(
                                      margin: EdgeInsets.zero,
                                      elevation: 1.5,
                                      color: neutralSurface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: const BorderSide(
                                            color: neutralBorder),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => HotelDetailPage(
                                              hotelId: hotel['id'],
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Image 16:11 nette avec fade-in + badge ville
                                            Expanded(
                                              child: LayoutBuilder(
                                                builder: (ctx, c) {
                                                  final w = c.maxWidth;
                                                  final h = w * (11 / 16);
                                                  return Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      _FadeInNetworkImage(
                                                        url: image,
                                                        cacheWidth: w.isFinite
                                                            ? (w * 2).round()
                                                            : null,
                                                        cacheHeight: h.isFinite
                                                            ? (h * 2).round()
                                                            : null,
                                                      ),
                                                      if ((hotel['ville'] ?? '')
                                                          .toString()
                                                          .isNotEmpty)
                                                        Positioned(
                                                          left: 8,
                                                          top: 8,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: hotelsPrimary
                                                                  .withOpacity(
                                                                      .85),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Icon(
                                                                  Icons
                                                                      .location_on,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  (hotel['ville'] ??
                                                                          '')
                                                                      .toString(),
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
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
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      10, 8, 10, 10),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    (hotel['nom'] ?? "Sans nom")
                                                        .toString(),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  // ⭐️ Note moyenne
                                                  Row(
                                                    children: [
                                                      _starsFor(avg),
                                                      if (count > 0)
                                                        Text(
                                                          '  ($count)',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                Colors.black45,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  // Ville + distance
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          (hotel['ville'] ?? '')
                                                              .toString(),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      if (hotel.containsKey(
                                                              '_distance') &&
                                                          hotel['_distance'] !=
                                                              null) ...[
                                                        const Text(
                                                          '  •  ',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${(hotel['_distance'] / 1000).toStringAsFixed(1)} km',
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  // Prix — toujours "GNF / nuit"
                                                  if ((hotel['prix'] ?? '')
                                                      .toString()
                                                      .isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 3),
                                                      child: Text(
                                                        'Prix : ${_formatGNF(hotel['prix'])} GNF / nuit',
                                                        style: const TextStyle(
                                                          color: hotelsPrimary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
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

// ----------------- Image réseau avec fade-in + placeholder gris (sans spinner) -----------------
class _FadeInNetworkImage extends StatefulWidget {
  final String url;
  final int? cacheWidth;
  final int? cacheHeight;

  const _FadeInNetworkImage({
    required this.url,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  State<_FadeInNetworkImage> createState() => _FadeInNetworkImageState();
}

class _FadeInNetworkImageState extends State<_FadeInNetworkImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _ctrl.value = 0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      fit: BoxFit.cover,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      // ✅ aucun spinner : simple bloc gris pendant le chargement
      loadingBuilder: (ctx, child, ev) {
        if (ev == null) {
          _ctrl.forward();
          return FadeTransition(opacity: _fade, child: child);
        }
        return Container(color: Colors.grey.shade200);
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image,
          size: 40,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

// --------- Skeleton Card (aucun spinner) ----------
class _HotelSkeletonCard extends StatelessWidget {
  const _HotelSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: _HotelPageState.neutralSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _HotelPageState.neutralBorder),
      ),
      elevation: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 11,
            child: Container(color: Colors.grey.shade200),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 90,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 120,
                  color: Colors.grey.shade200,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
