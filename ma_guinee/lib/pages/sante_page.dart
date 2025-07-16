import 'package:flutter/material.dart';
import 'sante_detail_page.dart'; // ⚠️ Assure-toi d'importer ce fichier

class SantePage extends StatelessWidget {
  const SantePage({super.key});

  final List<Map<String, String>> centresSante = const [
    {
      'nom': 'Hôpital Donka',
      'ville': 'Conakry',
      'specialite': 'Médecine générale, urgences',
      'image': 'https://via.placeholder.com/150',
    },
    {
      'nom': 'Clinique Pasteur',
      'ville': 'Dixinn',
      'specialite': 'Consultations, imagerie médicale',
      'image': 'https://via.placeholder.com/150',
    },
    {
      'nom': 'Centre de santé Tafory',
      'ville': 'Kindia',
      'specialite': 'Soins primaires',
      'image': 'https://via.placeholder.com/150',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Services de santé"),
        backgroundColor: const Color(0xFF009460),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        itemCount: centresSante.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final centre = centresSante[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(centre['image']!),
                radius: 26,
              ),
              title: Text(
                centre['nom']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${centre['ville']} • ${centre['specialite']}'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SanteDetailPage(centre: centre),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
