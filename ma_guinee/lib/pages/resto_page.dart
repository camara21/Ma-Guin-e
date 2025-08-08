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
        final p = placemarks.first;
        final city = (p.locality?.isNotEmpty == true)
            ? p.locality
            : (p.subAdministrativeArea?.isNotEmpty == true
                ? p.subAdministrativeArea
                : null);
        _villeGPS = city?.toLowerCase().trim();
      }
    } catch (e) {
      debugPrint('Erreur localisation: $e');
    }
  }

  double? _distanceMeters(
      double? lat1, double? lon1, double? lat2, double? lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
    const R = 6371000.0;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await _getLocation();

      final data = await Supabase.instance.client
          .from('restaurants')
          .select('''
            id, nom, ville, adresse, tel, whatsapp,
            prix, etoiles, description,
            latitude, longitude,
            images, specialites, horaires,
            created_at, updated_at, user_id
          ''')
          .order('nom');

      final restos = List<Map<String, dynamic>>.from(data);

      if (_position != null) {
        for (final r in restos) {
          final lat = (r['latitude'] as num?)?.toDouble();
          final lon = (r['longitude'] as num?)?.toDouble();
          r['_distance'] = _distanceMeters(
              _position!.latitude, _position!.longitude, lat, lon);
        }

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

  Widget _buildStars(dynamic raw) {
    final n = (raw is int) ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          i < n ? Icons.star : Icons.star_border,
          size: 14,
          color: const Color(0xFFFBC02D),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bleu = Color(0xFF113CFC);

    final subtitleInfo = (_position != null && _villeGPS != null)
        ? 'Autour de ${_villeGPS!.isEmpty ? "vous" : _villeGPS}'
        : (_locationDenied ? "Localisation refusée — tri par défaut" : null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Restaurants'),
        backgroundColor: Colors.white,
        foregroundColor: bleu,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _restos.isEmpty
              ? const Center(child: Text("Aucun restaurant trouvé."))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 76,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFCD116), Color(0xFF009460)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Découvrez les meilleurs restaurants de Guinée",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                if (subtitleInfo != null)
                                  Text(
                                    subtitleInfo,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un resto ou une ville...',
                          prefixIcon: const Icon(Icons.search, color: bleu),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6F9),
                        ),
                        onChanged: _applyFilter,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadAll,
                          child: _filtered.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 200),
                                    Center(child: Text("Aucun restaurant trouvé.")),
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
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
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
                                                        child: const Icon(Icons.restaurant,
                                                            size: 40, color: Colors.grey),
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
                                                    (resto['nom'] ?? "Sans nom").toString(),
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
                                                            style: TextStyle(
                                                                color: Colors.grey, fontSize: 13)),
                                                        Text(
                                                          '${(resto['_distance'] / 1000).toStringAsFixed(1)} km',
                                                          style: const TextStyle(
                                                              color: Colors.grey, fontSize: 13),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if ((resto['prix'] ?? '').toString().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Text(
                                                        'Prix : ${resto['prix']}',
                                                        style: const TextStyle(
                                                          color: Color(0xFF009460),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  if (resto['etoiles'] != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: _buildStars(resto['etoiles']),
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
