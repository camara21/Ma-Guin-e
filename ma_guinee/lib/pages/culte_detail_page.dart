import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class CulteDetailPage extends StatelessWidget {
  final Map<String, dynamic> lieu;

  const CulteDetailPage({super.key, required this.lieu});

  void _ouvrirDansGoogleMaps(double lat, double lng) async {
    final Uri uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Impossible d’ouvrir Google Maps");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nom = lieu['nom'] ?? 'Lieu de culte';
    final String ville = lieu['ville'] ?? 'Ville inconnue';
    final List<String> images = (lieu['images'] as List?)?.cast<String>() ?? [];
    final double latitude = (lieu['latitude'] ?? 0).toDouble();
    final double longitude = (lieu['longitude'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        title: Text(
          nom,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF113CFC),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Si plusieurs images, on peut afficher un carousel basique avec PageView
            if (images.isNotEmpty)
              SizedBox(
                height: 190,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.network(
                        images[index],
                        width: double.infinity,
                        height: 190,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 190,
                          color: Colors.grey.shade300,
                          child: const Center(child: Icon(Icons.image_not_supported)),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  height: 190,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.place, size: 70, color: Colors.grey)),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              ville,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 18),
            const Text(
              "Localisation :",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 7, offset: Offset(0, 2)),
                ],
              ),
              height: 190,
              child: FlutterMap(
                options: MapOptions(
                  center: LatLng(latitude, longitude),
                  zoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: 'com.example.ma_guinee',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(latitude, longitude),
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.location_on, color: Color(0xFF009460), size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _ouvrirDansGoogleMaps(latitude, longitude),
                icon: const Icon(Icons.map),
                label: const Text("Ouvrir dans Google Maps"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF113CFC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
