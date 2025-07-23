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
      backgroundColor: Colors.white, // Fond blanc premium
      appBar: AppBar(
        title: const Text(
          'Services administratifs',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1.2,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un service...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF113CFC)),
                filled: true,
                fillColor: const Color(0xFFF8F6F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                return Card(
                  color: Colors.indigo.shade50.withOpacity(0.13),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFCE1126),
                      child: Icon(service['icone'], color: Colors.white),
                    ),
                    title: Text(
                      service['titre'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      service['description'],
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFFCE1126)),
                    onTap: () {
                      // Futur : ouvrir la page de détail ou téléchargement PDF
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
