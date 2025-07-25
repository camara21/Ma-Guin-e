import 'package:flutter/material.dart';

class DetailPrestationPage extends StatelessWidget {
  final Map<String, dynamic> prestation;

  const DetailPrestationPage({super.key, required this.prestation});

  @override
  Widget build(BuildContext context) {
    final String nom = prestation['nom'] ?? 'Nom inconnu';
    final String metier = prestation['metier'] ?? 'Métier non spécifié';
    final String description = prestation['description'] ?? 'Aucune description';
    final String ville = prestation['ville'] ?? 'Ville non renseignée';
    final String telephone = prestation['telephone'] ?? 'Non renseigné';
    final String? photoUrl = prestation['photo_url'];

    return Scaffold(
      appBar: AppBar(title: Text(metier)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            photoUrl != null
                ? Image.network(
                    photoUrl,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.person, size: 100, color: Colors.white70),
                  ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined),
                      const SizedBox(width: 5),
                      Text(ville),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description),
                  const SizedBox(height: 20),
                  const Text('Téléphone', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(telephone),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.call),
                      label: const Text('Contacter'),
                      onPressed: () {
                        // Tu peux implémenter la logique pour appeler ou envoyer un message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Fonction à implémenter")),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
