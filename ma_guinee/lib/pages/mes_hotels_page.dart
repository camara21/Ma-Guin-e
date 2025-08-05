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
    _hotels = List<Map<String, dynamic>>.from(widget.hotels);
  }

  Future<void> _supprimerHotel(Map<String, dynamic> hotel) async {
    final supabase = Supabase.instance.client;
    final id = hotel['id'];
    final List<String> images = hotel['images'] is List ? List<String>.from(hotel['images']) : [];

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
        const SnackBar(content: Text("Hôtel supprimé avec succès !")),
      );
    } catch (e) {
      debugPrint("Erreur suppression hôtel: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la suppression : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleuMaGuinee = const Color(0xFF113CFC);
    final jauneMaGuinee = const Color(0xFFFCD116);
    final vertMaGuinee = const Color(0xFF009460);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mes hôtels", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: bleuMaGuinee,
        elevation: 1,
        iconTheme: IconThemeData(color: bleuMaGuinee),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: bleuMaGuinee,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.inscriptionHotel)
              .then((_) => setState(() {}));
        },
        icon: const Icon(Icons.add),
        label: const Text("Ajouter"),
      ),
      body: _hotels.isEmpty
          ? Center(
              child: Text(
                "Aucun hôtel trouvé.",
                style: TextStyle(color: Colors.grey[700], fontSize: 17),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _hotels.length,
              itemBuilder: (context, index) {
                final hotel = _hotels[index];
                final List<String> images = hotel['images'] is List ? List<String>.from(hotel['images']) : [];
                final image = images.isNotEmpty
                    ? images.first
                    : 'https://via.placeholder.com/150';

                return Card(
                  color: jauneMaGuinee.withOpacity(0.07),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(image),
                      radius: 27,
                      backgroundColor: jauneMaGuinee,
                    ),
                    title: Text(
                      hotel['nom'] ?? "Sans nom",
                      style: TextStyle(fontWeight: FontWeight.bold, color: bleuMaGuinee),
                    ),
                    subtitle: Text(
                      '${hotel['adresse'] ?? "Adresse"} • ${hotel['ville'] ?? "Ville"}',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'modifier') {
                          await Navigator.pushNamed(
                            context,
                            AppRoutes.inscriptionHotel,
                            arguments: hotel,
                          );
                          setState(() {});
                        } else if (value == 'supprimer') {
                          final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Confirmation"),
                                  content: const Text(
                                      "Voulez-vous vraiment supprimer cet hôtel ?\nCette action est irréversible."),
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
                              ) ??
                              false;

                          if (confirm) {
                            await _supprimerHotel(hotel);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'modifier',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: bleuMaGuinee),
                              const SizedBox(width: 8),
                              const Text("Modifier"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'supprimer',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text("Supprimer"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HotelDetailPage(hotelId: hotel['id']),
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
