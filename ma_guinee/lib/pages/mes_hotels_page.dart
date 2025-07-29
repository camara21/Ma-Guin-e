import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';
import 'hotel_detail_page.dart';

class MesHotelsPage extends StatefulWidget {
  final List<Map<String, dynamic>> hotels;

  const MesHotelsPage({super.key, required this.hotels});

  @override
  State<MesHotelsPage> createState() => _MesHotelsPageState();
}

class _MesHotelsPageState extends State<MesHotelsPage> {
  late List<Map<String, dynamic>> _hotels;

  @override
  void initState() {
    super.initState();
    _hotels = List.from(widget.hotels);
  }

  Future<void> _supprimerHotel(Map<String, dynamic> hotel) async {
    final supabase = Supabase.instance.client;
    final id = hotel['id'];
    final List<String> images = hotel['images'] is List
        ? List<String>.from(hotel['images'])
        : [];

    try {
      // 🔥 Supprimer les images dans le bucket Supabase
      for (var url in images) {
        final path = url.split('/object/public/').last;
        await supabase.storage.from('hotel-photos').remove([path]);
      }

      // ❌ Supprimer l'hôtel de la base Supabase
      await supabase.from('hotels').delete().eq('id', id);

      // 🔁 Supprimer localement dans l'app
      setState(() {
        _hotels.removeWhere((h) => h['id'] == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hôtel supprimé")),
      );
    } catch (e) {
      debugPrint("Erreur suppression hôtel: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la suppression")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes hôtels"),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.inscriptionHotel)
              .then((_) => setState(() {}));
        },
        icon: const Icon(Icons.add),
        label: const Text("Ajouter"),
      ),
      body: _hotels.isEmpty
          ? const Center(child: Text("Aucun hôtel trouvé."))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _hotels.length,
              itemBuilder: (context, index) {
                final hotel = _hotels[index];
                final List<String> images = hotel['images'] is List
                    ? List<String>.from(hotel['images'])
                    : [];
                final image = images.isNotEmpty
                    ? images.first
                    : 'https://via.placeholder.com/150';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(image),
                      radius: 26,
                    ),
                    title: Text(
                      hotel['nom'] ?? "Sans nom",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${hotel['adresse'] ?? "Adresse"} • ${hotel['ville'] ?? "Ville"}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'modifier') {
                          await Navigator.pushNamed(
                            context,
                            AppRoutes.inscriptionHotel,
                            arguments: hotel,
                          );
                          setState(() {}); // Mise à jour après modification
                        } else if (value == 'supprimer') {
                          final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Confirmer la suppression"),
                                  content: const Text(
                                      "Voulez-vous vraiment supprimer cet hôtel ?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text("Annuler"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text("Supprimer"),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (confirm) {
                            await _supprimerHotel(hotel);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'modifier',
                          child: Text("Modifier"),
                        ),
                        const PopupMenuItem(
                          value: 'supprimer',
                          child: Text("Supprimer"),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HotelDetailPage(hotelId: hotel['id']),
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
