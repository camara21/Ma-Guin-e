// lib/pages/sante_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'sante_detail_page.dart';
import '../services/app_cache.dart';
import '../services/geoloc_service.dart'; // ✅ centralise l’envoi de la position

class SantePage extends StatefulWidget {
  const SantePage({super.key});

  @override
  State<SantePage> createState() => _SantePageState();
}

class _SantePageState extends State<SantePage> {
  // Cache key (mémoire + disque via AppCache)
  static const String _cacheKey = 'sante:centres:list:v1';

  // Données
  List<Map<String, dynamic>> centres = [];
  List<Map<String, dynamic>> filteredCentres = [];
  bool loading = true;      // uniquement pour 1er skeleton
  String searchQuery = '';

  // Localisation
  Position? _position;
  String? _villeGPS;

  // Palette Santé
  static const Color primaryColor   = Color(0xFF009460); // vert
  static const Color secondaryColor = Color(0xFFFCD116); // jaune

  @override
  void initState() {
    super.initState();
    _loadCentresSWR(); // ⚡ instantané (cache) + sync réseau en arrière-plan
  }

  // ---------------- Localisation (non bloquante) ----------------
  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      // 1) last known -> instantané
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _position = last;
        unawaited(_reverseCity(last));
      }

      // 2) permission + position fraîche en AR
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return;
      }

      Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).then((pos) async {
        _position = pos;
        // pousse la position (RPC + dédoublonnage)
        try { await GeolocService.reportPosition(pos); } catch (_) {}
        await _reverseCity(pos);
        // dès qu’on a mieux -> retrie local + rafraîchit
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

  // Distance précise
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

  // --------- SWR: cache -> réseau (instantané, sans spinner) ----------
  Future<void> _loadCentresSWR() async {
    // affiche le cache immédiatement s’il existe (mémoire ou disque)
    final cached =
        AppCache.I.getList(_cacheKey, maxAge: const Duration(hours: 24));
    if (cached != null && cached.isNotEmpty) {
      centres = List<Map<String, dynamic>>.from(cached);
      _filterCentres(searchQuery);
      if (mounted) setState(() => loading = false);
    } else {
      if (mounted) setState(() => loading = true);
    }

    // localisation en parallèle (non bloquante)
    unawaited(_getLocation());

    // réseau en arrière-plan (pas de spinner, on remplace l’UI quand on a mieux)
    try {
      final data = await Supabase.instance.client
          .from('cliniques')
          .select(
              'id, nom, ville, specialites, description, images, latitude, longitude')
          .order('nom');

      final list = List<Map<String, dynamic>>.from(data);

      // enrichissement distances + tri
      _enrichDistancesAndSort(list);

      // persist cache
      AppCache.I.setList(_cacheKey, list);

      centres = list;
      _filterCentres(searchQuery);
      if (mounted) setState(() => loading = false);
    } catch (e) {
      // réseau lent : on garde l’UI actuelle (cache) sans bloquer
      if (mounted) setState(() => loading = false);
    }
  }

  void _enrichDistancesAndSort(List<Map<String, dynamic>> list) {
    if (_position != null) {
      for (final c in list) {
        final lat = (c['latitude'] as num?)?.toDouble();
        final lon = (c['longitude'] as num?)?.toDouble();
        c['_distance'] = _dist(_position!.latitude, _position!.longitude, lat, lon);
      }

      int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
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
          return (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());
        });
      }
    } else {
      list.sort((a, b) =>
          (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString()));
    }
  }

  void _recomputeDistancesAndSort() {
    if (centres.isEmpty) return;
    final list = centres.map((e) => Map<String, dynamic>.from(e)).toList();
    _enrichDistancesAndSort(list);
    centres = list;
    _filterCentres(searchQuery);
  }

  // RefreshIndicator appelle ça (instantané : pas de spinner)
  Future<void> _refresh() async {
    // on ne vide pas l’UI : on relit réseau et on remplace en fond
    await _loadCentresSWR();
  }

  // ---------------- Filtre ----------------
  void _filterCentres(String value) {
    final q = value.toLowerCase().trim();
    searchQuery = value;
    filteredCentres = centres.where((c) {
      final nom  = (c['nom'] ?? '').toString().toLowerCase();
      final ville = (c['ville'] ?? '').toString().toLowerCase();
      final spec = (c['specialites'] ?? c['description'] ?? '')
          .toString()
          .toLowerCase();
      return nom.contains(q) || ville.contains(q) || spec.contains(q);
    }).toList();
    if (mounted) setState(() {});
  }

  // ---------------- Helpers ----------------
  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  // -------- Skeleton (pas de spinner) ----------
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
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);

    final screenW = media.size.width;
    final crossCount = screenW < 600
        ? (screenW / 200).floor().clamp(2, 6)
        : (screenW / 240).floor().clamp(3, 6);
    final totalHGap = (crossCount - 1) * 8.0 + 16.0;
    final itemW = (screenW - totalHGap) / crossCount;
    final itemH = itemW * (11 / 16) + 112.0;
    final ratio = itemW / itemH;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "Services de santé",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: primaryColor),
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: primaryColor),
              onPressed: _refresh, // ⚡ instantané + sync AR
              tooltip: 'Rafraîchir',
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: loading
              ? _skeletonGrid(context) // premier rendu seulement
              : (centres.isEmpty
                  ? const Center(child: Text("Aucun centre de santé trouvé."))
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Column(
                        children: [
                          // Bandeau
                          Container(
                            width: double.infinity,
                            height: 72,
                            margin: const EdgeInsets.only(
                                left: 4, right: 4, bottom: 10),
                            decoration: const BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(16)),
                              gradient: LinearGradient(
                                colors: [secondaryColor, primaryColor],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Découvrez tous les centres et cliniques de Guinée",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Recherche
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText:
                                    'Rechercher un centre, une ville, une spécialité...',
                                prefixIcon:
                                    Icon(Icons.search, color: primaryColor),
                                filled: true,
                                fillColor: Color(0xFFF8F6F9),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(12)),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              onChanged: _filterCentres,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Grille serrée
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _refresh, // ⚡ instant + sync
                              child: filteredCentres.isEmpty
                                  ? ListView(
                                      children: const [
                                        SizedBox(height: 200),
                                        Center(
                                            child:
                                                Text("Aucun centre trouvé.")),
                                      ],
                                    )
                                  : GridView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossCount,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                        childAspectRatio: ratio,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                      itemCount: filteredCentres.length,
                                      itemBuilder: (context, index) {
                                        final c = filteredCentres[index];
                                        final images = _imagesFrom(c['images']);
                                        final img = images.isNotEmpty
                                            ? images[0]
                                            : 'https://via.placeholder.com/300x200.png?text=Sant%C3%A9';

                                        return InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SanteDetailPage(
                                                    cliniqueId: c['id']),
                                              ),
                                            );
                                          },
                                          child: Card(
                                            margin: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            elevation: 1.5,
                                            clipBehavior: Clip.antiAlias,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Image 16:11 + badge ville
                                                Expanded(
                                                  child: LayoutBuilder(
                                                    builder:
                                                        (context, cons) {
                                                      final w = cons.maxWidth;
                                                      final h = w * (11 / 16);
                                                      return Stack(
                                                        fit: StackFit.expand,
                                                        children: [
                                                          CachedNetworkImage(
                                                            imageUrl: img,
                                                            fit: BoxFit.cover,
                                                            memCacheWidth: w
                                                                    .isFinite
                                                                ? (w * 2).round()
                                                                : null,
                                                            memCacheHeight: h
                                                                    .isFinite
                                                                ? (h * 2).round()
                                                                : null,
                                                            placeholder: (_,
                                                                    __) =>
                                                                Container(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade200),
                                                            errorWidget:
                                                                (_, __, ___) =>
                                                                    Container(
                                                              color: Colors.grey
                                                                  .shade200,
                                                              child: const Icon(
                                                                Icons
                                                                    .local_hospital,
                                                                size: 40,
                                                                color: Colors
                                                                    .grey,
                                                              ),
                                                            ),
                                                          ),
                                                          if ((c['ville'] ?? '')
                                                              .toString()
                                                              .isNotEmpty)
                                                            Positioned(
                                                              left: 8,
                                                              top: 8,
                                                              child: Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        4),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                          0.55),
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
                                                                        size:
                                                                            14,
                                                                        color: Colors
                                                                            .white),
                                                                    const SizedBox(
                                                                        width:
                                                                            4),
                                                                    Text(
                                                                      c['ville']
                                                                          .toString(),
                                                                      style: const TextStyle(
                                                                          color: Colors
                                                                              .white,
                                                                          fontSize:
                                                                              12),
                                                                      maxLines:
                                                                          1,
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
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        (c['nom'] ??
                                                                "Sans nom")
                                                            .toString(),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 3),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              (c['ville'] ??
                                                                      '')
                                                                  .toString(),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ),
                                                          if (c.containsKey(
                                                                  '_distance') &&
                                                              c['_distance'] !=
                                                                  null) ...[
                                                            const SizedBox(
                                                                width: 6),
                                                            Text(
                                                              '${(c['_distance'] / 1000).toStringAsFixed(1)} km',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .fade,
                                                              style:
                                                                  const TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      if ((c['specialites'] ??
                                                              '')
                                                          .toString()
                                                          .isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 2),
                                                          child: Text(
                                                            c['specialites']
                                                                .toString(),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  primaryColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
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
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    )),
        ),
      ),
    );
  }
}

// ------------------ Skeleton Card --------------------
class _SkeletonCard extends StatelessWidget {
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
                Container(height: 12, width: 90,  color: Colors.grey.shade200),
                const SizedBox(height: 6),
                Container(height: 12, width: 70,  color: Colors.grey.shade200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
