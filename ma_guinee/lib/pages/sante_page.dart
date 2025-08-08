import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'sante_detail_page.dart';

class SantePage extends StatefulWidget {
  const SantePage({super.key});

  @override
  State<SantePage> createState() => _SantePageState();
}

class _SantePageState extends State<SantePage> {
  List<Map<String, dynamic>> centres = [];
  List<Map<String, dynamic>> filteredCentres = [];
  bool loading = true;
  String searchQuery = '';

  Position? _position;
  String? _villeGPS;

  static const primaryColor = Color(0xFF009460);

  @override
  void initState() {
    super.initState();
    _loadCentres();
  }

  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      _position = pos;

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
    final a = sin(dLat/2)*sin(dLat/2) + cos(lat1*(pi/180))*cos(lat2*(pi/180))*sin(dLon/2)*sin(dLon/2);
    return R * 2 * atan2(sqrt(a), sqrt(1-a));
  }

  Future<void> _loadCentres() async {
    setState(() => loading = true);
    try {
      await _getLocation();

      final data = await Supabase.instance.client
          .from('cliniques')
          .select('id, nom, ville, specialites, description, images, latitude, longitude')
          .order('nom');

      final list = List<Map<String, dynamic>>.from(data);

      if (_position != null) {
        for (final c in list) {
          final lat = (c['latitude'] as num?)?.toDouble();
          final lon = (c['longitude'] as num?)?.toDouble();
          c['_distance'] = _dist(_position!.latitude, _position!.longitude, lat, lon);
        }
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
            return (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString());
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
      }

      centres = list;
      _filterCentres(searchQuery);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

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

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Services de santé",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: primaryColor),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadCentres,
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
                      // Bandeau
                      Container(
                        width: double.infinity,
                        height: 75,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [primaryColor, Color(0xFF2EC4F1)],
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
                      // Recherche
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un centre, une ville, une spécialité...',
                          prefixIcon: const Icon(Icons.search, color: primaryColor),
                          border:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6F9),
                        ),
                        onChanged: _filterCentres,
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: filteredCentres.isEmpty
                            ? const Center(child: Text("Aucun centre trouvé."))
                            : RefreshIndicator(
                                onRefresh: _loadCentres,
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 0.77,
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
                                            builder: (_) =>
                                                SanteDetailPage(cliniqueId: c['id']),
                                          ),
                                        );
                                      },
                                      child: Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                        clipBehavior: Clip.hardEdge,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Image + badge ville
                                            AspectRatio(
                                              aspectRatio: 16 / 11,
                                              child: Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: Image.network(
                                                      img,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        color: Colors.grey[200],
                                                        child: const Icon(
                                                          Icons.local_hospital,
                                                          size: 40,
                                                          color: Colors.grey,
                                                        ),
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
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black
                                                              .withOpacity(0.55),
                                                          borderRadius:
                                                              BorderRadius.circular(12),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.location_on,
                                                                size: 14,
                                                                color: Colors.white),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              c['ville'].toString(),
                                                              style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 12),
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
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
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          (c['ville'] ?? '').toString(),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      if (c['_distance'] != null)
                                                        Text(
                                                          ' • ${(c['_distance'] / 1000).toStringAsFixed(1)} km',
                                                          style: const TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  if ((c['specialites'] ?? '')
                                                      .toString()
                                                      .isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(top: 2),
                                                      child: Text(
                                                        c['specialites'].toString(),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
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
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
