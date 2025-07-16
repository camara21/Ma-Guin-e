import 'package:flutter/material.dart';
import 'culte_detail_page.dart';

class CultePage extends StatelessWidget {
  const CultePage({super.key});

  final List<Map<String, dynamic>> lieux = const [
    {
      'nom': 'Mosquée Fayçal',
      'type': 'Mosquée',
      'ville': 'Conakry',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.mosque,
      'maps_url': 'https://www.google.com/maps?q=Mosquée+Faycal+Conakry',
    },
    {
      'nom': 'Église Saint Michel',
      'type': 'Église Catholique',
      'ville': 'Kaloum',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.church,
      'maps_url': 'https://www.google.com/maps?q=Eglise+Saint+Michel+Kaloum',
    },
    {
      'nom': 'Mosquée de Dixinn',
      'type': 'Mosquée',
      'ville': 'Dixinn',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.mosque,
      'maps_url': 'https://www.google.com/maps?q=Mosquée+Dixinn',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lieux de culte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un lieu de culte...',
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lieux.length,
              itemBuilder: (context, index) {
                final lieu = lieux[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
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
                    subtitle: Text('${lieu['type']} • ${lieu['ville']}'),
                    trailing: Icon(
                      lieu['icone'],
                      color: lieu['type'].toString().contains('Mosquée')
                          ? const Color(0xFF009460)
                          : const Color(0xFFCE1126),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CulteDetailPage(lieu: lieu),
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
