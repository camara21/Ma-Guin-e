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
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredLieux = _allLieux;
  }

  void _filterLieux(String query) {
    final q = query.toLowerCase();
    setState(() {
      searchQuery = query;
      _filteredLieux = _allLieux.where((lieu) {
        final nom = (lieu['nom'] ?? '').toLowerCase();
        final ville = (lieu['ville'] ?? '').toLowerCase();
        final ambiance = (lieu['ambiance'] ?? '').toLowerCase();
        return nom.contains(q) || ville.contains(q) || ambiance.contains(q);
      }).toList();
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
          // Banner
          Container(
            width: double.infinity,
            height: 75,
            margin: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF00C9FF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Bars, clubs, lounges et sorties à Conakry",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
          // Recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un lieu, une ambiance, une ville...',
                prefixIcon: const Icon(Icons.search, color: primaryColor),
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
          const SizedBox(height: 10),
          // Grille de cartes
          Expanded(
            child: _filteredLieux.isEmpty
                ? const Center(child: Text("Aucun lieu trouvé."))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.77,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 11,
                                child: firstImage != null
                                    ? Image.network(
                                        firstImage,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.broken_image, size: 50),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image, size: 50),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lieu['nom'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      lieu['ville'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if ((lieu['ambiance'] ?? '').toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          lieu['ambiance'],
                                          style: const TextStyle(
                                            color: Colors.deepPurple,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
