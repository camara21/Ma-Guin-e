import 'package:flutter/material.dart';
import 'divertissement_detail_page.dart';

class DivertissementPage extends StatefulWidget {
  const DivertissementPage({super.key});

  @override
  State<DivertissementPage> createState() => _DivertissementPageState();
}

class _DivertissementPageState extends State<DivertissementPage> {
  final List<Map<String, dynamic>> _allLieux = [
    {
      'nom': 'Palm Camayenne Club',
      'ambiance': 'Afrobeat, DJ Live',
      'ville': 'Kaloum',
      'images': ['https://via.placeholder.com/600x400', 'https://via.placeholder.com/600x401'],
      'icone': Icons.music_note,
      'telephone': '+224620000000',
    },
    {
      'nom': 'VIP Room Conakry',
      'ambiance': 'Ambiance chic & urbaine',
      'ville': 'Taouyah',
      'images': ['https://via.placeholder.com/600x402'],
      'icone': Icons.nightlife,
      'telephone': '+224622111111',
    },
    {
      'nom': 'Platinum Lounge',
      'ambiance': 'Electro & Afro vibes',
      'ville': 'Nongo',
      'images': ['https://via.placeholder.com/600x403'],
      'icone': Icons.theater_comedy,
      'telephone': '+224623222222',
    },
  ];

  List<Map<String, dynamic>> _filteredLieux = [];

  @override
  void initState() {
    super.initState();
    _filteredLieux = _allLieux;
  }

  void _filterLieux(String query) {
    final filtered = _allLieux.where((lieu) {
      final nomLower = lieu['nom'].toString().toLowerCase();
      final villeLower = lieu['ville'].toString().toLowerCase();
      final q = query.toLowerCase();
      return nomLower.contains(q) || villeLower.contains(q);
    }).toList();

    setState(() {
      _filteredLieux = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.deepPurple;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Divertissement',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1.2,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un lieu festif...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filterLieux,
            ),
          ),
          Expanded(
            child: _filteredLieux.isEmpty
                ? const Center(child: Text("Aucun lieu trouvé."))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredLieux.length,
                    itemBuilder: (context, index) {
                      final lieu = _filteredLieux[index];
                      final images = (lieu['images'] as List?)?.cast<String>() ?? [];
                      final firstImage = images.isNotEmpty ? images[0] : null;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DivertissementDetailPage(lieu: lieu),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 3,
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: firstImage != null
                                    ? Image.network(
                                        firstImage,
                                        height: 170,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 170,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.broken_image, size: 50),
                                        ),
                                      )
                                    : Container(
                                        height: 170,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image, size: 50),
                                      ),
                              ),
                              ListTile(
                                leading: Icon(lieu['icone'], color: primaryColor),
                                title: Text(
                                  lieu['nom'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                ),
                                subtitle: Text(
                                  '${lieu['ambiance']} • ${lieu['ville']}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                trailing: Icon(Icons.arrow_forward_ios, size: 18, color: primaryColor),
                              ),
                            ],
                          ),
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
