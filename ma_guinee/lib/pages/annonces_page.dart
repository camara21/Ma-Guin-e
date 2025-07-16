import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/annonce_provider.dart';
import '../models/annonce_model.dart';
import '../components/annonce_grid_card.dart';
import 'annonce_detail_page.dart';
import 'create_annonce_page.dart';

class AnnoncesPage extends StatefulWidget {
  const AnnoncesPage({super.key});

  @override
  State<AnnoncesPage> createState() => _AnnoncesPageState();
}

class _AnnoncesPageState extends State<AnnoncesPage> {
  final List<String> _filtres = ['Tous', 'Emploi', 'Vente', 'Services', 'Immobilier'];
  String _filtreActuel = 'Tous';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<AnnonceProvider>(context, listen: false).loadAnnonces());
  }

  @override
  Widget build(BuildContext context) {
    final annonceProvider = Provider.of<AnnonceProvider>(context);
    final isLoading = annonceProvider.isLoading;

    // 🔍 Filtrage combiné catégorie + recherche
    final filteredAnnonces = annonceProvider
        .filterByCategorie(_filtreActuel)
        .where((annonce) =>
            annonce.titre.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            annonce.description.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();

    final int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Petites Annonces'),
      ),
      body: Column(
        children: [
          // 🔍 Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une annonce...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 10),

          // 🧩 Filtres
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filtres.length,
              itemBuilder: (context, index) {
                final filtre = _filtres[index];
                final selected = _filtreActuel == filtre;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filtre),
                    selected: selected,
                    onSelected: (_) => setState(() => _filtreActuel = filtre),
                    selectedColor: const Color(0xFFCE1126),
                    backgroundColor: Colors.grey[200],
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // 📦 Grille des annonces
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredAnnonces.isEmpty
                    ? const Center(child: Text("Aucune annonce disponible."))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredAnnonces.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 3 / 3.5,
                        ),
                        itemBuilder: (context, index) {
                          final AnnonceModel annonce = filteredAnnonces[index];
                          return AnnonceGridCard(
                            annonce: annonce,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnnonceDetailPage(annonce: annonce),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),

      // ➕ Bouton déposer
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateAnnoncePage()),
          );
        },
        icon: const Icon(Icons.post_add),
        label: const Text("Déposer"),
        backgroundColor: const Color(0xFFCE1126),
      ),
    );
  }
}
