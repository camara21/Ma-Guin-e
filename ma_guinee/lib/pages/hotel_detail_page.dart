import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HotelDetailPage extends StatelessWidget {
  final Map<String, dynamic> hotel;

  const HotelDetailPage({super.key, required this.hotel});

  void _appelerHotel(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Impossible de lancer l’appel.');
    }
  }

  void _reserverHotel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Réservation'),
        content: const Text('La fonction de réservation sera bientôt disponible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String adresse = hotel['adresse'] ?? 'Adresse inconnue';
    final String numero = hotel['tel'] ?? '';
    final int etoiles = hotel['etoiles'] ?? 0;
    final String prix = hotel['prix'] ?? "Non renseigné";
    final String avis = hotel['avis'] ?? "Pas d'avis";
    final String image = hotel['image'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          hotel['nom'],
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

            // 🏨 Nom
            Text(
              hotel['nom'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // 📍 Adresse
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(child: Text(adresse, style: const TextStyle(fontSize: 16))),
              ],
            ),
            const SizedBox(height: 10),

            // ⭐ Étoiles
            Row(
              children: List.generate(
                etoiles,
                (i) => const Icon(Icons.star, color: Colors.amber, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            // 💰 Prix
            const Text("Prix moyen :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              prix,
              style: const TextStyle(fontSize: 16, color: Color(0xFF009460)),
            ),
            const SizedBox(height: 20),

            // 💬 Avis
            const Text("Avis client :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              avis,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 30),

            // 📍 Localiser sur carte
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, {
                  'latitude': hotel['latitude'],
                  'longitude': hotel['longitude'],
                });
              },
              icon: const Icon(Icons.map),
              label: const Text("Localiser sur la carte"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // 📞 & 📅 Actions
            Row(
              children: [
                if (numero.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.call),
                      label: const Text("Appeler"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009460),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _appelerHotel(numero),
                    ),
                  ),
                if (numero.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: const Text("Réserver"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCE1126),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _reserverHotel(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
