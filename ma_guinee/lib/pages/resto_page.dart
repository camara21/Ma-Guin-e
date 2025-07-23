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
  bool loading = true;

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
      loading = false;
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
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: restos.length,
                  itemBuilder: (context, index) {
                    final resto = restos[index];
                    // Images peut être NULL ou vide ou non liste
                    final List<String> images = (resto['images'] is List)
                        ? List<String>.from(resto['images'])
                        : [];
                    final String image = images.isNotEmpty
                        ? images[0]
                        : 'https://via.placeholder.com/150';

                    return Card(
                      color: Colors.indigo.shade50.withOpacity(0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.only(bottom: 14),
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(image),
                          radius: 26,
                        ),
                        title: Text(
                          resto['nom'] ?? "Sans nom",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          '${resto['cuisine'] ?? "Cuisine"} • ${resto['ville'] ?? "Ville"}',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        trailing: const FaIcon(FontAwesomeIcons.utensils, color: Color(0xFF009460)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RestoDetailPage(restoId: resto['id']),
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
