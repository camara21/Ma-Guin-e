import 'package:flutter/material.dart';

class DivertissementDetailPage extends StatelessWidget {
  final Map<String, dynamic> lieu;

  const DivertissementDetailPage({super.key, required this.lieu});

  @override
  Widget build(BuildContext context) {
    final horaires = lieu['horaires'] ?? "Non renseigné";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lieu['nom'],
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
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
                lieu['image'] ?? '',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📝 Nom
            Text(
              lieu['nom'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // 🎉 Ambiance
            if (lieu['ambiance'] != null)
              Text(
                lieu['ambiance'],
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),

            const SizedBox(height: 20),

            // 📍 Ville
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  lieu['ville'] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ⏰ Horaires
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    horaires,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 🗺️ Localiser sur la carte
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, {
                    'latitude': lieu['latitude'],
                    'longitude': lieu['longitude'],
                  });
                },
                icon: const Icon(Icons.map),
                label: const Text("Localiser sur la carte"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),

      // ✅ Action : Réserver
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Fonction à venir")),
          );
        },
        icon: const Icon(Icons.event),
        label: const Text("Réserver"),
        backgroundColor: const Color(0xFFCE1126),
      ),
    );
  }
}
