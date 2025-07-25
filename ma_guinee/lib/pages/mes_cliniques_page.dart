import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../routes.dart';

class MesCliniquesPage extends StatelessWidget {
  const MesCliniquesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final utilisateur = userProvider.utilisateur;
    final cliniques = utilisateur?.cliniques ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Cliniques'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.inscriptionClinique)
                  .then((_) => userProvider.chargerUtilisateurConnecte());
            },
          )
        ],
      ),
      body: cliniques.isEmpty
          ? const Center(child: Text("Aucune clinique enregistrée."))
          : ListView.builder(
              itemCount: cliniques.length,
              itemBuilder: (context, index) {
                final clinique = cliniques[index];
                final List images = clinique['images'] ?? [];
                final image = images.isNotEmpty ? images.first : null;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal,
                      backgroundImage: image != null ? NetworkImage(image) : null,
                      child: image == null
                          ? const Icon(Icons.local_hospital, color: Colors.white)
                          : null,
                    ),
                    title: Text(clinique['nom'] ?? 'Nom inconnu'),
                    subtitle: Text(clinique['ville'] ?? 'Ville inconnue'),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.inscriptionClinique,
                        arguments: clinique,
                      ).then((_) => userProvider.chargerUtilisateurConnecte());
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirmer la suppression'),
                                content: const Text('Voulez-vous vraiment supprimer cette clinique ?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Annuler'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            ) ?? false;

                        if (confirmed) {
                          await userProvider.supprimerClinique(clinique['id']);
                          await userProvider.chargerUtilisateurConnecte();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
