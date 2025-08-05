import 'package:flutter/material.dart';
import 'prestataire_detail_page.dart';

class PrestatairesParMetierPage extends StatelessWidget {
  final String metier;
  final List<Map<String, dynamic>> allPrestataires;

  const PrestatairesParMetierPage({
    Key? key,
    required this.metier,
    required this.allPrestataires,
  }) : super(key: key);

  String _categoryForJob(String? job) {
    if (job == null) return '';
    final Map<String, List<String>> categories = {
      'Artisans & BTP': [
        'Maçon', 'Plombier', 'Électricien', 'Soudeur', 'Charpentier',
        'Couvreur', 'Peintre en bâtiment', 'Mécanicien', 'Menuisier',
        'Vitrier', 'Tôlier', 'Carreleur', 'Poseur de fenêtres/portes', 'Ferrailleur',
      ],
      'Beauté & Bien-être': [
        'Coiffeur / Coiffeuse', 'Esthéticienne', 'Maquilleuse',
        'Barbier', 'Masseuse', 'Spa thérapeute', 'Onglerie / Prothésiste ongulaire',
      ],
      'Couture & Mode': [
        'Couturier / Couturière', 'Styliste / Modéliste', 'Brodeur / Brodeuse',
        'Teinturier', 'Designer textile',
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

    for (final e in categories.entries) {
      if (e.value.contains(job)) return e.key;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final m = metier.toLowerCase();
    final filtres = allPrestataires.where((p) {
      return (p['metier'] ?? '').toString().toLowerCase() == m;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F9),
      appBar: AppBar(
        title: Text(
          'Prestataires : $metier',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF113CFC)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        elevation: 0.8,
      ),
      body: filtres.isEmpty
          ? const Center(child: Text("Aucun prestataire trouvé."))
          : Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 1 pour mobile, 2+ pour web/tablette
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.80,
                ),
                itemCount: filtres.length,
                itemBuilder: (_, i) {
                  final p = filtres[i];
                  final nom = (p['nom'] ?? p['name'] ?? '').toString();
                  final ville = (p['ville'] ?? p['city'] ?? '').toString();
                  final photo = (p['photo_url'] ?? p['image'] ?? '').toString();
                  final metier = (p['metier'] ?? '').toString();
                  final category = p['category'] ?? _categoryForJob(metier);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrestataireDetailPage(data: p),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 11,
                            child: photo.isNotEmpty
                                ? Image.network(photo, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[200],
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.person, size: 40, color: Colors.grey),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.person, size: 40, color: Colors.grey),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nom.isEmpty ? metier : nom,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ville,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
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
    );
  }
}
