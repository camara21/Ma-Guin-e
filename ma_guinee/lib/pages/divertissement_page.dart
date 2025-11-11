// lib/pages/divertissement_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'divertissement_detail_page.dart';

class DivertissementPage extends StatefulWidget {
  const DivertissementPage({super.key});

  @override
  State<DivertissementPage> createState() => _DivertissementPageState();
}

class _DivertissementPageState extends State<DivertissementPage> {
  // Données
  List<Map<String, dynamic>> _allLieux = [];
  List<Map<String, dynamic>> _filteredLieux = [];
  bool _loading = true;

  // Recherche (petit debounce)
  String searchQuery = '';
  Timer? _debounce;

  // Localisation
  Position? _position;
  String? _villeGPS;

  // Couleur
  static const primaryColor = Colors.deepPurple;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ====== Distance précise (même principe que Santé: Haversine) ======
  double? _distanceMeters(
      double? lat1, double? lon1, double? lat2, double? lon2) {
    if ([lat1, lon1, lat2, lon2].any((v) => v == null)) return null;

    // radians
    final double phi1 = lat1! * pi / 180.0;
    final double phi2 = lat2! * pi / 180.0;
    final double lam1 = lon1! * pi / 180.0;
    final double lam2 = lon2! * pi / 180.0;

    final double dPhi = phi2 - phi1;
    final double dLam = lam2 - lam1;

    final double a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLam / 2) * sin(dLam / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return 6371000.0 * c; // mètres
  }
  // -------------------------------------------------------------------

  // Localisation (non bloquante)
  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Last known = instantané
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _position = last;

      // Position actuelle en arrière-plan
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
        _recomputeDistancesAndSort(); // maj tri dès qu’on a la position fraîche
      }).catchError((_) {});
    } catch (e) {
      debugPrint('Erreur localisation divertissement: $e');
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // localisation en parallèle (non bloquante)
      unawaited(_getLocation());

      // Lieux + avis imbriqués (pour moyenne)
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
        l['_avg'] = count == 0 ? null : (sum / count);
        l['_count'] = count;
      }

      _allLieux = list;

      // Si on a déjà une position (last known), affiche tout de suite les distances
      _recomputeDistancesAndSort();

      _filterLieux(searchQuery);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recomputeDistancesAndSort() {
    if (_allLieux.isEmpty) {
      setState(() {}); // force rebuild si besoin
      return;
    }

    // Ajoute/MAJ distance si position connue
    if (_position != null) {
      for (final l in _allLieux) {
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

    // Tri: même ville -> distance -> nom (sinon: distance -> nom)
    int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());

    if ((_villeGPS ?? '').isNotEmpty && _position != null) {
      _allLieux.sort((a, b) {
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
    } else if (_position != null) {
      _allLieux.sort((a, b) {
        final ad = (a['_distance'] as double?);
        final bd = (b['_distance'] as double?);
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return byName(a, b);
      });
    } else {
      _allLieux.sort(byName);
    }

    // Rafraîchit la vue + garde le filtre courant
    _filterLieux(searchQuery, doSetState: true);
  }

  void _filterLieux(String query, {bool doSetState = true}) {
    final q = query.toLowerCase().trim();
    final filtered = _allLieux.where((lieu) {
      final nom = (lieu['nom'] ?? '').toString().toLowerCase();
      final ville = (lieu['ville'] ?? '').toString().toLowerCase();
      final tag =
          (lieu['type'] ?? lieu['categorie'] ?? lieu['description'] ?? '')
              .toString()
              .toLowerCase();
      return nom.contains(q) || ville.contains(q) || tag.contains(q);
    }).toList();

    if (doSetState) {
      setState(() {
        searchQuery = query;
        _filteredLieux = filtered;
      });
    } else {
      searchQuery = query;
      _filteredLieux = filtered;
    }
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  // ---------------- Skeletons ----------------
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

  @override
  Widget build(BuildContext context) {
    // limite légère du textScale
    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);

    // grille responsive (mêmes paramètres loading/data)
    final screenW = media.size.width;
    final crossCount = screenW < 600
        ? max(2, (screenW / 200).floor())
        : max(3, (screenW / 240).floor());
    final totalHGap = (crossCount - 1) * 8.0 + 16.0; // gaps + padding
    final itemW = (screenW - totalHGap) / crossCount;
    final itemH = itemW * (11 / 16) + 112.0;
    final ratio = itemW / itemH;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Divertissement'),
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 1.2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAll,
              tooltip: 'Rafraîchir',
              color: Colors.white,
            ),
          ],
        ),
        body: Column(
          children: [
            // Bandeau
            Container(
              width: double.infinity,
              height: 72,
              margin: const EdgeInsets.only(
                  left: 12, right: 12, top: 12, bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B1FA2), Color(0xFF00C9FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Bars, clubs, lounges et sorties à Conakry",
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

            // Recherche (debounce)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un lieu, une catégorie, une ville...',
                  prefixIcon: const Icon(Icons.search, color: primaryColor),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (txt) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 230), () {
                    _filterLieux(txt);
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
                    : (_filteredLieux.isEmpty
                        ? const Center(child: Text("Aucun lieu trouvé."))
                        : RefreshIndicator(
                            onRefresh: _loadAll,
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
                              itemCount: _filteredLieux.length,
                              itemBuilder: (context, index) {
                                final lieu = _filteredLieux[index];
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

// ======================== Carte adaptative ===========================
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

  static const primaryColor = Colors.deepPurple;

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
        margin: EdgeInsets.zero, // serré
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1.5,
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
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth: w.isFinite ? (w * 2).round() : null,
                      cacheHeight: h.isFinite ? (h * 2).round() : null,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image, size: 36),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
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
                              const Icon(Icons.location_on,
                                  size: 14, color: Colors.white),
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
