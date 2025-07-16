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
  late GoogleMapController _mapController;
  MapType _mapType = MapType.normal;

  void _launchGoogleMaps() async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Impossible d’ouvrir la navigation.';
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
      appBar: AppBar(
        title: Text("Carte - ${widget.nom}"),
        backgroundColor: const Color(0xFF009460),
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
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _launchGoogleMaps,
              icon: const Icon(Icons.navigation),
              label: const Text("Itinéraire avec Google Maps"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCE1126),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
