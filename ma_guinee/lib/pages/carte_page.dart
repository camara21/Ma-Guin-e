import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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
    final List<Marker> marqueurs = [];

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
                    final widget = _buildDetailPage(categorie, lieu);
                    if (widget != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => widget),
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

    if (_maPosition != null) {
      marqueurs.add(
        Marker(
          point: _maPosition!,
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, size: 40, color: Colors.blueAccent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Carte interactive"),
        backgroundColor: Colors.green[700],
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _categorieSelectionnee,
              dropdownColor: Colors.white,
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
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(9.5412, -13.6773), // Conakry par défaut
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
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _centrerSurMaPosition,
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildDetailPage(String category, Map<String, dynamic> lieu) {
    switch (category) {
      case 'hotels':
        return HotelDetailPage(hotel: lieu);
      case 'sante':
        return SanteDetailPage(centre: lieu);
      case 'restos':
        return RestoDetailPage(resto: lieu);
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
