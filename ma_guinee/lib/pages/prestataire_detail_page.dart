import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrestataireDetailPage extends StatelessWidget {
  final Map<String, dynamic> prestataire;

  const PrestataireDetailPage({super.key, required this.prestataire});

  void _call(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _whatsapp(String numero) async {
    final clean = numero.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nom = prestataire['nom'];
    final specialite = prestataire['specialite'];
    final ville = prestataire['ville'];
    final image = prestataire['image'];
    final numero = prestataire['telephone'] ?? '620000000';
    final icone = prestataire['icone'];

    return Scaffold(
      appBar: AppBar(
        title: Text(nom),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 👤 Photo du prestataire
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(image),
            ),
            const SizedBox(height: 16),

            // 🧰 Spécialité et ville
            Text(
              specialite,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              ville,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // 📞 Boutons d’action
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _call(numero),
                  icon: const Icon(Icons.call),
                  label: const Text("Appeler"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _whatsapp(numero),
                  icon: const Icon(Icons.chat),
                  label: const Text("WhatsApp"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 📝 Résumé (à personnaliser si besoin)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Présentation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Professionnel expérimenté dans le domaine de la $specialite basé à $ville. Disponible pour vos besoins quotidiens.',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
