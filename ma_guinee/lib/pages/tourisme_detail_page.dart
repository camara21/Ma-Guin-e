import 'package:flutter/material.dart';

class TourismeDetailPage extends StatelessWidget {
  final Map<String, dynamic> lieu;

  const TourismeDetailPage({super.key, required this.lieu});

  @override
  Widget build(BuildContext context) {
    final List<String> images = lieu['images'] != null
        ? List<String>.from(lieu['images'])
        : [lieu['image'] ?? ''];
    final String nom = lieu['nom'] ?? '';
    final String ville = lieu['ville'] ?? '';
    final String description = lieu['description'] ?? '';
    final String horaires = lieu['horaires'] ?? "Lundi - Dimanche : 08h00 - 18h00";

    return Scaffold(
      appBar: AppBar(
        title: Text(nom),
        backgroundColor: const Color(0xFFCE1126),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Ajouté aux favoris !")),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📸 Carrousel d’images
            SizedBox(
              height: 200,
              child: PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      images[index],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade300,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 🏞 Nom & Ville
            Text(
              nom,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              ville,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // 📝 Description
            Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // ⏰ Horaires
            const Text(
              "🕒 Horaires d’ouverture",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(horaires, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 24),

            // 📍 Localiser sur la carte (Flutter)
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
                  backgroundColor: const Color(0xFF009460),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ⭐ Avis
            const Text(
              "⭐ Avis des visiteurs",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text("“Magnifique site, à visiter absolument !” - Aissatou"),
            const Text("“J’ai adoré la vue et l’ambiance.” - Mamadou"),
            const Text("“Un peu difficile d’accès mais ça vaut le détour.” - Ibrahima"),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
