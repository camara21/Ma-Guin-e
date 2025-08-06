import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tourisme_detail_page.dart';

class TourismePage extends StatefulWidget {
  const TourismePage({super.key});

  @override
  State<TourismePage> createState() => _TourismePageState();
}

class _TourismePageState extends State<TourismePage> {
  List<Map<String, dynamic>> _allLieux = [];
  List<Map<String, dynamic>> _filteredLieux = [];
  String searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLieux();
  }

  Future<void> _loadLieux() async {
    setState(() => _loading = true);
    final response = await Supabase.instance.client
        .from('lieux')
        .select()
        .eq('type', 'tourisme'); // ou .eq('categorie', 'tourisme') selon ta BDD
    setState(() {
      _allLieux = List<Map<String, dynamic>>.from(response);
      _filteredLieux = _allLieux;
      _loading = false;
    });
  }

  void _filterLieux(String query) {
    final q = query.toLowerCase();
    setState(() {
      searchQuery = query;
      _filteredLieux = _allLieux.where((lieu) {
        final nom = (lieu['nom'] ?? '').toLowerCase();
        final ville = (lieu['ville'] ?? '').toLowerCase();
        final desc = (lieu['description'] ?? '').toLowerCase();
        return nom.contains(q) || ville.contains(q) || desc.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF113CFC);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Sites touristiques",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Banner
                Container(
                  width: double.infinity,
                  height: 75,
                  margin: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [primaryColor, Color(0xFF2EC4F1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Découvrez les plus beaux sites touristiques de Guinée",
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
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un site, une ville...',
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
                      ? const Center(child: Text("Aucun site trouvé."))
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
                            final firstImage = images.isNotEmpty ? images[0] : (lieu['image'] ?? null);

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TourismeDetailPage(lieu: lieu),
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
                                                child: const Icon(Icons.landscape, size: 50),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey.shade300,
                                              child: const Icon(Icons.landscape, size: 50),
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lieu['nom'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            lieu['ville'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if ((lieu['description'] ?? '').toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                lieu['description'],
                                                style: const TextStyle(
                                                  color: primaryColor,
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
