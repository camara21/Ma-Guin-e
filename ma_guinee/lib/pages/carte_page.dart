import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart'; // Adapte ce chemin si besoin
import '../data/lieux_data.dart';
import 'hotel_detail_page.dart';
import 'sante_detail_page.dart';
import 'resto_detail_page.dart';
import 'tourisme_detail_page.dart';
import 'culte_detail_page.dart';
import 'divertissement_detail_page.dart';

class CartePage extends StatefulWidget {
  const CartePage({super.key});

  @override
  State<CartePage> createState() => _CartePageState();
}

class _CartePageState extends State<CartePage> {
  final MapController _mapController = MapController();
  String _categorieSelectionnee = 'tous';
  LatLng? _maPosition;

  @override
  void initState() {
    super.initState();
    _getMaPosition();
  }

  Future<void> _getMaPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _maPosition = LatLng(position.latitude, position.longitude);
    });
  }

  void _centrerSurMaPosition() {
    if (_maPosition != null) {
      _mapController.move(_maPosition!, 14);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Position actuelle non disponible")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userPhotoUrl = userProvider.utilisateur?.photoUrl ?? '';
    final userNom = userProvider.utilisateur?.prenom ?? "Moi";

    final List<Marker> marqueurs = [];

    // Marqueurs des lieux par catégorie
    lieuxData.forEach((categorie, lieux) {
      if (_categorieSelectionnee == 'tous' || _categorieSelectionnee == categorie) {
        for (var lieu in lieux) {
          final latitude = lieu['latitude'];
          final longitude = lieu['longitude'];
          if (latitude != null && longitude != null) {
            marqueurs.add(
              Marker(
                point: LatLng(latitude, longitude),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    final page = _buildDetailPage(categorie, lieu);
                    if (page != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => page),
                      );
                    }
                  },
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
      }
    });

    // Marqueur utilisateur : photo + badge prénom, sans overflow
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  backgroundImage: (userPhotoUrl.isNotEmpty)
                      ? NetworkImage(userPhotoUrl)
                      : null,
                  child: (userPhotoUrl.isEmpty)
                      ? const Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 35)
                      : null,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  userNom,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Carte interactive",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        elevation: 1.2,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
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
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: 'tous', child: Text("Tous")),
                    DropdownMenuItem(value: 'hotels', child: Text("Hôtels")),
                    DropdownMenuItem(value: 'sante', child: Text("Santé")),
                    DropdownMenuItem(value: 'restos', child: Text("Restaurants")),
                    DropdownMenuItem(value: 'tourisme', child: Text("Tourisme")),
                    DropdownMenuItem(value: 'culte', child: Text("Lieux de culte")),
                    DropdownMenuItem(value: 'divertissement', child: Text("Divertissement")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _categorieSelectionnee = val;
                      });
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
            options: MapOptions(
              initialCenter: const LatLng(9.5412, -13.6773), // Conakry
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.my_location),
              tooltip: "Ma position",
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildDetailPage(String category, Map<String, dynamic> lieu) {
    switch (category) {
      case 'hotels':
        return HotelDetailPage(hotelId: lieu['id']);
      case 'sante':
        return SanteDetailPage(cliniqueId: lieu['id']);
      case 'restos':
        return RestoDetailPage(restoId: lieu['id']);
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

  Color _getColorByCategorie(String categorie) {
    switch (categorie) {
      case 'hotels':
        return Colors.purple;
      case 'sante':
        return Colors.teal;
      case 'restos':
        return Colors.orange;
      case 'tourisme':
        return Colors.blue;
      case 'culte':
        return Colors.green;
      case 'divertissement':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
