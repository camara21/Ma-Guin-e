import 'package:flutter/material.dart';
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
    _hotels = widget.hotels;
  }

  Future<void> _supprimerHotel(int id) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Hôtel supprimé")),
    );
    setState(() {
      _hotels.removeWhere((h) => h['id'] == id);
    });
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
              .then((_) => setState(() {})); // à remplacer par rechargement si nécessaire
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
                      borderRadius: BorderRadius.circular(12)),
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
                      onSelected: (value) {
                        if (value == 'modifier') {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.inscriptionHotel,
                            arguments: hotel,
                          ).then((_) => setState(() {}));
                        } else if (value == 'supprimer') {
                          _supprimerHotel(hotel['id']);
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
