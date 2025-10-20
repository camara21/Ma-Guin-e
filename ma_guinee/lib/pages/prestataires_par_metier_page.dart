// lib/pages/prestataires_par_metier_page.dart
import 'package:flutter/material.dart';
import 'prestataire_detail_page.dart';

/// === Palette Prestataires ===
const Color prestatairesPrimary = Color(0xFF0F766E);
const Color prestatairesSecondary = Color(0xFF14B8A6);
const Color prestatairesOnPrimary = Color(0xFFFFFFFF);
const Color prestatairesOnSecondary = Color(0xFF000000);

class PrestatairesParMetierPage extends StatelessWidget {
  final String metier;
  final List<Map<String, dynamic>> allPrestataires;

  const PrestatairesParMetierPage({
    Key? key,
    required this.metier,
    required this.allPrestataires,
  }) : super(key: key);

  /// Catégories & métiers (accents corrigés + ajouts Guinée)
  static const Map<String, List<String>> _categories = {
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
      'Frigoriste / Technicien froid & clim',
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

  /// Renvoie la catégorie d'un métier
  String _categoryForJob(String? job) {
    if (job == null) return '';
    for (final e in _categories.entries) {
      if (e.value.contains(job)) return e.key;
    }
    return '';
  }

  /// Normalisation très simple (supprime accents de base + lowercase)
  String _normalize(String s) {
    final lower = s.toLowerCase().trim();
    // Remplacement minimal d’accents fréquents pour les comparaisons
    return lower
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('û', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ç', 'c');
  }

  @override
  Widget build(BuildContext context) {
    final target = _normalize(metier);

    final filtres = allPrestataires.where((p) {
      final m = (p['metier'] ?? '').toString();
      // On compare en normalisant pour éviter les soucis d’accents
      return _normalize(m) == target;
    }).toList();

    // Responsive : 1 colonne sur petit écran
    int crossAxisCount = 2;
    final width = MediaQuery.of(context).size.width;
    if (width < 380) crossAxisCount = 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: Text(
          'Prestataires : $metier',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: prestatairesPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: prestatairesPrimary),
        elevation: 0.6,
      ),
      body: filtres.isEmpty
          ? const _EmptyState()
          : Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: crossAxisCount == 1 ? 2.0 : 0.80,
                ),
                itemCount: filtres.length,
                itemBuilder: (_, i) {
                  final p = filtres[i];
                  final nom = (p['nom'] ?? p['name'] ?? '').toString();
                  final ville = (p['ville'] ?? p['city'] ?? '').toString();
                  final photo = (p['photo_url'] ?? p['image'] ?? '').toString();
                  final metierStr = (p['metier'] ?? '').toString();
                  final category = (p['category'] ?? '').toString().isNotEmpty
                      ? (p['category'] ?? '').toString()
                      : _categoryForJob(metierStr);

                  return _ProCard(
                    name: nom.isEmpty ? metierStr : nom,
                    category: category,
                    city: ville,
                    photoUrl: photo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrestataireDetailPage(data: p),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

/// ====================== Widgets UI ======================

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
            // Image + overlay + badge ville
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
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF1F4F7),
                              alignment: Alignment.center,
                              child: Icon(Icons.person,
                                  size: 44,
                                  color: prestatairesPrimary.withOpacity(.35)),
                            ),
                          )
                        : Container(
                            alignment: Alignment.center,
                            color: const Color(0xFFF1F4F7),
                            child: Icon(Icons.person,
                                size: 44,
                                color: prestatairesPrimary.withOpacity(.35)),
                          ),
                  ),
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
                  // Badge ville
                  if (city.isNotEmpty)
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
                  // nom / métier
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
            'Aucun prestataire trouvé pour ce métier.',
            style: TextStyle(
              color: prestatairesPrimary.withOpacity(.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Essaie une autre recherche ou reviens plus tard.',
            style: TextStyle(color: prestatairesPrimary.withOpacity(.7)),
          ),
        ],
      ),
    );
  }
}
