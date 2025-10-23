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
  static const Color hotelsPrimary   = Color(0xFF264653);
  static const Color hotelsSecondary = Color(0xFF2A9D8F);
  static const Color onPrimary       = Color(0xFFFFFFFF);

  // Neutres
  static const Color neutralBg      = Color(0xFFF7F7F9);
  static const Color neutralSurface = Color(0xFFFFFFFF);
  static const Color neutralBorder  = Color(0xFFE5E7EB);

  // Cache SWR
  static const String _CACHE_KEY = 'hotels_v1';
  static const Duration _CACHE_MAX_AGE = Duration(hours: 12);

  // Données
  List<Map<String, dynamic>> hotels = [];
  List<Map<String, dynamic>> filteredHotels = [];
  bool loading = true;

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
    _loadAll(); // SWR par défaut
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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _position = pos;

      // ville (pour le tri local)
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
      } catch (_) {
        // pas bloquant pour l’UI
      }

      // ⭐ NEW: centralise l’envoi dans la table `utilisateurs` (RPC + dédoublonnage)
      try {
        await GeolocService.reportPosition(pos);
      } catch (_) {
        // silencieux si échec réseau/RLS
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
  // ----------------------------------------------

  // ========= TRI + enrichissement (distance) commun cache / réseau =========
  Future<List<Map<String, dynamic>>> _enrichAndSort(List<Map<String, dynamic>> list) async {
    await _getLocation();

    if (_position != null) {
      for (final h in list) {
        final lat = (h['latitude'] as num?)?.toDouble();
        final lon = (h['longitude'] as num?)?.toDouble();
        h['_distance'] = _distanceMeters(_position!.latitude, _position!.longitude, lat, lon);
      }

      if (_villeGPS != null && _villeGPS!.isNotEmpty) {
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
    } else {
      list.sort((a, b) => (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString()));
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
      final n  = (r['etoiles'] as num?)?.toDouble() ?? 0.0;
      sums[id]   = (sums[id] ?? 0.0) + n;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    for (final id in counts.keys) {
      _avgByHotelId[id] = (sums[id]! / counts[id]!.clamp(1, 1 << 30));
      _countByHotelId[id] = counts[id]!;
    }
  }
  // --------------------------------------------------------

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
  // CHARGEMENT SWR PRINCIPAL
  // =======================
  Future<void> _loadAll({bool forceNetwork = false}) async {
    if (!forceNetwork) {
      // 1) Instantané: mémoire ou disque si non expiré
      final mem = AppCache.I.getListMemory(_CACHE_KEY, maxAge: _CACHE_MAX_AGE);
      List<Map<String, dynamic>>? disk;
      if (mem == null) {
        disk = await AppCache.I.getListPersistent(_CACHE_KEY, maxAge: _CACHE_MAX_AGE);
      }
      final snapshot = mem ?? disk;

      if (snapshot != null) {
        // Affiche tout de suite le cache
        final snapClone = snapshot.map((e) => Map<String, dynamic>.from(e)).toList();
        final enriched = await _enrichAndSort(snapClone);
        hotels = enriched;
        await _preloadAverages(enriched.map((e) => e['id'].toString()).toList());
        _filterHotels(searchQuery);
        if (mounted) setState(() => loading = false);
      } else {
        if (mounted) setState(() => loading = true);
      }
    } else {
      if (mounted) setState(() => loading = true);
    }

    // 2) Réseau: rafraîchit en arrière-plan et met à jour l'UI + le cache
    try {
      final data = await Supabase.instance.client.from('hotels').select('''
            id, nom, ville, adresse, prix,
            latitude, longitude, images, description, created_at
          ''');

      final list = List<Map<String, dynamic>>.from(data);

      final enriched = await _enrichAndSort(list);

      // Notes moyennes
      await _preloadAverages(enriched.map((e) => e['id'].toString()).toList());

      // Met à jour l'écran
      hotels = enriched;
      _filterHotels(searchQuery);

      // Persist cache (retire le champ volatil _distance)
      final toCache = enriched.map((h) {
        final clone = Map<String, dynamic>.from(h);
        clone.remove('_distance');
        return clone;
      }).toList(growable: false).cast<Map<String, dynamic>>();

      // On n'attend pas: AppCache.setList est async void
      AppCache.I.setList(_CACHE_KEY, toCache, persist: true);

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted && hotels.isEmpty) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement hôtels : $e')),
        );
      } else {
        debugPrint('Erreur rafraîchissement hôtels : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutralBg,
      appBar: AppBar(
        backgroundColor: neutralSurface,
        elevation: 1,
        foregroundColor: hotelsPrimary,
        title: const Text(
          'Hôtels',
          style: TextStyle(
            color: hotelsPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: hotelsPrimary),
            tooltip: 'Rafraîchir',
            onPressed: () => _loadAll(forceNetwork: true),
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
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(hotelsPrimary),
              ),
            )
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
                            colors: [hotelsPrimary, hotelsSecondary],
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
                          prefixIcon: const Icon(Icons.search, color: hotelsPrimary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: neutralBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: neutralBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: hotelsSecondary, width: 1.5),
                          ),
                          filled: true,
                          fillColor: neutralSurface,
                        ),
                        onChanged: _filterHotels,
                      ),
                      const SizedBox(height: 12),
                      // Grille d'hôtels
                      Expanded(
                        child: filteredHotels.isEmpty
                            ? const Center(child: Text("Aucun hôtel trouvé."))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.80,
                                ),
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

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => HotelDetailPage(hotelId: hotel['id']),
                                        ),
                                      );
                                    },
                                    child: Card(
                                      elevation: 2,
                                      color: neutralSurface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: const BorderSide(color: neutralBorder),
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
                                                      child: Icon(
                                                        Icons.hotel,
                                                        size: 40,
                                                        color: Colors.grey[500],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if ((hotel['ville'] ?? '').toString().isNotEmpty)
                                                  Positioned(
                                                    left: 8,
                                                    top: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: hotelsPrimary.withOpacity(.85),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.location_on, size: 14, color: onPrimary),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            (hotel['ville'] ?? '').toString(),
                                                            style: const TextStyle(color: onPrimary, fontSize: 12),
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
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (hotel['nom'] ?? "Sans nom").toString(),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                // ⭐️ Note moyenne (même logique que détail)
                                                Row(
                                                  children: [
                                                    _starsFor(avg),
                                                    if (count > 0)
                                                      Text('  ($count)',
                                                          style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // Ville + distance
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        (hotel['ville'] ?? '').toString(),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    if (hotel.containsKey('_distance') &&
                                                        hotel['_distance'] != null) ...[
                                                      const Text('  •  ',
                                                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                                                      Text(
                                                        '${(hotel['_distance'] / 1000).toStringAsFixed(1)} km',
                                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                // Prix — toujours "GNF / nuit"
                                                if ((hotel['prix'] ?? '').toString().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 3),
                                                    child: Text(
                                                      'Prix : ${_formatGNF(hotel['prix'])} GNF / nuit',
                                                      style: const TextStyle(
                                                        color: hotelsPrimary,
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
