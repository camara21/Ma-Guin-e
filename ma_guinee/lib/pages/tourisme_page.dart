import 'package:flutter/material.dart';
import 'tourisme_detail_page.dart';

class TourismePage extends StatelessWidget {
  const TourismePage({super.key});

  final List<Map<String, dynamic>> lieuxTouristiques = const [
    {
      'nom': 'Chutes de la Sala',
      'ville': 'Kindia',
      'description': 'Cascade naturelle entourée de verdure',
      'image': 'https://via.placeholder.com/150',
      'images': [
        'https://via.placeholder.com/300x200?text=Sala+1',
        'https://via.placeholder.com/300x200?text=Sala+2',
        'https://via.placeholder.com/300x200?text=Sala+3',
      ],
      'maps_url': 'https://www.google.com/maps?q=chutes+de+la+sala,+kindia',
    },
    {
      'nom': 'Îles de Loos',
      'ville': 'Conakry',
      'description': 'Plages paradisiaques à quelques minutes de la capitale',
      'image': 'https://via.placeholder.com/150',
      'images': [
        'https://via.placeholder.com/300x200?text=Loos+1',
        'https://via.placeholder.com/300x200?text=Loos+2',
      ],
      'maps_url': 'https://www.google.com/maps?q=iles+de+loos+conakry',
    },
    {
      'nom': 'Mont Nimba',
      'ville': 'Nzérékoré',
      'description': 'Réserve naturelle classée au patrimoine mondial',
      'image': 'https://via.placeholder.com/150',
      'images': [
        'https://via.placeholder.com/300x200?text=Nimba+1',
        'https://via.placeholder.com/300x200?text=Nimba+2',
        'https://via.placeholder.com/300x200?text=Nimba+3',
      ],
      'maps_url': 'https://www.google.com/maps?q=mont+nimba+nzerekore',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Sites touristiques",
          style: TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
      ),
      body: ListView.builder(
        itemCount: lieuxTouristiques.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final lieu = lieuxTouristiques[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            color: Colors.blue.shade50.withOpacity(0.12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(lieu['image']),
                radius: 26,
              ),
              title: Text(
                lieu['nom'],
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              subtitle: Text(
                '${lieu['ville']} • ${lieu['description']}',
                style: const TextStyle(color: Colors.black87),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF113CFC)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TourismeDetailPage(lieu: lieu),
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
