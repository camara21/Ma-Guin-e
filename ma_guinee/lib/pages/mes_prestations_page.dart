import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';

class MesPrestationsPage extends StatelessWidget {
  final List<Map<String, dynamic>> prestations;

  const MesPrestationsPage({super.key, required this.prestations});

  String _categoryForJob(String? job) {
    if (job == null) return '';
    final Map<String, List<String>> categories = {
      'Artisans & BTP': ['Maçon', 'Plombier', 'Électricien', 'Soudeur', 'Charpentier', 'Couvreur', 'Peintre en bâtiment', 'Mécanicien', 'Menuisier', 'Vitrier', 'Tôlier', 'Carreleur', 'Poseur de fenêtres/portes', 'Ferrailleur'],
      'Beauté & Bien-être': ['Coiffeur / Coiffeuse', 'Esthéticienne', 'Maquilleuse', 'Barbier', 'Masseuse', 'Spa thérapeute', 'Onglerie / Prothésiste ongulaire'],
      'Couture & Mode': ['Couturier / Couturière', 'Styliste / Modéliste', 'Brodeur / Brodeuse', 'Teinturier', 'Designer textile'],
      'Alimentation': ['Cuisinier', 'Traiteur', 'Boulanger', 'Pâtissier', 'Vendeur de fruits/légumes', 'Marchand de poisson', 'Restaurateur'],
      'Transport & Livraison': ['Chauffeur particulier', 'Taxi-moto', 'Taxi-brousse', 'Livreur', 'Transporteur'],
      'Services domestiques': ['Femme de ménage', 'Nounou', 'Agent d’entretien', 'Gardiennage', 'Blanchisserie'],
      'Services professionnels': ['Secrétaire', 'Traducteur', 'Comptable', 'Consultant', 'Notaire'],
      'Éducation & formation': ['Enseignant', 'Tuteur', 'Formateur', 'Professeur particulier', 'Coach scolaire'],
      'Santé & Bien-être': ['Infirmier', 'Docteur', 'Kinésithérapeute', 'Psychologue', 'Pharmacien', 'Médecine traditionnelle'],
      'Technologies & Digital': ['Développeur / Développeuse', 'Ingénieur logiciel', 'Data Scientist', 'Développeur mobile', 'Designer UI/UX', 'Administrateur systèmes', 'Chef de projet IT', 'Technicien réseau', 'Analyste sécurité', 'Community Manager', 'Growth Hacker', 'Webmaster', 'DevOps Engineer'],
    };

    for (final e in categories.entries) {
      if (e.value.contains(job)) return e.key;
    }
    return '';
  }

  Future<void> _supprimerPrestataire(BuildContext context, String id) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('prestataires').delete().eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Prestataire supprimé avec succès.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur suppression : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes prestations')),
      body: prestations.isEmpty
          ? const Center(child: Text("Aucune prestation enregistrée."))
          : ListView.builder(
              itemCount: prestations.length,
              itemBuilder: (context, index) {
                final p = prestations[index];
                final id = p['id']?.toString() ?? '';
                final metier = p['metier'] ?? p['job'] ?? '';
                final ville = p['ville'] ?? p['city'] ?? '';
                final cat = p['category'] ?? _categoryForJob(metier);
                final photo = p['photo_url'] ?? p['image'];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    leading: photo != null && photo != ''
                        ? CircleAvatar(backgroundImage: NetworkImage(photo))
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(metier.toString()),
                    subtitle: Text('$ville • $cat'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.editPrestataire,
                              arguments: p,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Confirmer la suppression"),
                                content: const Text("Voulez-vous supprimer cette prestation ?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Annuler"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("Supprimer"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && id.isNotEmpty) {
                              await _supprimerPrestataire(context, id);
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.editPrestataire,
                        arguments: p,
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
