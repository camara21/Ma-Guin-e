import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_guinee/models/annonce_model.dart';
import '../providers/favoris_provider.dart';
import 'annonce_detail_page.dart';

class FavorisPage extends StatefulWidget {
  const FavorisPage({super.key});

  @override
  State<FavorisPage> createState() => _FavorisPageState();
}

class _FavorisPageState extends State<FavorisPage> {
  bool affichageGrille = true;

  @override
  void initState() {
    super.initState();
    Provider.of<FavorisProvider>(context, listen: false).loadFavoris();
  }

  // SQL 'IN' propre pour Supabase
  Future<List<Map<String, dynamic>>> fetchFavorisAnnonces(List<String> favorisIds) async {
    if (favorisIds.isEmpty) return [];
    final inValues = favorisIds.join(',');
    final data = await Supabase.instance.client
        .from('annonces')
        .select()
        .filter('id', 'in', '($inValues)');
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    final favorisProvider = Provider.of<FavorisProvider>(context);
    final favorisIds = favorisProvider.favoris;

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final bleu = const Color(0xFF113CFC);
    final rouge = const Color(0xFFCE1126);
    final vert = const Color(0xFF009460);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Favoris', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bleu,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(affichageGrille ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: affichageGrille ? "Afficher en liste" : "Afficher en grille",
            color: Colors.white,
            onPressed: () {
              setState(() => affichageGrille = !affichageGrille);
            },
          )
        ],
      ),
      body: favorisProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchFavorisAnnonces(favorisIds),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final annonces = snapshot.data ?? [];
                if (annonces.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite_border, size: 60, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text(
                          "Aucun favori pour l’instant.",
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  );
                }

                if (!affichageGrille) {
                  // --- Affichage LISTE ---
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: annonces.length,
                    itemBuilder: (context, index) {
                      final annonce = annonces[index];
                      final images = List<String>.from(annonce['images'] ?? []);
                      final String annonceId = annonce['id'].toString();

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              images.isNotEmpty
                                  ? images.first
                                  : "https://via.placeholder.com/80x80?text=Photo",
                              width: 54, height: 54, fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            annonce['titre'] ?? 'Sans titre',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(annonce['ville'] ?? ''),
                          trailing: IconButton(
                            icon: Icon(Icons.favorite, color: rouge),
                            tooltip: "Retirer des favoris",
                            onPressed: () async {
                              await favorisProvider.toggleFavori(annonceId);
                              setState(() {});
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnnonceDetailPage(
                                  annonce: AnnonceModel.fromJson(annonce),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                }

                // --- Affichage GRILLE ---
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 2 : 3,
                    childAspectRatio: 0.74,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
                  itemCount: annonces.length,
                  itemBuilder: (_, idx) {
                    final annonce = annonces[idx];
                    final images = List<String>.from(annonce['images'] ?? []);
                    final String annonceId = annonce['id'].toString();

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnnonceDetailPage(
                            annonce: AnnonceModel.fromJson(annonce),
                          ),
                        ),
                      ),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    topRight: Radius.circular(18),
                                  ),
                                  child: Image.network(
                                    images.isNotEmpty
                                        ? images.first
                                        : "https://via.placeholder.com/600x400?text=Photo",
                                    height: 115,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 115,
                                      color: Colors.grey[200],
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.image_not_supported,
                                          size: 40, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        annonce['titre'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${annonce['prix'] ?? ''} ${annonce['devise'] ?? 'GNF'}",
                                        style: TextStyle(
                                          color: vert,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        annonce['ville'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Favori en bas à droite
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () async {
                                  await favorisProvider.toggleFavori(annonceId);
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.favorite,
                                    color: rouge,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
