import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prestataire_model.dart';
import '../providers/prestataires_provider.dart';
import 'inscription_prestataire_page.dart';
import 'prestataire_detail_page.dart';
import 'prestataires_par_metier_page.dart'; // optionnel

class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  final Map<String, List<String>> categories = {
    'Artisans & BTP': [
      'Maçon','Plombier','Électricien','Soudeur','Charpentier','Couvreur','Peintre en bâtiment',
      'Mécanicien','Menuisier','Vitrier','Tôlier','Carreleur','Poseur de fenêtres/portes','Ferrailleur',
    ],
    'Beauté & Bien-être': [
      'Coiffeur / Coiffeuse','Esthéticienne','Maquilleuse','Barbier','Masseuse','Spa thérapeute',
      'Onglerie / Prothésiste ongulaire',
    ],
    'Couture & Mode': [
      'Couturier / Couturière','Styliste / Modéliste','Brodeur / Brodeuse','Teinturier','Designer textile',
    ],
    'Alimentation': [
      'Cuisinier','Traiteur','Boulanger','Pâtissier','Vendeur de fruits/légumes','Marchand de poisson','Restaurateur',
    ],
    'Transport & Livraison': [
      'Chauffeur particulier','Taxi-moto','Taxi-brousse','Livreur','Transporteur',
    ],
    'Services domestiques': [
      'Femme de ménage','Nounou','Agent d’entretien','Gardiennage','Blanchisserie',
    ],
    'Services professionnels': [
      'Secrétaire','Traducteur','Comptable','Consultant','Notaire',
    ],
    'Éducation & formation': [
      'Enseignant','Tuteur','Formateur','Professeur particulier','Coach scolaire',
    ],
    'Santé & Bien-être': [
      'Infirmier','Docteur','Kinésithérapeute','Psychologue','Pharmacien',
    ],
  };

  String selectedCategory = 'Tous';
  String selectedJob = 'Tous';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<PrestatairesProvider>().loadPrestataires());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PrestatairesProvider>();
    final all = prov.prestataires;

    // Filtres
    List<PrestataireModel> list = all;
    if (selectedCategory != 'Tous') {
      list = list.where((p) => p.category == selectedCategory).toList();
    }
    if (selectedJob != 'Tous') {
      list = list.where((p) => p.metier == selectedJob).toList();
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((p) {
        return p.metier.toLowerCase().contains(q) ||
            p.ville.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Prestataires par métier',
          style: TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.7,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InscriptionPrestatairePage()),
              );
            },
            icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF113CFC)),
            label: const Text("S'inscrire", style: TextStyle(color: Color(0xFF113CFC))),
          ),
        ],
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.error != null
              ? Center(child: Text('Erreur: ${prov.error}'))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      // Bannière
                      Container(
                        width: double.infinity,
                        height: 80,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFCE1126), Color(0xFFFCD116)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Trouvez un professionnel\ndans tous les métiers",
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

                      // Filtres lignes
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: selectedCategory,
                            items: <DropdownMenuItem<String>>[
                              const DropdownMenuItem(
                                  value: 'Tous', child: Text('Domaines de métiers')),
                              ...categories.keys.map(
                                (c) => DropdownMenuItem(value: c, child: Text(c)),
                              )
                            ],
                            onChanged: (v) {
                              setState(() {
                                selectedCategory = v!;
                                selectedJob = 'Tous';
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          if (selectedCategory != 'Tous')
                            DropdownButton<String>(
                              value: selectedJob,
                              items: [
                                const DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                                ...categories[selectedCategory]!.map(
                                  (job) => DropdownMenuItem(value: job, child: Text(job)),
                                ),
                              ],
                              onChanged: (v) => setState(() => selectedJob = v!),
                            ),
                        ],
                      ),

                      // Recherche
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un métier, une ville...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF113CFC)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6F9),
                        ),
                        onChanged: (v) => setState(() => searchQuery = v),
                      ),
                      const SizedBox(height: 10),

                      // Liste
                      Expanded(
                        child: list.isEmpty
                            ? const Center(child: Text("Aucun prestataire trouvé."))
                            : ListView.builder(
                                itemCount: list.length,
                                itemBuilder: (_, i) {
                                  final p = list[i];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PrestataireDetailPage(data: p.toJson()),
                                        ),
                                      );
                                    },
                                    child: Card(
                                      color: Colors.white,
                                      elevation: 2,
                                      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.indigo.shade50,
                                          backgroundImage: p.photoUrl.isNotEmpty
                                              ? NetworkImage(p.photoUrl)
                                              : const AssetImage('assets/avatar.png') as ImageProvider,
                                        ),
                                        title: Text(
                                          p.metier,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text('${p.category} • ${p.ville}'),
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
