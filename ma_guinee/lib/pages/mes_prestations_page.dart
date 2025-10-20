import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';
import 'prestataire_detail_page.dart';

class MesPrestationsPage extends StatefulWidget {
  final List<Map<String, dynamic>> prestations;
  const MesPrestationsPage({super.key, required this.prestations});

  @override
  State<MesPrestationsPage> createState() => _MesPrestationsPageState();
}

class _MesPrestationsPageState extends State<MesPrestationsPage> {
  // Palette Prestataire
  static const Color prestatairePrimary = Color(0xFFCE1126); // rouge
  static const Color prestataireSecondary = Color(0xFFFCD116); // jaune
  static const Color prestataireAccent = Color(0xFF009460); // vert
  static const Color prestataireOnPrimary = Color(0xFFFFFFFF);

  late List<Map<String, dynamic>> _prestations;

  @override
  void initState() {
    super.initState();
    _prestations = List<Map<String, dynamic>>.from(widget.prestations);
  }

  String _categoryForJob(String? job) {
    if (job == null) return '';
    final Map<String, List<String>> categories = {
      'Artisans & BTP': [
        'Maçon','Plombier','Électricien','Soudeur','Charpentier','Couvreur',
        'Peintre en bâtiment','Mécanicien','Menuisier','Vitrier','Tôlier',
        'Carreleur','Poseur de fenêtres/portes','Ferrailleur'
      ],
      'Beauté & Bien-être': [
        'Coiffeur / Coiffeuse','Esthéticienne','Maquilleuse','Barbier',
        'Masseuse','Spa thérapeute','Onglerie / Prothésiste ongulaire'
      ],
      'Couture & Mode': [
        'Couturier / Couturière','Styliste / Modéliste','Brodeur / Brodeuse',
        'Teinturier','Designer textile'
      ],
      'Alimentation': [
        'Cuisinier','Traiteur','Boulanger','Pâtissier',
        'Vendeur de fruits/légumes','Marchand de poisson','Restaurateur'
      ],
      'Transport & Livraison': [
        'Chauffeur particulier','Taxi-moto','Taxi-brousse','Livreur','Transporteur'
      ],
      'Services domestiques': [
        'Femme de ménage','Nounou','Agent d’entretien','Gardiennage','Blanchisserie'
      ],
      'Services professionnels': [
        'Secrétaire','Traducteur','Comptable','Consultant','Notaire'
      ],
      'Éducation & formation': [
        'Enseignant','Tuteur','Formateur','Professeur particulier','Coach scolaire'
      ],
      'Santé & Bien-être': [
        'Infirmier','Docteur','Kinésithérapeute','Psychologue','Pharmacien',
        'Médecine traditionnelle'
      ],
      'Technologies & Digital': [
        'Développeur / Développeuse','Ingénieur logiciel','Data Scientist',
        'Développeur mobile','Designer UI/UX','Administrateur systèmes',
        'Chef de projet IT','Technicien réseau','Analyste sécurité',
        'Community Manager','Growth Hacker','Webmaster','DevOps Engineer'
      ],
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
      setState(() {
        _prestations.removeWhere((e) => e['id'].toString() == id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Prestation supprimée avec succès !")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la suppression : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mes prestations',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: prestatairePrimary,
        elevation: 1,
        iconTheme: const IconThemeData(color: prestatairePrimary),
      ),
      body: _prestations.isEmpty
          ? Center(
              child: Text(
                "Aucune prestation enregistrée.",
                style: TextStyle(color: Colors.grey[700], fontSize: 17),
              ),
            )
          : ListView.builder(
              itemCount: _prestations.length,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemBuilder: (context, index) {
                final p = _prestations[index];
                final id = p['id']?.toString() ?? '';
                final metier = (p['metier'] ?? p['job'] ?? '').toString();
                final ville = (p['ville'] ?? p['city'] ?? '').toString();
                final cat = (p['category'] ?? _categoryForJob(metier)).toString();
                final photo = (p['photo_url'] ?? p['image'])?.toString();

                return Card(
                  color: prestataireSecondary.withOpacity(0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: prestatairePrimary.withOpacity(0.10),
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: (photo != null && photo.isNotEmpty)
                        ? CircleAvatar(backgroundImage: NetworkImage(photo))
                        : CircleAvatar(
                            backgroundColor:
                                prestatairePrimary.withOpacity(0.12),
                            child: const Icon(Icons.person,
                                color: prestatairePrimary),
                          ),
                    title: Text(
                      metier,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: prestatairePrimary,
                      ),
                    ),
                    subtitle: Text(
                      [if (ville.isNotEmpty) ville, if (cat.isNotEmpty) cat]
                          .join(' · '),
                      style: const TextStyle(color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Modifier',
                          icon: const Icon(Icons.edit,
                              color: prestataireAccent),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.editPrestataire,
                              arguments: p,
                            ).then((res) {
                              if (res == true && mounted) setState(() {});
                            });
                          },
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Confirmation"),
                                content: const Text(
                                    "Voulez-vous supprimer cette prestation ? Cette action est irréversible."),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("Annuler"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text("Supprimer",
                                        style: TextStyle(color: Colors.red)),
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
