import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'hotel_detail_page.dart';

class HotelPage extends StatefulWidget {
  const HotelPage({super.key});

  @override
  State<HotelPage> createState() => _HotelPageState();
}

class _HotelPageState extends State<HotelPage> {
  // Données
  List<Map<String, dynamic>> hotels = [];
  List<Map<String, dynamic>> filteredHotels = [];
  bool loading = true;

  // Recherche
  String searchQuery = '';

  // Localisation
  Position? _position;
  String? _villeGPS;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

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
      debugPrint('Erreur localisation hôtels: $e');
    }
  }

  double? _distanceMeters(
      double? lat1, double? lon1, double? lat2, double? lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
    const R = 6371000.0;
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  // ----------------------------------------------

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      await _getLocation();

      // 🔧 Retirer "devise" du select
      final data = await Supabase.instance.client
          .from('hotels')
          .select('''
            id, nom, ville, adresse, prix,
            latitude, longitude, images, description, created_at
          ''')
          .order('nom');

      final list = List<Map<String, dynamic>>.from(data);

      // Distance + tri
      if (_position != null) {
        for (final h in list) {
          final lat = (h['latitude'] as num?)?.toDouble();
          final lon = (h['longitude'] as num?)?.toDouble();
          h['_distance'] =
              _distanceMeters(_position!.latitude, _position!.longitude, lat, lon);
        }

        if (_villeGPS != null && _villeGPS!.isNotEmpty) {
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

      hotels = list;
      _filterHotels(searchQuery);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur chargement hôtels : $e')));
    } finally {
      if (mounted) setState(() => loading = false);
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

  @override
  Widget build(BuildContext context) {
    const bleu = Color(0xFF113CFC);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: bleu,
        title: const Text(
          'Hôtels',
          style: TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : hotels.isEmpty
              ? const Center(child: Text("Aucun hôtel trouvé."))
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
                            colors: [Color(0xFF113CFC), Color(0xFF2EC4F1)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Trouvez l'hôtel parfait partout en Guinée",
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
                        decoration: InputDecoration(
                          hintText: 'Rechercher un hôtel, une ville...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF113CFC)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6F9),
                        ),
                        onChanged: _filterHotels,
                      ),
                      const SizedBox(height: 12),
                      // Grille d’hôtels
                      Expanded(
                        child: filteredHotels.isEmpty
                            ? const Center(child: Text("Aucun hôtel trouvé."))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.77,
                                ),
                                itemCount: filteredHotels.length,
                                itemBuilder: (context, index) {
                                  final hotel = filteredHotels[index];
                                  final images = _imagesFrom(hotel['images']);
                                  final image = images.isNotEmpty
                                      ? images.first
                                      : 'https://via.placeholder.com/300x200.png?text=H%C3%B4tel';

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => HotelDetailPage(
                                            hotelId: hotel['id'],
                                          ),
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
                                          // Image + badge ville
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
                                                        Icons.hotel,
                                                        size: 40,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if ((hotel['ville'] ?? '')
                                                    .toString()
                                                    .isNotEmpty)
                                                  Positioned(
                                                    left: 8,
                                                    top: 8,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                              horizontal: 8, vertical: 4),
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
                                                            hotel['ville'].toString(),
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
                                                  (hotel['nom'] ?? "Sans nom")
                                                      .toString(),
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
                                                        (hotel['ville'] ?? '').toString(),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    if (hotel.containsKey('_distance') &&
                                                        hotel['_distance'] != null) ...[
                                                      const Text(
                                                        '  •  ',
                                                        style: TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${(hotel['_distance'] / 1000).toStringAsFixed(1)} km',
                                                        style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                // Prix (sans devise puisque la colonne n’existe pas)
                                                if ((hotel['prix'] ?? '')
                                                    .toString()
                                                    .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(top: 2.5),
                                                    child: Text(
                                                      'Prix : ${hotel['prix']}',
                                                      style: const TextStyle(
                                                        color: Color(0xFF113CFC),
                                                        fontWeight: FontWeight.w600,
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
                ),
    );
  }
}
