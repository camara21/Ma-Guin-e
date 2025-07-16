import 'package:flutter/material.dart';
import 'package:ma_guinee/models/annonce_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // ✅ pour le partage

class AnnonceDetailPage extends StatelessWidget {
  final AnnonceModel annonce;

  const AnnonceDetailPage({super.key, required this.annonce});

  /// 📞 Appeler
  void _call(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// 💬 WhatsApp
  void _whatsapp(String numero) async {
    final cleanNumber = numero.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 📤 Partager
  void _shareAnnonce() {
    final message = '''
📢 ${annonce.titre}

${annonce.description}

📍 Ville : ${annonce.ville}
📂 Catégorie : ${annonce.categorie}
📞 Téléphone : ${annonce.telephone}

Partagé depuis l'app Ma Guinée 🇬🇳
''';

    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final hasTel = annonce.telephone.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(annonce.titre),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📷 Image principale
            if (annonce.images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  annonce.images.first,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_not_supported, size: 60),
              ),

            const SizedBox(height: 20),

            // 🏷️ Titre
            Text(
              annonce.titre,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // 📝 Description
            Text(
              annonce.description,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            // 💰 Prix
            if (annonce.prix > 0)
              Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("Prix : ${annonce.prix.toStringAsFixed(0)} GNF"),
                ],
              ),

            const SizedBox(height: 8),

            // 🧾 Catégorie
            Row(
              children: [
                const Icon(Icons.category, color: Colors.grey),
                const SizedBox(width: 8),
                Text("Catégorie : ${annonce.categorie}"),
              ],
            ),

            const SizedBox(height: 8),

            // 📍 Ville
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey),
                const SizedBox(width: 8),
                Text("Ville : ${annonce.ville}"),
              ],
            ),

            const SizedBox(height: 30),

            // 📞 Boutons de contact
            if (hasTel)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _call(annonce.telephone),
                    icon: const Icon(Icons.phone),
                    label: const Text("Appeler"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009460),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _whatsapp(annonce.telephone),
                    icon: const Icon(Icons.message),
                    label: const Text("WhatsApp"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              )
            else
              const Center(
                child: Text(
                  "Aucun numéro de téléphone fourni.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            const SizedBox(height: 16),

            // 📤 Bouton Partager
            Center(
              child: ElevatedButton.icon(
                onPressed: _shareAnnonce,
                icon: const Icon(Icons.share),
                label: const Text("Partager l’annonce"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333333),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
