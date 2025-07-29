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
  List<Map<String, dynamic>> cliniques = [];

  @override
  void initState() {
    super.initState();
    cliniques = widget.cliniques;
  }

  Future<void> supprimerClinique(int id) async {
    try {
      await Supabase.instance.client
          .from('cliniques')
          .delete()
          .match({'id': id});

      setState(() {
        cliniques.removeWhere((element) => element['id'] == id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la suppression : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Cliniques'),
        backgroundColor: Colors.teal,
      ),
      body: cliniques.isEmpty
          ? const Center(child: Text("Aucune clinique enregistrée."))
          : ListView.builder(
              itemCount: cliniques.length,
              itemBuilder: (context, index) {
                final clinique = cliniques[index];
                return ListTile(
                  leading: const Icon(Icons.local_hospital, color: Colors.teal),
                  title: Text(clinique['nom'] ?? ''),
                  subtitle: Text(clinique['ville'] ?? ''),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SanteDetailPage(cliniqueId: clinique['id']),
                      ),
                    );
                  },
                  trailing: Wrap(
                    spacing: 12,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditCliniquePage(clinique: clinique),
                            ),
                          ).then((_) => setState(() {})); // rechargement manuel si besoin
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Confirmation"),
                              content: const Text("Supprimer cette clinique ?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("Annuler"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("Supprimer"),
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
                );
              },
            ),
    );
  }
}
