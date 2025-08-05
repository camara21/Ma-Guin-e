import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'resto_detail_page.dart';

class RestoPage extends StatefulWidget {
  const RestoPage({super.key});

  @override
  State<RestoPage> createState() => _RestoPageState();
}

class _RestoPageState extends State<RestoPage> {
  List<Map<String, dynamic>> restos = [];
  List<Map<String, dynamic>> filteredRestos = [];
  bool loading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRestos();
  }

  Future<void> _loadRestos() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client
        .from('restaurants')
        .select()
        .order('nom');
    setState(() {
      restos = List<Map<String, dynamic>>.from(data);
      filteredRestos = restos;
      loading = false;
    });
  }

  void _filterRestos(String value) {
    final q = value.toLowerCase();
    setState(() {
      searchQuery = value;
      filteredRestos = restos.where((resto) {
        final nom = (resto['nom'] ?? '').toLowerCase();
        final ville = (resto['ville'] ?? '').toLowerCase();
        final cuisine = (resto['cuisine'] ?? '').toLowerCase();
        return nom.contains(q) || ville.contains(q) || cuisine.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF113CFC),
        title: const Text(
          'Restaurants',
          style: TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : restos.isEmpty
              ? const Center(child: Text("Aucun restaurant trouvé."))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      // Banner
                      Container(
                        width: double.infinity,
                        height: 75,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFCD116), Color(0xFF009460)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Découvrez les meilleurs restaurants de Guinée",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Barre de recherche
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un resto, une ville, une cuisine...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF113CFC)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6F9),
                        ),
                        onChanged: _filterRestos,
                      ),
                      const SizedBox(height: 12),
                      // Grille de cartes restaurants
                      Expanded(
                        child: filteredRestos.isEmpty
                            ? const Center(child: Text("Aucun restaurant trouvé."))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.77,
                                ),
                                itemCount: filteredRestos.length,
                                itemBuilder: (context, index) {
                                  final resto = filteredRestos[index];
                                  final List<String> images = (resto['images'] is List)
                                      ? List<String>.from(resto['images'])
                                      : [];
                                  final String image = images.isNotEmpty
                                      ? images[0]
                                      : 'https://via.placeholder.com/300x200.png?text=Restaurant';

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RestoDetailPage(restoId: resto['id']),
                                        ),
                                      );
                                    },
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Image principale
                                          AspectRatio(
                                            aspectRatio: 16 / 11,
                                            child: Image.network(
                                              image,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  resto['nom'] ?? "Sans nom",
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  resto['ville'] ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if ((resto['cuisine'] ?? '').toString().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Text(
                                                      resto['cuisine'],
                                                      style: const TextStyle(
                                                        color: Color(0xFF113CFC),
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                if (resto['prix_moyen'] != null && resto['prix_moyen'].toString().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 1.5),
                                                    child: Text(
                                                      'Prix moyen : ${resto['prix_moyen']} ${resto['devise'] ?? 'GNF'}',
                                                      style: const TextStyle(
                                                        color: Color(0xFF009460),
                                                        fontSize: 12,
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
                ),
    );
  }
}
