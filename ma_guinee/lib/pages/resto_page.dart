// lib/pages/resto_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../routes.dart';

class RestoPage extends StatefulWidget {
  const RestoPage({super.key});

  @override
  State<RestoPage> createState() => _RestoPageState();
}

class _RestoPageState extends State<RestoPage> {
  // Couleurs — Restaurants (on garde la palette)
  static const Color _restoPrimary   = Color(0xFFE76F51);
  static const Color _restoSecondary = Color(0xFFF4A261);
  static const Color _restoOnPrimary = Color(0xFFFFFFFF);

  // Neutres (comme Annonces/Tourisme “moins flashy”)
  static const Color _neutralBg      = Color(0xFFF7F7F9);
  static const Color _neutralSurface = Color(0xFFFFFFFF);
  static const Color _neutralBorder  = Color(0xFFE5E7EB);

  final _searchCtrl = TextEditingController();

  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  List<Map<String, dynamic>> _restos = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------- utils --------------------
  String _formatGNF(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remaining = s.length - i - 1;
      buf.write(s[i]);
      if (remaining > 0 && remaining % 3 == 0) buf.write('\u202F'); // espace fine
    }
    return '$buf GNF';
  }

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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _position = pos;

      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final city = (pm.locality?.isNotEmpty == true)
            ? pm.locality
            : (pm.subAdministrativeArea?.isNotEmpty == true
                ? pm.subAdministrativeArea
                : null);
        _villeGPS = city?.toLowerCase().trim();
      }
    } catch (e) {
      debugPrint('Erreur localisation: $e');
    }
  }

  double? _distanceMeters(
      double? lat1, double? lon1, double? lat2, double? lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  // -------------------- chargement --------------------
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await _getLocation();

      // On lit la VUE avec note_moyenne, nb_avis
      final data = await Supabase.instance.client
          .from('v_restaurants_ratings')
          .select()
          .order('nom');

      final restos = List<Map<String, dynamic>>.from(data);

      // Distances + tri
      for (final r in restos) {
        if (_position != null) {
          final lat = (r['latitude'] as num?)?.toDouble();
          final lon = (r['longitude'] as num?)?.toDouble();
          r['_distance'] = _distanceMeters(
              _position!.latitude, _position!.longitude, lat, lon);
        }
        // étoile entière à afficher (arrondi)
        final avg = (r['note_moyenne'] as num?)?.toDouble();
        if (avg != null) r['_avg_int'] = avg.round();
      }

      if (_position != null) {
        if (_villeGPS != null && _villeGPS!.isNotEmpty) {
          restos.sort((a, b) {
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
            return (a['nom'] ?? '').toString().compareTo(
                  (b['nom'] ?? '').toString(),
                );
          });
        } else {
          restos.sort((a, b) {
            final ad = (a['_distance'] as double?);
            final bd = (b['_distance'] as double?);
            if (ad != null && bd != null) return ad.compareTo(bd);
            if (ad != null) return -1;
            if (bd != null) return 1;
            return (a['nom'] ?? '').toString().compareTo(
                  (b['nom'] ?? '').toString(),
                );
          });
        }
      }

      _restos = restos;
      _applyFilter(_searchCtrl.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String value) {
    final q = value.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _filtered = _restos);
      return;
    }
    setState(() {
      _filtered = _restos.where((r) {
        final nom = (r['nom'] ?? '').toString().toLowerCase();
        final ville = (r['ville'] ?? '').toString().toLowerCase();
        return nom.contains(q) || ville.contains(q);
      }).toList();
    });
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  Widget _buildStarsInt(int n) {
    final c = n.clamp(0, 5);
    return Row(
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

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final subtitleInfo = (_position != null && _villeGPS != null)
        ? 'Autour de ${_villeGPS!.isEmpty ? "vous" : _villeGPS}'
        : (_locationDenied ? 'Localisation refusée — tri par défaut' : null);

    const bottomGradient = LinearGradient(
      colors: [_restoPrimary, _restoSecondary],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Scaffold(
      backgroundColor: _neutralBg,
      appBar: AppBar(
        title: const Text(
          'Restaurants',
          style: TextStyle(color: _restoPrimary, fontWeight: FontWeight.w700),
        ),
        backgroundColor: _neutralSurface,   // AppBar blanche
        foregroundColor: _restoPrimary,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _restoPrimary),
            onPressed: _loadAll,
            tooltip: 'Rafraîchir',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _restos.isEmpty
              ? const Center(child: Text('Aucun restaurant trouvé.'))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      // Bandeau d’accroche — version subtile
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _restoPrimary.withOpacity(0.08), // fond pâle
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _restoPrimary.withOpacity(0.15)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.restaurant_menu, color: _restoPrimary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Découvrez les meilleurs restaurants de Guinée',
                                    style: TextStyle(
                                      color: _restoPrimary,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (subtitleInfo != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitleInfo,
                                      style: TextStyle(
                                        color: Colors.black.withOpacity(.55),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Recherche — neutre
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un resto ou une ville…',
                          prefixIcon: const Icon(Icons.search, color: _restoPrimary),
                          filled: true,
                          fillColor: _neutralSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _neutralBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _neutralBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _restoSecondary, width: 1.5),
                          ),
                        ),
                        onChanged: _applyFilter,
                      ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: RefreshIndicator(
                          color: _restoPrimary,
                          onRefresh: _loadAll,
                          child: _filtered.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 200),
                                    Center(child: Text('Aucun restaurant trouvé.')),
                                  ],
                                )
                              : GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 0.77,
                                  ),
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, i) {
                                    final resto = _filtered[i];

                                    final images = _imagesFrom(resto['images']);
                                    final image = images.isNotEmpty
                                        ? images.first
                                        : 'https://via.placeholder.com/300x200.png?text=Restaurant';

                                    final hasPrix = (resto['prix'] is num) ||
                                        (resto['prix'] is String &&
                                            (resto['prix'] as String).trim().isNotEmpty);
                                    final prixVal = (resto['prix'] is num)
                                        ? (resto['prix'] as num).toInt()
                                        : int.tryParse((resto['prix'] ?? '').toString());

                                    final avgInt =
                                        (resto['_avg_int'] as int?) ??
                                        ((resto['note_moyenne'] is num)
                                            ? (resto['note_moyenne'] as num).round()
                                            : null) ??
                                        ((resto['etoiles'] is int)
                                            ? resto['etoiles'] as int
                                            : null);

                                    return GestureDetector(
                                      onTap: () {
                                        final String restoId = resto['id'].toString();
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.restoDetail,
                                          arguments: restoId,
                                        );
                                      },
                                      child: Card(
                                        color: _neutralSurface,
                                        elevation: 1.5,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: const BorderSide(color: _neutralBorder),
                                        ),
                                        clipBehavior: Clip.hardEdge,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            AspectRatio(
                                              aspectRatio: 16 / 11,
                                              child: Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: Image.network(
                                                      image,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        color: Colors.grey[200],
                                                        child: const Icon(
                                                          Icons.restaurant,
                                                          size: 40,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if ((resto['ville'] ?? '').toString().isNotEmpty)
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
                                                              resto['ville'].toString(),
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
                                            Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 8),
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
                                                      Flexible(
                                                        child: Text(
                                                          (resto['ville'] ?? '').toString(),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      if (resto.containsKey('_distance') &&
                                                          resto['_distance'] != null) ...[
                                                        const Text('  •  ',
                                                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                                                        Text(
                                                          '${(resto['_distance'] / 1000).toStringAsFixed(1)} km',
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
                                                        style: const TextStyle(
                                                          color: _restoPrimary,
                                                          fontSize: 12,
                                                        ),
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
                    ],
                  ),
                ),
    );
  }
}
