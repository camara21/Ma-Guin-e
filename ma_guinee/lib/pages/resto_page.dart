import 'package:flutter/material.dart';
import 'resto_detail_page.dart'; // ✅ Import de la page détail

class RestoPage extends StatelessWidget {
  const RestoPage({super.key});

  final List<Map<String, dynamic>> restos = const [
    {
      'nom': 'Le Diplomat',
      'cuisine': 'Cuisine africaine', // 🟡 renommé en "cuisine" pour cohérence
      'ville': 'Kaloum',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.restaurant_menu,
    },
    {
      'nom': 'Chez Fatou',
      'cuisine': 'Cuisine guinéenne',
      'ville': 'Ratoma',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.rice_bowl,
    },
    {
      'nom': 'Pizza Palace',
      'cuisine': 'Pizza & fast-food',
      'ville': 'Lambanyi',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.local_pizza,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants'),
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
                hintText: 'Rechercher un restaurant...',
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

          // 📋 Liste des restos
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: restos.length,
              itemBuilder: (context, index) {
                final resto = restos[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(resto['image']),
                      radius: 26,
                    ),
                    title: Text(
                      resto['nom'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${resto['cuisine']} • ${resto['ville']}'),
                    trailing: Icon(resto['icone'], color: const Color(0xFF009460)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestoDetailPage(resto: resto),
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
