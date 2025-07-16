import 'package:flutter/material.dart';

class SanteDetailPage extends StatelessWidget {
  final Map<String, dynamic> centre;

  const SanteDetailPage({super.key, required this.centre});

  @override
  Widget build(BuildContext context) {
    final String nom = centre['nom'] ?? 'Centre médical';
    final String ville = centre['ville'] ?? 'Ville inconnue';
    final String specialite = centre['specialite'] ?? 'Spécialité non renseignée';
    final String image = centre['image'] ?? '';
    final String horaires = centre['horaires'] ??
        "Lundi - Vendredi : 8h à 18h\nSamedi : 8h à 13h\nDimanche : Fermé";

    return Scaffold(
      appBar: AppBar(
        title: Text(nom, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF009460),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📸 Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                image,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Center(child: Icon(Icons.image_not_supported)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🏥 Nom
            Text(
              nom,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // 📍 Ville
            Row(
              children: [
                const Icon(Icons.location_city, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(ville, style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),

            // 🩺 Spécialité
            const Text(
              "Spécialités :",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              specialite,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            // ⏰ Horaires
            const Text(
              "Horaires d’ouverture :",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(horaires, style: const TextStyle(fontSize: 16)),

            const SizedBox(height: 30),

            // 🗺️ Localisation sur la carte intégrée
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, {
                  'latitude': centre['latitude'],
                  'longitude': centre['longitude'],
                });
              },
              icon: const Icon(Icons.map),
              label: const Text("Localiser sur la carte"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009460),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
