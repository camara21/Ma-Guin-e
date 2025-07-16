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
      appBar: AppBar(
        title: const Text("Sites touristiques"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        itemCount: lieuxTouristiques.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final lieu = lieuxTouristiques[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(lieu['image']),
                radius: 26,
              ),
              title: Text(
                lieu['nom'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${lieu['ville']} • ${lieu['description']}'),
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
