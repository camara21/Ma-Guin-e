import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  final List<Map<String, dynamic>> services = const [
    {
      'titre': 'Carte Nationale d\'Identité',
      'description': 'Pièces requises et lieux pour faire la demande.',
      'icone': Icons.badge,
    },
    {
      'titre': 'Passeport Biométrique',
      'description': 'Documents nécessaires et délai d’obtention.',
      'icone': Icons.travel_explore,
    },
    {
      'titre': 'Acte de Naissance',
      'description': 'Où et comment l’obtenir rapidement.',
      'icone': Icons.cake,
    },
    {
      'titre': 'Casier Judiciaire',
      'description': 'Démarches pour en faire la demande.',
      'icone': Icons.gavel,
    },
    {
      'titre': 'Permis de Conduire',
      'description': 'Inscriptions et conditions d’obtention.',
      'icone': Icons.directions_car,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services administratifs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 🔍 Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un service...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 📋 Liste des services
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFCE1126),
                      child: Icon(service['icone'], color: Colors.white),
                    ),
                    title: Text(
                      service['titre'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(service['description']),
                    onTap: () {
                      // Tu pourras ouvrir une page avec les détails ou fichiers
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
