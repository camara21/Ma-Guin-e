import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/prestataire_model.dart';
import '../providers/prestataires_provider.dart';
import 'inscription_prestataire_page.dart';
import 'prestataire_detail_page.dart';

class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  static const Map<String, List<String>> categories = {
    'Artisans & BTP': [
      'Maçon', 'Plombier', 'Électricien', 'Soudeur', 'Charpentier',
      'Couvreur', 'Peintre en bâtiment', 'Mécanicien', 'Menuisier',
      'Vitrier', 'Tôlier', 'Carreleur', 'Poseur de fenêtres/portes',
      'Ferrailleur', 'Verrier',
    ],
    'Beauté & Bien-être': [
      'Coiffeur / Coiffeuse', 'Esthéticienne', 'Maquilleuse',
      'Barbier', 'Masseuse', 'Spa thérapeute', 'Onglerie / Prothésiste ongulaire',
    ],
    'Couture & Mode': [
      'Couturier / Couturière', 'Styliste / Modéliste',
      'Brodeur / Brodeuse', 'Teinturier', 'Designer textile',
    ],
    'Alimentation': [
      'Cuisinier', 'Traiteur', 'Boulanger', 'Pâtissier',
      'Vendeur de fruits/légumes', 'Marchand de poisson', 'Restaurateur',
    ],
    'Transport & Livraison': [
      'Chauffeur particulier', 'Taxi-moto', 'Taxi-brousse',
      'Livreur', 'Transporteur',
    ],
    'Services domestiques': [
      'Femme de ménage', 'Nounou', 'Agent d’entretien',
      'Gardiennage', 'Blanchisserie',
    ],
    'Services professionnels': [
      'Secrétaire', 'Traducteur', 'Comptable',
      'Consultant', 'Notaire',
    ],
    'Éducation & formation': [
      'Enseignant', 'Tuteur', 'Formateur',
      'Professeur particulier', 'Coach scolaire',
    ],
    'Santé & Bien-être': [
      'Infirmier', 'Docteur', 'Kinésithérapeute',
      'Psychologue', 'Pharmacien', 'Médecine traditionnelle',
    ],
    'Technologies & Digital': [
      'Développeur / Développeuse', 'Ingénieur logiciel', 'Data Scientist',
      'Développeur mobile', 'Designer UI/UX', 'Administrateur systèmes',
      'Chef de projet IT', 'Technicien réseau', 'Analyste sécurité',
      'Community Manager', 'Growth Hacker', 'Webmaster', 'DevOps Engineer',
    ],
  };

  String selectedCategory = 'Tous';
  String selectedJob = 'Tous';
  String searchQuery = '';

  String _categoryForJob(String? job) {
    if (job == null) return '';
    for (final e in categories.entries) {
      if (e.value.contains(job)) return e.key;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<PrestatairesProvider>().loadPrestataires());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PrestatairesProvider>();
    final all = prov.prestataires;

    // Filtering logic
    List<PrestataireModel> list = all;
    if (selectedCategory != 'Tous') {
      list = list.where((p) {
        final cat = p.category.isNotEmpty ? p.category : _categoryForJob(p.metier);
        return cat == selectedCategory;
      }).toList();
    }
    if (selectedJob != 'Tous') {
      list = list.where((p) => p.metier == selectedJob).toList();
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((p) {
        final cat = p.category.isNotEmpty ? p.category : _categoryForJob(p.metier);
        return p.metier.toLowerCase().contains(q)
            || p.ville.toLowerCase().contains(q)
            || cat.toLowerCase().contains(q);
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
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InscriptionPrestatairePage()),
            ),
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
                      // Header Banner
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

                      // Filters
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedCategory,
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem(value: 'Tous', child: Text('Domaines de métiers')),
                                ...categories.keys.map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c))),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  selectedCategory = v!;
                                  selectedJob = 'Tous';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (selectedCategory != 'Tous')
                            Expanded(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedJob,
                                items: [
                                  const DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                                  ...categories[selectedCategory]!
                                      .map((job) => DropdownMenuItem(value: job, child: Text(job))),
                                ],
                                onChanged: (v) => setState(() => selectedJob = v!),
                              ),
                            ),
                        ],
                      ),

                      // Search field
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un métier, une ville...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF113CFC)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6F9),
                        ),
                        onChanged: (v) => setState(() => searchQuery = v),
                      ),

                      const SizedBox(height: 10),

                      // List of cards
                      Expanded(
                        child: list.isEmpty
                            ? const Center(child: Text("Aucun prestataire trouvé."))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.8,
                                ),
                                itemCount: list.length,
                                itemBuilder: (_, i) {
                                  final p = list[i];
                                  final cat = p.category.isNotEmpty
                                      ? p.category
                                      : _categoryForJob(p.metier);

                                  return GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PrestataireDetailPage(data: p.toJson()),
                                      ),
                                    ),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                      clipBehavior: Clip.hardEdge,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Image
                                          AspectRatio(
                                            aspectRatio: 16 / 11,
                                            child: p.photoUrl.isNotEmpty
                                                ? Image.network(p.photoUrl, fit: BoxFit.cover)
                                                : Container(
                                                    color: Colors.grey[200],
                                                    alignment: Alignment.center,
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 40,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                          ),
                                          // Info
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.metier,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  cat,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  p.ville,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
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
