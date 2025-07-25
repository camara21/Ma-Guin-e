import 'package:flutter/material.dart';
import '../routes.dart';

class MesPrestationsPage extends StatelessWidget {
  final List<Map<String, dynamic>> prestations;

  const MesPrestationsPage({super.key, required this.prestations});

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
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    leading: p['photo_url'] != null
                        ? CircleAvatar(backgroundImage: NetworkImage(p['photo_url']))
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(p['metier'] ?? "Sans titre"),
                    subtitle: Text(p['ville'] ?? "Sans ville"),
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

                            if (confirm == true) {
                              // TODO: Supprimer dans Supabase
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Suppression à implémenter"),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      // ⚠️ Redirige vers détail uniquement si implémenté dans routes.dart
                      // Sinon tu peux le remplacer par une page vide ou désactiver ce bouton
                      Navigator.pushNamed(
                        context,
                        AppRoutes.editPrestataire, // ou detailPrestation si défini
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
