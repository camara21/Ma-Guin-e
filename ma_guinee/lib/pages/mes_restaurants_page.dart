import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';

class MesRestaurantsPage extends StatefulWidget {
  final List<Map<String, dynamic>> restaurants;

  const MesRestaurantsPage({super.key, required this.restaurants});

  @override
  State<MesRestaurantsPage> createState() => _MesRestaurantsPageState();
}

class _MesRestaurantsPageState extends State<MesRestaurantsPage> {
  late List<Map<String, dynamic>> mesRestaurants;

  @override
  void initState() {
    super.initState();
    mesRestaurants = List.from(widget.restaurants); // Copie locale
  }

  Future<void> supprimerRestaurant(Map<String, dynamic> resto) async {
    final supabase = Supabase.instance.client;
    final id = resto['id'];
    final images = List<String>.from(resto['images'] ?? []);

    try {
      // 🧹 Supprimer les images du Storage
      for (var url in images) {
        final path = url.split('/object/public/').last;
        await supabase.storage.from('restaurant-photos').remove([path]);
      }

      // ❌ Supprimer le restaurant
      await supabase.from('restaurants').delete().eq('id', id);

      // 🔄 Rafraîchir la liste
      if (mounted) {
        setState(() {
          mesRestaurants.removeWhere((r) => r['id'] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant supprimé')),
        );
      }
    } catch (e) {
      debugPrint('Erreur suppression: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la suppression")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Restaurants'),
        backgroundColor: Colors.deepOrange,
      ),
      body: mesRestaurants.isEmpty
          ? const Center(child: Text("Aucun restaurant enregistré."))
          : ListView.builder(
              itemCount: mesRestaurants.length,
              itemBuilder: (context, index) {
                final resto = mesRestaurants[index];
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
                              await supprimerRestaurant(resto);
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
