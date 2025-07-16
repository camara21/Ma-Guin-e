import 'package:flutter/material.dart';
import 'prestataire_detail_page.dart';

class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  String selectedCategory = 'Tous';
  String searchText = '';

  final List<String> categories = [
    'Tous',
    'Artisanat',
    'Bâtiment',
    'Services',
    'Transport',
    'Éducation',
    'Santé',
    'Mode',
    'Beauté',
    'Électronique',
    'Agroalimentaire',
  ];

  final List<Map<String, dynamic>> prestataires = [
    {
      'nom': 'Alpha Coiffure',
      'specialite': 'Coiffure homme',
      'ville': 'Matoto',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.cut,
      'categorie': 'Beauté',
    },
    {
      'nom': 'Fatou Plomberie',
      'specialite': 'Plomberie générale',
      'ville': 'Dixinn',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.plumbing,
      'categorie': 'Bâtiment',
    },
    {
      'nom': 'Issa Électricité',
      'specialite': 'Installation électrique',
      'ville': 'Ratoma',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.electrical_services,
      'categorie': 'Bâtiment',
    },
    {
      'nom': 'Mamadou Couture',
      'specialite': 'Couturier traditionnel',
      'ville': 'Kaloum',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.checkroom,
      'categorie': 'Mode',
    },
    {
      'nom': 'Aïssatou Tresses',
      'specialite': 'Tresse africaine',
      'ville': 'Nongo',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.face_retouching_natural,
      'categorie': 'Beauté',
    },
    {
      'nom': 'Kaba Menuiserie',
      'specialite': 'Menuisier bois et alu',
      'ville': 'Kipé',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.chair,
      'categorie': 'Artisanat',
    },
    {
      'nom': 'Diallo Taxi',
      'specialite': 'Chauffeur privé',
      'ville': 'Lambanyi',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.local_taxi,
      'categorie': 'Transport',
    },
    {
      'nom': 'Thierno Informatique',
      'specialite': 'Dépannage PC',
      'ville': 'Cosa',
      'image': 'https://via.placeholder.com/150',
      'icone': Icons.computer,
      'categorie': 'Électronique',
    },
  ];

  List<Map<String, dynamic>> get prestatairesFiltres {
    final data = selectedCategory == 'Tous'
        ? prestataires
        : prestataires.where((p) => p['categorie'] == selectedCategory).toList();

    if (searchText.isEmpty) return data;

    return data.where((p) =>
      p['nom'].toLowerCase().contains(searchText.toLowerCase()) ||
      p['specialite'].toLowerCase().contains(searchText.toLowerCase())
    ).toList();
  }

  void _showCategoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: categories.map((cat) {
            return ListTile(
              leading: selectedCategory == cat
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              title: Text(cat),
              onTap: () {
                setState(() {
                  selectedCategory = cat;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestataires'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 🔍 Recherche
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un prestataire...',
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

          // 🔽 Bouton menu catégories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Catégorie : $selectedCategory'),
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => _showCategoryModal(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 📋 Liste des prestataires
          Expanded(
            child: prestatairesFiltres.isEmpty
                ? const Center(child: Text("Aucun prestataire trouvé."))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: prestatairesFiltres.length,
                    itemBuilder: (context, index) {
                      final pro = prestatairesFiltres[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(pro['image']),
                            radius: 26,
                          ),
                          title: Text(
                            pro['nom'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${pro['specialite']} • ${pro['ville']}'),
                          trailing: Icon(pro['icone'], color: const Color(0xFFCE1126)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrestataireDetailPage(prestataire: pro),
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
