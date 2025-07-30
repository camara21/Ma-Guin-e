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
      backgroundColor: const Color(0xFFFCF7FB),
      appBar: AppBar(
        title: Text(
          'Prestataires : $metier',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0.8,
      ),
      body: filtres.isEmpty
          ? const Center(child: Text("Aucun prestataire trouvé."))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtres.length,
              itemBuilder: (_, i) {
                final p = filtres[i];
                final nom = (p['nom'] ?? p['name'] ?? '').toString();
                final ville = (p['ville'] ?? p['city'] ?? '').toString();
                final photo = (p['photo_url'] ?? p['image'] ?? '').toString();
                final metier = (p['metier'] ?? '').toString();
                final category = p['category'] ?? _categoryForJob(metier);

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.purple.shade50,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : const AssetImage('assets/avatar.png') as ImageProvider,
                    ),
                    title: Text(
                      nom.isEmpty ? metier : nom,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$category • $ville'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrestataireDetailPage(data: p),
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
