import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RestoDetailPage extends StatelessWidget {
  final Map<String, dynamic> resto;

  const RestoDetailPage({super.key, required this.resto});

  void _appeler(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Impossible de lancer l'appel vers $numero");
    }
  }

  void _ouvrirMenu(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Impossible d'ouvrir l'URL : $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nom = resto['nom'] ?? 'Nom inconnu';
    final String ville = resto['ville'] ?? 'Ville inconnue';
    final String image = resto['image'] ?? '';
    final String cuisine = resto['cuisine'] ?? 'Non précisé';
    final String tel = resto['tel'] ?? '';
    final String menuUrl = resto['menu_url'] ?? '';
    final String horaires = resto['horaires'] ?? "Horaires non renseignés";

    return Scaffold(
      appBar: AppBar(
        title: Text(nom, style: const TextStyle(color: Colors.black)),
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

            // 📝 Nom & Type de cuisine
            Text(
              nom,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              cuisine,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // 📍 Ville
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(ville, style: const TextStyle(fontSize: 16)),
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

            // 📞 & 🍽️ Boutons d’action
            Row(
              children: [
                if (tel.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _appeler(tel),
                      icon: const Icon(Icons.phone, color: Colors.white),
                      label: const Text("Contacter"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCE1126),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (tel.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (menuUrl.isNotEmpty) {
                        _ouvrirMenu(menuUrl);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Menu indisponible pour l’instant")),
                        );
                      }
                    },
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text("Voir le menu"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🗺️ Bouton Localiser sur la carte
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, {
                  'latitude': resto['latitude'],
                  'longitude': resto['longitude'],
                });
              },
              icon: const Icon(Icons.map),
              label: const Text("Localiser sur la carte"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
