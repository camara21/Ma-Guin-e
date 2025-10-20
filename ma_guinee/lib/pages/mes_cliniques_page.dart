import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_guinee/pages/edit_clinique_page.dart';
import 'package:ma_guinee/pages/sante_detail_page.dart';

class MesCliniquesPage extends StatefulWidget {
  const MesCliniquesPage({super.key, required this.cliniques});
  final List<Map<String, dynamic>> cliniques;

  @override
  State<MesCliniquesPage> createState() => _MesCliniquesPageState();
}

class _MesCliniquesPageState extends State<MesCliniquesPage> {
  // Palette Santé
  static const Color kHealthGreen = Color(0xFF009460);
  static const Color kHealthYellow = Color(0xFFFCD116);

  List<Map<String, dynamic>> cliniques = [];

  @override
  void initState() {
    super.initState();
    cliniques = List<Map<String, dynamic>>.from(widget.cliniques);
  }

  Future<void> supprimerClinique(int id) async {
    try {
      await Supabase.instance.client.from('cliniques').delete().match({'id': id});
      setState(() => cliniques.removeWhere((e) => e['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Clinique supprimée avec succès !")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la suppression : $e")),
      );
    }
  }

  Future<void> _editClinique(Map<String, dynamic> clinique) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditCliniquePage(
          clinique: clinique,
          autoAskLocation: false, // édition: pas d’auto-demande
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        final idx = cliniques.indexWhere((c) => c['id'] == result['id']);
        if (idx != -1) cliniques[idx] = result;
      });
    }
  }

  void _mesRendezVousPasActif() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mes rendez-vous : fonctionnalité bientôt disponible.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Mes Cliniques',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kHealthGreen,
        elevation: 1,
        iconTheme: const IconThemeData(color: kHealthGreen),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _mesRendezVousPasActif, // non actif pour l’instant
              icon: const Icon(Icons.event_note, size: 18, color: kHealthGreen),
              label: const Text(
                "Mes rendez-vous",
                style: TextStyle(color: kHealthGreen, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: kHealthGreen,
              ),
            ),
          ),
        ],
      ),
      body: cliniques.isEmpty
          ? Center(
              child: Text(
                "Aucune clinique enregistrée.",
                style: TextStyle(color: Colors.grey[700], fontSize: 17),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
              itemCount: cliniques.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE0E0E0)),
              itemBuilder: (context, index) {
                final clinique = cliniques[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: kHealthYellow, // JAUNE santé
                      child: const Icon(Icons.local_hospital, color: kHealthGreen, size: 27),
                    ),
                    title: Text(
                      clinique['nom'] ?? '',
                      style: const TextStyle(
                        color: kHealthGreen, // VERT santé
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      clinique['ville'] ?? '',
                      style: TextStyle(color: Colors.grey[800], fontSize: 15),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SanteDetailPage(cliniqueId: clinique['id']),
                        ),
                      );
                    },
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: "Modifier",
                          icon: const Icon(Icons.edit, color: kHealthGreen),
                          onPressed: () => _editClinique(clinique),
                        ),
                        IconButton(
                          tooltip: "Supprimer",
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Suppression"),
                                content: const Text(
                                  "Voulez-vous vraiment supprimer cette clinique ?\nCette action est irréversible.",
                                  style: TextStyle(fontSize: 16),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Annuler"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              supprimerClinique(clinique['id']);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kHealthGreen, // VERT santé
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EditCliniquePage(
                autoAskLocation: true, // création: demande auto de localisation
              ),
            ),
          );
          if (result != null && result is Map<String, dynamic>) {
            setState(() => cliniques.add(result));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text("Nouvelle clinique"),
      ),
    );
  }
}
