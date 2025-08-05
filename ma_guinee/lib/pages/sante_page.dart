import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sante_detail_page.dart';

class SantePage extends StatefulWidget {
  const SantePage({super.key});

  @override
  State<SantePage> createState() => _SantePageState();
}

class _SantePageState extends State<SantePage> {
  List<Map<String, dynamic>> centres = [];
  List<Map<String, dynamic>> filteredCentres = [];
  bool loading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCentres();
  }

  Future<void> _loadCentres() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client
        .from('cliniques')
        .select()
        .order('nom');
    setState(() {
      centres = List<Map<String, dynamic>>.from(data);
      filteredCentres = centres;
      loading = false;
    });
  }

  void _filterCentres(String value) {
    final q = value.toLowerCase();
    setState(() {
      searchQuery = value;
      filteredCentres = centres.where((centre) {
        final nom = (centre['nom'] ?? '').toLowerCase();
        final ville = (centre['ville'] ?? '').toLowerCase();
        final spec = (centre['specialite'] ?? centre['description'] ?? '').toLowerCase();
        return nom.contains(q) || ville.contains(q) || spec.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Services de santé",
          style: TextStyle(
            color: Color(0xFF009460),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF009460)),
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : centres.isEmpty
              ? const Center(child: Text("Aucun centre de santé trouvé."))
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
                            colors: [Color(0xFF009460), Color(0xFF2EC4F1)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Découvrez tous les centres et cliniques de Guinée",
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
                      // Recherche
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un centre, une ville, une spécialité...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF009460)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6F9),
                        ),
                        onChanged: _filterCentres,
                      ),
                      const SizedBox(height: 12),
                      // Grille de cartes centres/cliniques
                      Expanded(
                        child: filteredCentres.isEmpty
                            ? const Center(child: Text("Aucun centre de santé trouvé."))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.77,
                                ),
                                itemCount: filteredCentres.length,
                                itemBuilder: (context, index) {
                                  final centre = filteredCentres[index];
                                  final List<String> images = (centre['images'] is List)
                                      ? List<String>.from(centre['images'])
                                      : [];
                                  final String image = images.isNotEmpty
                                      ? images[0]
                                      : 'https://via.placeholder.com/300x200.png?text=Sant%C3%A9';

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SanteDetailPage(cliniqueId: centre['id']),
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
                                                child: const Icon(Icons.local_hospital, size: 40, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  centre['nom'] ?? "Sans nom",
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  centre['ville'] ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if ((centre['specialite'] ?? '').toString().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Text(
                                                      centre['specialite'],
                                                      style: const TextStyle(
                                                        color: Color(0xFF009460),
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
                ),
    );
  }
}
