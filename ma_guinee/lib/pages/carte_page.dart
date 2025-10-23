import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';
import 'hotel_detail_page.dart';
import 'sante_detail_page.dart';
import 'resto_detail_page.dart';
import 'tourisme_detail_page.dart';
import 'culte_detail_page.dart';
import 'divertissement_detail_page.dart';
import '../services/geoloc_service.dart'; // ✅ NEW: centraliser l’envoi localisation

class CartePage extends StatefulWidget {
  const CartePage({super.key});

  @override
  State<CartePage> createState() => _CartePageState();
}

class _CartePageState extends State<CartePage> {
  final MapController _mapController = MapController();
  String _categorieSelectionnee = 'tous';
  LatLng? _maPosition;
  bool _loading = true;

  // Données en mémoire
  final Map<String, List<Map<String, dynamic>>> _data = {
    'hotels': [],
    'restos': [],
    'sante': [],
    'tourisme': [],
    'culte': [],
    'divertissement': [],
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await _getMaPosition();

    // Requêtes séparées, une par catégorie/table
    await _chargerHotels(); // public.hotels
    await _chargerRestaurants(); // public.restaurants
    await _chargerCliniques(); // public.cliniques
    await _chargerTourisme(); // public.lieux (tourisme)
    await _chargerCulte(); // public.lieux (culte)
    await _chargerDivertissement(); // public.lieux (divertissement)

    if (!mounted) return;
    setState(() => _loading = false);

    // Log de contrôle
    debugPrint('[CARTE] hotels=${_data['hotels']?.length} '
        'restos=${_data['restos']?.length} '
        'sante=${_data['sante']?.length} '
        'tourisme=${_data['tourisme']?.length} '
        'culte=${_data['culte']?.length} '
        'divert=${_data['divertissement']?.length}');
  }

  // ---------------- Géolocalisation ----------------
  Future<void> _getMaPosition() async {
    try {
      final ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      // ✅ NEW: envoi de la position de l’utilisateur à Supabase (comme ailleurs)
      try { await GeolocService.reportPosition(pos); } catch (_) {}

      _maPosition = LatLng(pos.latitude, pos.longitude);
    } catch (_) {/* silencieux */}
  }

  // ------------------- Récupérations séparées -------------------

  final _sb = Supabase.instance.client;

  Future<void> _chargerHotels() async {
    try {
      final res = await _sb
          .from('hotels')
          .select('*')
          .order('nom', ascending: true)
          .range(0, 99999);
      setState(
          () => _data['hotels'] = List<Map<String, dynamic>>.from(res as List));
    } catch (e) {
      _toast('Erreur hôtels : $e');
    }
  }

  Future<void> _chargerRestaurants() async {
    try {
      final res = await _sb
          .from('restaurants')
          .select('*')
          .order('nom', ascending: true)
          .range(0, 99999);
      setState(
          () => _data['restos'] = List<Map<String, dynamic>>.from(res as List));
    } catch (e) {
      _toast('Erreur restaurants : $e');
    }
  }

  Future<void> _chargerCliniques() async {
    try {
      final res = await _sb
          .from('cliniques')
          .select('*')
          .order('nom', ascending: true)
          .range(0, 99999);
      setState(
          () => _data['sante'] = List<Map<String, dynamic>>.from(res as List));
    } catch (e) {
      _toast('Erreur cliniques : $e');
    }
  }

  // LIEUX : on fait une requête PAR catégorie avec des mots-clés tolérants
  static const _colsLieux = '''
    id, nom, latitude, longitude, images, ville, description, adresse, contact,
    type, categorie, photo_url, created_at
  ''';

  Future<void> _chargerTourisme() async {
    try {
      final res = await _sb
          .from('lieux')
          .select(_colsLieux)
          .or(
            // on accepte "tour", "tourisme", "touristique", "turisme"… sur type OU categorie
            'type.ilike.%tour%,type.ilike.%turism%,categorie.ilike.%tour%,categorie.ilike.%turism%',
          )
          .order('nom', ascending: true)
          .range(0, 99999);
      setState(() =>
          _data['tourisme'] = List<Map<String, dynamic>>.from(res as List));
    } catch (e) {
      // si table absente, on ignore
    }
  }

  Future<void> _chargerCulte() async {
    try {
      final res = await _sb
          .from('lieux')
          .select(_colsLieux)
          .or(
            // "culte", "mosquée", "église", "cathédrale", "temple", "sanctuaire"…
            'type.ilike.%culte%,type.ilike.%mosqu%,type.ilike.%egl%,type.ilike.%Ã©Â©Ã†â€™Â©gl%,type.ilike.%cath%,type.ilike.%temple%,type.ilike.%sanct%,'
            'categorie.ilike.%culte%,categorie.ilike.%mosqu%,categorie.ilike.%egl%,categorie.ilike.%Ã©Â©Ã†â€™Â©gl%,categorie.ilike.%cath%,categorie.ilike.%temple%,categorie.ilike.%sanct%',
          )
          .order('nom', ascending: true)
          .range(0, 99999);
    setState(
          () => _data['culte'] = List<Map<String, dynamic>>.from(res as List));
    } catch (e) {
      // ignore
    }
  }

  Future<void> _chargerDivertissement() async {
    try {
      final res = await _sb
          .from('lieux')
          .select(_colsLieux)
          .or(
            // "divertissement", "loisir", "bar", "club", "ciné", "théâtre", "lounge", "parc"…
            'type.ilike.%diver%,type.ilike.%loisir%,type.ilike.%bar%,type.ilike.%club%,type.ilike.%cine%,type.ilike.%cinÃ©Â©Ã†â€™Â©%,type.ilike.%theat%,type.ilike.%thÃ©Â©Ã†â€™Â©Ã©Â©Ã†â€™Â¢t%,type.ilike.%lounge%,type.ilike.%parc%,'
            'categorie.ilike.%diver%,categorie.ilike.%loisir%,categorie.ilike.%bar%,categorie.ilike.%club%,categorie.ilike.%cine%,categorie.ilike.%cinÃ©Â©Ã†â€™Â©%,categorie.ilike.%theat%,categorie.ilike.%thÃ©Â©Ã†â€™Â©Ã©Â©Ã†â€™Â¢t%,categorie.ilike.%lounge%,categorie.ilike.%parc%',
          )
          .order('nom', ascending: true)
          .range(0, 99999);
      setState(() => _data['divertissement'] =
          List<Map<String, dynamic>>.from(res as List));
    } catch (e) {
      // ignore
    }
  }

  // ---------------- Helpers ----------------
  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return double.tryParse(s.replaceAll(',', '.'));
    }
    return null;
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  String _firstImage(Map<String, dynamic> lieu, {required String categorie}) {
    // Différentes colonnes possibles selon les tables
    final keys = [
      'images',
      'photos',
      'photo_url',
      'image_url',
      'cover',
      'logo',
      'image'
    ];
    for (final k in keys) {
      final v = lieu[k];
      final imgs = _imagesFrom(v);
      if (imgs.isNotEmpty) return imgs.first;
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return 'https://via.placeholder.com/800x450.png?text=${categorie[0].toUpperCase()}${categorie.substring(1)}';
  }

  void _centrerSurMaPosition() {
    if (_maPosition != null) {
      _mapController.move(_maPosition!, 14);
    } else {
      _toast("Position actuelle non disponible");
    }
  }

  // -------- Popup aperçu (1ère image + nom) --------
  void _showPlacePreview(String categorie, Map<String, dynamic> lieu) {
    final image = _firstImage(lieu, categorie: categorie);
    final nom = (lieu['nom'] ?? 'Nom indisponible').toString();
    final ville = (lieu['ville'] ?? '').toString();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                nom,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (ville.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child:
                    Text(ville, style: TextStyle(color: Colors.grey.shade700)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final page = _buildDetailPage(categorie, lieu);
              if (page != null) {
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => page));
              }
            },
            child: const Text('Voir la fiche'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userPhotoUrl = userProvider.utilisateur?.photoUrl ?? '';
    final userNom = userProvider.utilisateur?.prenom ?? "Moi";

    // ---------------- Marqueurs ----------------
    final List<Marker> marqueurs = [];

    void addMarkers(String categorie, List<Map<String, dynamic>> lieux) {
      for (final lieu in lieux) {
        final lat = _toDouble(lieu['latitude']);
        final lon = _toDouble(lieu['longitude']);
        if (lat == null || lon == null) continue;

        marqueurs.add(
          Marker(
            point: LatLng(lat, lon),
            width: 42,
            height: 42,
            child: GestureDetector(
              onTap: () => _showPlacePreview(categorie, lieu),
              child: Icon(
                Icons.location_on,
                size: 38,
                color: _getColorByCategorie(categorie),
              ),
            ),
          ),
        );
      }
    }

    if (_categorieSelectionnee == 'tous') {
      addMarkers('hotels', _data['hotels'] ?? []);
      addMarkers('restos', _data['restos'] ?? []);
      addMarkers('sante', _data['sante'] ?? []);
      addMarkers('tourisme', _data['tourisme'] ?? []);
      addMarkers('culte', _data['culte'] ?? []);
      addMarkers('divertissement', _data['divertissement'] ?? []);
    } else {
      addMarkers(_categorieSelectionnee, _data[_categorieSelectionnee] ?? []);
    }

    // Marqueur utilisateur
    if (_maPosition != null) {
      marqueurs.add(
        Marker(
          point: _maPosition!,
          width: 80,
          height: 95,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent, width: 3),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2))
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  backgroundImage: userPhotoUrl.isNotEmpty
                      ? NetworkImage(userPhotoUrl)
                      : null,
                  child: userPhotoUrl.isEmpty
                      ? const Icon(Icons.person_pin_circle,
                          color: Colors.blueAccent, size: 35)
                      : null,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  userNom,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ---------------- UI ----------------
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Carte interactive",
          style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4),
        ),
        elevation: 1.2,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DropdownButtonHideUnderline(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButton<String>(
                  value: _categorieSelectionnee,
                  icon: const Icon(Icons.expand_more, color: Colors.black),
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: 'tous', child: Text("Tous")),
                    DropdownMenuItem(value: 'hotels', child: Text("Hôtels")),
                    DropdownMenuItem(
                        value: 'restos', child: Text("Restaurants")),
                    DropdownMenuItem(value: 'sante', child: Text("Santé")),
                    DropdownMenuItem(
                        value: 'tourisme', child: Text("Tourisme")),
                    DropdownMenuItem(
                        value: 'culte', child: Text("Lieux de culte")),
                    DropdownMenuItem(
                        value: 'divertissement', child: Text("Divertissement")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _categorieSelectionnee = val);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(9.5412, -13.6773), // Conakry
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.ma_guinee',
              ),
              MarkerLayer(markers: marqueurs),
            ],
          ),
          Positioned(
            bottom: 28,
            right: 18,
            child: FloatingActionButton(
              onPressed: _centrerSurMaPosition,
              backgroundColor: Colors.blueAccent,
              elevation: 5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.my_location),
              tooltip: "Ma position",
            ),
          ),
        ],
      ),
    );
  }

  // Ouvre la bonne page détail
  Widget? _buildDetailPage(String category, Map<String, dynamic> lieu) {
    switch (category) {
      case 'hotels':
        return HotelDetailPage(hotelId: lieu['id']);
      case 'restos':
        return RestoDetailPage(restoId: lieu['id']);
      case 'sante':
        return SanteDetailPage(cliniqueId: lieu['id']);
      case 'tourisme':
        return TourismeDetailPage(lieu: lieu);
      case 'culte':
        return CulteDetailPage(lieu: lieu);
      case 'divertissement':
        return DivertissementDetailPage(lieu: lieu);
      default:
        return null;
    }
  }

  // Couleurs par catégorie (alignées avec les pages)
Color _getColorByCategorie(String categorie) {
  switch (categorie) {
    case 'hotels':
      return const Color(0xFF264653); // Hôtels (teal sombre)
    case 'restos':
      return const Color(0xFFF4A261); // Restaurants (orange)
    case 'sante':
      return const Color(0xFF009460); // Santé (vert)
    case 'tourisme':
      return const Color(0xFFDAA520); // Tourisme (doré)
    case 'culte':
      return const Color(0xFF1E88E5); // Lieux de culte (bleu)
    case 'divertissement':
      return const Color(0xFF7E57C2); // Divertissement (violet)
    default:
      return Colors.grey;
  }
}

}
