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
    mesRestaurants = List.from(widget.restaurants);
  }

  Future<void> supprimerRestaurant(Map<String, dynamic> resto) async {
    final supabase = Supabase.instance.client;
    final String id = resto['id'];
    final images = List<String>.from(resto['images'] ?? []);

    try {
      // 🗑 Supprimer les images du Storage
      for (var url in images) {
        final path = url.split('/object/public/').last;
        await supabase.storage.from('restaurant-photos').remove([path]);
      }

      // ❌ Supprimer le restaurant
      await supabase.from('restaurants').delete().eq('id', id);

      // 🔄 Mise à jour de la liste locale
      if (mounted) {
        setState(() {
          mesRestaurants.removeWhere((r) => r['id'] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant supprimé avec succès !')),
        );
      }
    } catch (e) {
      debugPrint('Erreur suppression: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la suppression : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleuMaGuinee = const Color(0xFF113CFC);
    final jauneMaGuinee = const Color(0xFFFCD116);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Mes Restaurants',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: bleuMaGuinee,
        elevation: 1,
        iconTheme: IconThemeData(color: bleuMaGuinee),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: bleuMaGuinee,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Ajouter"),
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.inscriptionResto)
              .then((_) => setState(() {}));
        },
      ),
      body: mesRestaurants.isEmpty
          ? Center(
              child: Text(
                "Aucun restaurant enregistré.",
                style: TextStyle(color: Colors.grey[700], fontSize: 17),
              ),
            )
          : ListView.builder(
              itemCount: mesRestaurants.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final resto = mesRestaurants[index];
                final images = resto['images'] ?? [];
                final image = images.isNotEmpty ? images.first : null;

                return Card(
                  color: jauneMaGuinee.withOpacity(0.09),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: bleuMaGuinee.withOpacity(0.16),
                      backgroundImage:
                          image != null ? NetworkImage(image) : null,
                      child: image == null
                          ? Icon(Icons.restaurant, color: bleuMaGuinee)
                          : null,
                    ),
                    title: Text(
                      resto['nom'] ?? 'Nom inconnu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: bleuMaGuinee,
                      ),
                    ),
                    subtitle: Text(
                      resto['ville'] ?? 'Ville inconnue',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.restoDetail,
                        arguments: resto['id'],
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.edit, color: Color(0xFF009460)),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.inscriptionResto,
                              arguments: resto,
                            ).then((_) => setState(() {}));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmer la suppression'),
                                    content: const Text(
                                        'Voulez-vous vraiment supprimer ce restaurant ?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Annuler'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Supprimer',
                                          style: TextStyle(color: Colors.red),
                                        ),
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
