import 'package:flutter/material.dart';
import 'divertissement_detail_page.dart';

class DivertissementPage extends StatelessWidget {
  const DivertissementPage({super.key});

  static const List<Map<String, dynamic>> lieux = [
    {
      'nom': 'Palm Camayenne Club',
      'ambiance': 'Afrobeat, DJ Live',
      'ville': 'Kaloum',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.music_note,
    },
    {
      'nom': 'VIP Room Conakry',
      'ambiance': 'Ambiance chic & urbaine',
      'ville': 'Taouyah',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.nightlife,
    },
    {
      'nom': 'Platinum Lounge',
      'ambiance': 'Electro & Afro vibes',
      'ville': 'Nongo',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.theater_comedy,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Divertissement',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
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
                hintText: 'Rechercher un lieu festif...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 📋 Liste des lieux
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: lieux.length,
              itemBuilder: (context, index) {
                final lieu = lieux[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        lieu['image'],
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      lieu['nom'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${lieu['ambiance']} • ${lieu['ville']}'),
                    trailing: Icon(
                      lieu['icone'],
                      color: const Color(0xFFFCD116),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DivertissementDetailPage(lieu: lieu),
                        ),
                      );
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
