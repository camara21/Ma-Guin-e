import 'package:flutter/material.dart';
import 'hotel_detail_page.dart'; // ✅ à créer ou importer dans ton projet

class HotelPage extends StatelessWidget {
  const HotelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> hotels = [
      {
        'nom': 'Hotel Palm Camayenne',
        'adresse': 'Corniche Nord, Conakry',
        'etoiles': 5,
        'image': 'https://via.placeholder.com/300x180?text=Camayenne',
      },
      {
        'nom': 'Noom Hotel Conakry',
        'adresse': 'Avenue de la République, Conakry',
        'etoiles': 4,
        'image': 'https://via.placeholder.com/300x180?text=Noom',
      },
      {
        'nom': 'Hotel Onomo',
        'adresse': 'Quartier Kipé, Conakry',
        'etoiles': 3,
        'image': 'https://via.placeholder.com/300x180?text=Onomo',
      },
      {
        'nom': 'Grand Hotel de l\'Indépendance',
        'adresse': 'Centre-ville, Conakry',
        'etoiles': 4,
        'image': 'https://via.placeholder.com/300x180?text=Independance',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hôtels en Guinée 🇬🇳"),
        backgroundColor: const Color(0xFFCE1126),
      ),
      body: ListView.builder(
        itemCount: hotels.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final hotel = hotels[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.hotel, color: Color(0xFF009460)),
              title: Text(
                hotel['nom'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotel['adresse']),
                  Row(
                    children: List.generate(
                      hotel['etoiles'],
                      (i) => const Icon(Icons.star, size: 16, color: Colors.amber),
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HotelDetailPage(hotel: hotel),
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
