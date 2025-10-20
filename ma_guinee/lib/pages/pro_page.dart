// lib/pages/pro_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/prestataire_model.dart';
import '../providers/prestataires_provider.dart';
import 'inscription_prestataire_page.dart';
import 'prestataire_detail_page.dart';

/// === Palette Prestataires (donnée par l'utilisateur) ===
const Color prestatairesPrimary = Color(0xFF0F766E);
const Color prestatairesSecondary = Color(0xFF14B8A6);
const Color prestatairesOnPrimary = Color(0xFFFFFFFF);
const Color prestatairesOnSecondary = Color(0xFF000000);

class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  /// Catégories & métiers (accents corrigés + ajouts pour la Guinée)
  static const Map<String, List<String>> categories = {
    'Artisans & BTP': [
      'Maçon',
      'Plombier',
      'Électricien',
      'Soudeur',
      'Charpentier',
      'Couvreur',
      'Peintre en bâtiment',
      'Mécanicien',
      'Menuisier',
      'Vitrier',
      'Tôlier / Carrossier',
      'Carreleur',
      'Poseur de fenêtres/portes',
      'Ferrailleur',
      'Frigoriste / Technicien froid & clim', // ajouté
      'Topographe / Géomètre',
      'Technicien solaire / Photovoltaïque',
    ],
    'Beauté & Bien-être': [
      'Coiffeur / Coiffeuse',
      'Esthéticienne',
      'Maquilleuse',
      'Barbier',
      'Masseuse',
      'Spa thérapeute',
      'Onglerie / Prothésiste ongulaire',
    ],
    'Couture & Mode': [
      'Couturier / Couturière',
      'Styliste / Modéliste',
      'Brodeur / Brodeuse',
      'Teinturier',
      'Designer textile',
      'Cordonnier',
      'Tisserand',
    ],
    'Alimentation': [
      'Cuisinier',
      'Traiteur',
      'Boulanger',
      'Pâtissier',
      'Vendeur de fruits/légumes',
      'Marchand de poisson',
      'Restaurateur',
      'Boucher / Charcutier',
    ],
    'Transport & Livraison': [
      'Chauffeur particulier',
      'Taxi-moto',
      'Taxi-brousse',
      'Livreur',
      'Transporteur',
      'Déménageur',
      'Conducteur engins BTP',
    ],
    'Services domestiques': [
      'Femme de ménage',
      'Nounou',
      'Agent d’entretien',
      'Gardiennage',
      'Blanchisserie',
      'Cuisinière à domicile',
    ],
    'Services professionnels': [
      'Secrétaire',
      'Traducteur',
      'Comptable',
      'Consultant',
      'Notaire',
      'Photographe / Vidéaste',
      'Imprimeur',
      'Agent immobilier',
    ],
    'Éducation & Formation': [
      'Enseignant',
      'Tuteur',
      'Formateur',
      'Professeur particulier',
      'Coach scolaire',
      'Moniteur auto-école',
    ],
    'Santé & Bien-être': [
      'Infirmier',
      'Docteur',
      'Kinésithérapeute',
      'Psychologue',
      'Pharmacien',
      'Médecine traditionnelle',
      'Sage-femme',
    ],
    'Technologies & Digital': [
      'Développeur / Développeuse',
      'Ingénieur logiciel',
      'Data Scientist',
      'Développeur mobile',
      'Designer UI/UX',
      'Administrateur systèmes',
      'Chef de projet IT',
      'Technicien réseau',
      'Analyste sécurité',
      'Community Manager',
      'Growth Hacker',
      'Webmaster',
      'DevOps Engineer',
      'Technicien audiovisuel',
    ],
    'Événementiel & Culture': [
      'DJ / Animateur',
      'Maître de cérémonie',
      'Décorateur événementiel',
      'Traiteur événementiel',
      'Sonorisateur / Éclairagiste',
      'Guide touristique',
    ],
  };

  // --- États UI ---
  String selectedCategory = 'Tous';
  String selectedJob = 'Tous';
  String searchQuery = '';

  // --- Listes pré-calculées (corrige l’erreur const + perf) ---
  late final List<String> _allCategories = ['Tous', ...categories.keys];

  List<String> _jobsForCategory(String category) {
    if (category == 'Tous') return const ['Tous'];
    final list = categories[category] ?? const <String>[];
    return ['Tous', ...list];
  }

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
    Future.microtask(
      () => context.read<PrestatairesProvider>().loadPrestataires(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PrestatairesProvider>();
    final all = prov.prestataires;

    // --- Filtrage ---
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
        return p.metier.toLowerCase().contains(q) ||
            p.ville.toLowerCase().contains(q) ||
            cat.toLowerCase().contains(q);
      }).toList();
    }

    // --- Responsive: 1 colonne si largeur < 380, sinon 2 ---
    int crossAxisCount = 2;
    final width = MediaQuery.of(context).size.width;
    if (width < 380) crossAxisCount = 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.6,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: prestatairesSecondary.withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.handyman, color: prestatairesSecondary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Prestataires par métier',
                    style: TextStyle(
                      color: prestatairesPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: prestatairesPrimary),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InscriptionPrestatairePage()),
            ),
            icon: const Icon(Icons.person_add_alt_1, color: prestatairesPrimary),
            label: const Text("S'inscrire", style: TextStyle(color: prestatairesPrimary)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.error != null
              ? Center(child: Text('Erreur: ${prov.error}'))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Column(
                    children: [
                      // --- Bannière ---
                      const _HeroBanner(),

                      // --- Recherche ---
                      const SizedBox(height: 8),
                      _SearchField(
                        onChanged: (v) => setState(() => searchQuery = v),
                      ),

                      // --- Filtres Chips ---
                      const SizedBox(height: 10),
                      _CategoryChips(
                        categories: _allCategories, // ✅ plus de const spread
                        selected: selectedCategory,
                        onSelected: (v) {
                          setState(() {
                            selectedCategory = v;
                            selectedJob = 'Tous';
                          });
                        },
                      ),

                      if (selectedCategory != 'Tous') ...[
                        const SizedBox(height: 8),
                        _JobChips(
                          jobs: _jobsForCategory(selectedCategory),
                          selected: selectedJob,
                          onSelected: (v) => setState(() => selectedJob = v),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // --- Grille des prestataires ---
                      Expanded(
                        child: list.isEmpty
                            ? const _EmptyState()
                            : GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: crossAxisCount == 1 ? 2.0 : .78,
                                ),
                                itemCount: list.length,
                                itemBuilder: (_, i) {
                                  final p = list[i];
                                  final cat = p.category.isNotEmpty ? p.category : _categoryForJob(p.metier);
                                  return _ProCard(
                                    name: p.metier,
                                    category: cat,
                                    city: p.ville,
                                    photoUrl: p.photoUrl,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PrestataireDetailPage(data: p.toJson()),
                                        ),
                                      );
                                    },
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

/// ====================== Widgets UI ======================

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [prestatairesPrimary, prestatairesSecondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: prestatairesPrimary.withOpacity(.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -10,
            child: Icon(Icons.settings, size: 120, color: Colors.white.withOpacity(.06)),
          ),
          const Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Trouvez un professionnel\npour chaque besoin",
                  style: TextStyle(
                    color: prestatairesOnPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Rechercher un métier, une ville…',
        prefixIcon: const Icon(Icons.search, color: prestatairesPrimary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6EBEF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6EBEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: prestatairesSecondary, width: 1.4),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = categories[i];
          final isSel = c == selected;
          return ChoiceChip(
            label: Text(
              c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSel ? prestatairesOnSecondary : prestatairesPrimary,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            selected: isSel,
            onSelected: (_) => onSelected(c),
            selectedColor: prestatairesSecondary,
            backgroundColor: Colors.white,
            side: BorderSide(color: isSel ? prestatairesSecondary : const Color(0xFFE1E7EC)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          );
        },
      ),
    );
  }
}

class _JobChips extends StatelessWidget {
  final List<String> jobs;
  final String selected;
  final ValueChanged<String> onSelected;

  const _JobChips({
    required this.jobs,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final j = jobs[i];
          final isSel = j == selected;
          return ChoiceChip(
            label: Text(
              j,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSel ? prestatairesOnSecondary : prestatairesPrimary,
              ),
            ),
            selected: isSel,
            onSelected: (_) => onSelected(j),
            selectedColor: prestatairesSecondary.withOpacity(.95),
            backgroundColor: Colors.white,
            side: BorderSide(color: isSel ? prestatairesSecondary : const Color(0xFFE1E7EC)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          );
        },
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  final String name;
  final String category;
  final String city;
  final String photoUrl;
  final VoidCallback onTap;

  const _ProCard({
    required this.name,
    required this.category,
    required this.city,
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: prestatairesPrimary.withOpacity(.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE6EBEF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + overlay
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 11,
                    child: photoUrl.isNotEmpty
                        ? Image.network(photoUrl, fit: BoxFit.cover)
                        : Container(
                            alignment: Alignment.center,
                            color: const Color(0xFFF1F4F7),
                            child: Icon(Icons.person, size: 44, color: prestatairesPrimary.withOpacity(.35)),
                          ),
                  ),
                  // gradient bas pour lisibilité
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(.45)],
                        ),
                      ),
                    ),
                  ),
                  // badge ville
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: prestatairesSecondary.withOpacity(.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: prestatairesOnSecondary),
                          const SizedBox(width: 4),
                          Text(
                            city,
                            style: TextStyle(
                              color: prestatairesOnSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Infos
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // métier
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: prestatairesPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // catégorie
                  Row(
                    children: [
                      Icon(Icons.work_outline, size: 14, color: prestatairesPrimary.withOpacity(.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: prestatairesPrimary.withOpacity(.8),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 54, color: prestatairesPrimary.withOpacity(.35)),
          const SizedBox(height: 10),
          Text(
            'Aucun prestataire trouvé.',
            style: TextStyle(
              color: prestatairesPrimary.withOpacity(.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Essaye d’autres mots-clés ou catégories.',
            style: TextStyle(color: prestatairesPrimary.withOpacity(.7)),
          ),
        ],
      ),
    );
  }
}
