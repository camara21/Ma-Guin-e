import 'package:flutter/material.dart';
import '../routes.dart';

class MesRestaurantsPage extends StatelessWidget {
  final List<Map<String, dynamic>> restaurants;

  const MesRestaurantsPage({super.key, required this.restaurants});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Restaurants'),
        backgroundColor: Colors.deepOrange,
      ),
      body: restaurants.isEmpty
          ? const Center(child: Text("Aucun restaurant enregistré."))
          : ListView.builder(
              itemCount: restaurants.length,
              itemBuilder: (context, index) {
                final resto = restaurants[index];
                final List images = resto['images'] ?? [];
                final image = images.isNotEmpty ? images.first : null;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange,
                      backgroundImage: image != null ? NetworkImage(image) : null,
                      child: image == null
                          ? const Icon(Icons.restaurant, color: Colors.white)
                          : null,
                    ),
                    title: Text(resto['nom'] ?? 'Nom inconnu'),
                    subtitle: Text(resto['ville'] ?? 'Ville inconnue'),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.restoDetail,
                        arguments: resto['id'],
                      );
                    },
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.inscriptionResto,
                              arguments: resto,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmer la suppression'),
                                    content: const Text('Voulez-vous supprimer ce restaurant ?'),
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
                                ) ??
                                false;

                            if (confirmed) {
                              // 🔜 Supprimer depuis Supabase
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
                  ),
                );
              },
            ),
    );
  }
}
