import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LieuMapPage extends StatefulWidget {
  final String nom;
  final double latitude;
  final double longitude;

  const LieuMapPage({
    super.key,
    required this.nom,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<LieuMapPage> createState() => _LieuMapPageState();
}

class _LieuMapPageState extends State<LieuMapPage> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;

  void _launchGoogleMaps() async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d’ouvrir la navigation.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final marker = Marker(
      markerId: const MarkerId("lieu"),
      position: LatLng(widget.latitude, widget.longitude),
      infoWindow: InfoWindow(title: widget.nom),
    );

    return Scaffold(
      backgroundColor: Colors.white, // ✅ Fond blanc comme toutes les pages
      appBar: AppBar(
        title: Text(
          "Carte - ${widget.nom}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF009460),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            tooltip: "Changer la vue",
            onPressed: () {
              setState(() {
                _mapType = _mapType == MapType.normal
                    ? MapType.satellite
                    : MapType.normal;
              });
            },
          ),
        ],
        elevation: 1,
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: _mapType,
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.latitude, widget.longitude),
              zoom: 14,
            ),
            markers: {marker},
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            zoomControlsEnabled: true,
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _launchGoogleMaps,
                icon: const Icon(Icons.navigation, color: Colors.white),
                label: const Text(
                  "Itinéraire avec Google Maps",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCE1126),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
