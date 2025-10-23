// lib/pages/sante_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'sante_detail_page.dart';
import '../services/app_cache.dart';
import '../services/geoloc_service.dart'; // ✅ NEW: centralise l’envoi de la position

class SantePage extends StatefulWidget {
  const SantePage({super.key});

  @override
  State<SantePage> createState() => _SantePageState();
}

class _SantePageState extends State<SantePage> {
  // Cache key (mémoire)
  static const String _cacheKey = 'sante:centres:list:v1';

  // Données
  List<Map<String, dynamic>> centres = [];
  List<Map<String, dynamic>> filteredCentres = [];
  bool loading = true;
  bool syncing = false; // indique une sync réseau en cours
  String searchQuery = '';

  // Localisation
  Position? _position;
  String? _villeGPS;

  // Palette Santé
  static const Color primaryColor = Color(0xFF009460); // vert
  static const Color secondaryColor = Color(0xFFFCD116); // jaune

  @override
  void initState() {
    super.initState();
    _loadCentresSWR(); // ⚡ instantané (cache) + sync
  }

  // ---------------- Localisation ----------------
  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _position = pos;

      // ✅ NEW: pousse la position vers la table `utilisateurs` (RPC + dédoublonnage)
      try {
        await GeolocService.reportPosition(pos);
      } catch (_) {
        // silencieux : un échec réseau/RLS n'empêche pas l'UI
      }

      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final city = (m.locality?.isNotEmpty == true)
            ? m.locality
            : (m.subAdministrativeArea?.isNotEmpty == true ? m.subAdministrativeArea : null);
        _villeGPS = city?.toLowerCase().trim();
      }
    } catch (_) {}
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

  // ---------------- Chargement (SWR) ----------------
  Future<void> _loadCentresSWR() async {
    // 1) Affiche le cache immédiatement s’il existe
    final cached = AppCache.I.getList(_cacheKey, maxAge: const Duration(hours: 24));
    if (cached != null) {
      setState(() {
        loading = false;
        centres = cached;
        _filterCentres(searchQuery);
      });
    } else {
      setState(() => loading = true);
    }

    // 2) Requête réseau en arrière-plan puis MAJ UI
    setState(() => syncing = true);
    try {
      await _getLocation();

      // Sélection légère (garde description pour la recherche, mais pas indispensable à l’UI)
      final data = await Supabase.instance.client
          .from('cliniques')
          .select(
              'id, nom, ville, specialites, description, images, latitude, longitude')
          .order('nom');

      final list = List<Map<String, dynamic>>.from(data);

      // Distances + tri
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

      // Sauvegarde cache + MAJ UI
      AppCache.I.setList(_cacheKey, list);

      if (!mounted) return;
      setState(() {
        centres = list;
        _filterCentres(searchQuery);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Réseau lent — cache affiché. ($e)")),
      );
    } finally {
      if (mounted) setState(() => syncing = false);
      if (mounted && loading) setState(() => loading = false);
    }
  }

  // Ancien raccourci (pour RefreshIndicator)
  Future<void> _loadCentres() => _loadCentresSWR();

  // ---------------- Filtre ----------------
  void _filterCentres(String value) {
    final q = value.toLowerCase().trim();
    setState(() {
      searchQuery = value;
      filteredCentres = centres.where((c) {
        final nom = (c['nom'] ?? '').toString().toLowerCase();
        final ville = (c['ville'] ?? '').toString().toLowerCase();
        final spec = (c['specialites'] ?? c['description'] ?? '').toString().toLowerCase();
        return nom.contains(q) || ville.contains(q) || spec.contains(q);
      }).toList();
    });
  }

  // ---------------- UI helpers ----------------
  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              "Services de santé",
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
            ),
            if (syncing) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(secondaryColor)),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: primaryColor),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadCentresSWR, // ⚡ instant + sync
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : centres.isEmpty
              ? const Center(child: Text("Aucun centre de santé trouvé."))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      // Bandeau (JAUNE -> VERT)
                      Container(
                        width: double.infinity,
                        height: 75,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          gradient: LinearGradient(
                            colors: [secondaryColor, primaryColor],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Découvrez tous les centres et cliniques de Guinée",
                              style: TextStyle(
                                color: Colors.white,
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
                        decoration: const InputDecoration(
                          hintText: 'Rechercher un centre, une ville, une spécialité...',
                          prefixIcon: Icon(Icons.search, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          filled: true,
                          fillColor: Color(0xFFF8F6F9),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: _filterCentres,
                      ),
                      const SizedBox(height: 12),

                      // Grille
                      Expanded(
                        child: filteredCentres.isEmpty
                            ? const Center(child: Text("Aucun centre trouvé."))
                            : RefreshIndicator(
                                onRefresh: _loadCentresSWR, // ⚡ instant + sync
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final w = constraints.maxWidth;
                                    int crossAxisCount;
                                    if (w >= 980) {
                                      crossAxisCount = 4;
                                    } else if (w >= 720) {
                                      crossAxisCount = 3;
                                    } else if (w >= 380) {
                                      crossAxisCount = 2;
                                    } else {
                                      crossAxisCount = 1;
                                    }
                                    final aspect = (crossAxisCount == 1) ? 0.95 : 0.77;

                                    return GridView.builder(
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: 16,
                                        childAspectRatio: aspect,
                                      ),
                                      itemCount: filteredCentres.length,
                                      itemBuilder: (context, index) {
                                        final c = filteredCentres[index];
                                        final images = _imagesFrom(c['images']);
                                        final img = images.isNotEmpty
                                            ? images[0]
                                            : 'https://via.placeholder.com/300x200.png?text=Sant%C3%A9';

                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SanteDetailPage(cliniqueId: c['id']),
                                              ),
                                            );
                                          },
                                          child: Card(
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            clipBehavior: Clip.hardEdge,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Image + badge ville (cached)
                                                AspectRatio(
                                                  aspectRatio: 16 / 11,
                                                  child: Stack(
                                                    children: [
                                                      Positioned.fill(
                                                        child: CachedNetworkImage(
                                                          imageUrl: img,
                                                          fit: BoxFit.cover,
                                                          placeholder: (_, __) => Container(color: Colors.grey[200]),
                                                          errorWidget: (_, __, ___) => const Icon(
                                                            Icons.local_hospital,
                                                            size: 40,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                      if ((c['ville'] ?? '').toString().isNotEmpty)
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
                                                                Text(
                                                                  c['ville'].toString(),
                                                                  style: const TextStyle(
                                                                      color: Colors.white, fontSize: 12),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),

                                                // Texte
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 8),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        (c['nom'] ?? "Sans nom").toString(),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      // Ville + distance
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              (c['ville'] ?? '').toString(),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                color: Colors.grey,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ),
                                                          if (c['_distance'] != null) ...[
                                                            const Text(
                                                              '  •  ',
                                                              style: TextStyle(
                                                                color: Colors.grey,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                            Text(
                                                              '${(c['_distance'] / 1000).toStringAsFixed(1)} km',
                                                              style: const TextStyle(
                                                                color: Colors.grey,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      // Spécialités
                                                      if ((c['specialites'] ?? '').toString().isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 2),
                                                          child: Text(
                                                            c['specialites'].toString(),
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
                                      },
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
