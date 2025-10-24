// lib/pages/mes_restaurants_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';

// ✅ bon import (corrigé)
import 'pro_reservations_restaurants.dart';

class MesRestaurantsPage extends StatefulWidget {
  final List<Map<String, dynamic>> restaurants;

  const MesRestaurantsPage({super.key, required this.restaurants});

  @override
  State<MesRestaurantsPage> createState() => _MesRestaurantsPageState();
}

class _MesRestaurantsPageState extends State<MesRestaurantsPage> {
  // ==== Palette Restaurant (locale, pas de ServiceColors global) ====
  static const Color restoPrimary   = Color(0xFFE76F51);
  static const Color restoSecondary = Color(0xFFF4A261);
  static const Color onPrimary      = Colors.white;

  late List<Map<String, dynamic>> mesRestaurants;

  @override
  void initState() {
    super.initState();
    mesRestaurants = List<Map<String, dynamic>>.from(widget.restaurants);
  }

  Future<void> supprimerRestaurant(Map<String, dynamic> resto) async {
    final supabase = Supabase.instance.client;
    final String id = resto['id'];
    final List<String> images =
        resto['images'] is List ? List<String>.from(resto['images']) : [];

    try {
      // Supprimer les images du Storage
      for (var url in images) {
        final path = url.split('/object/public/').last;
        await supabase.storage.from('restaurant-photos').remove([path]);
      }

      // Supprimer le restaurant
      await supabase.from('restaurants').delete().eq('id', id);

      // Mise à jour locale
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

  void _openProReservations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProReservationsRestaurantsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text(
          'Mes Restaurants',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: restoPrimary,
        elevation: 1,
        iconTheme: const IconThemeData(color: restoPrimary),

        // ✅ Bouton "Mes réservations" (ouvre la gestion PRO)
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: _openProReservations,
              icon: const Icon(Icons.calendar_month),
              label: const Text("Mes réservations"),
              style: OutlinedButton.styleFrom(
                foregroundColor: restoPrimary,
                side: BorderSide(color: restoPrimary.withOpacity(.25)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: restoPrimary,
        foregroundColor: onPrimary,
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
                final List<String> images =
                    resto['images'] is List ? List<String>.from(resto['images']) : [];
                final String? image = images.isNotEmpty ? images.first : null;

                return Card(
                  color: restoSecondary.withOpacity(0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: restoSecondary.withOpacity(0.25),
                      backgroundImage: image != null ? NetworkImage(image) : null,
                      child: image == null
                          ? const Icon(Icons.restaurant, color: restoPrimary)
                          : null,
                    ),
                    title: Text(
                      resto['nom'] ?? 'Nom inconnu',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: restoPrimary,
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
                          icon: const Icon(Icons.edit, color: restoSecondary),
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
                                      'Voulez-vous vraiment supprimer ce restaurant ?',
                                    ),
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