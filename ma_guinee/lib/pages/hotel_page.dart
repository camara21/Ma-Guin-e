import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hotel_detail_page.dart';

class HotelPage extends StatefulWidget {
  const HotelPage({super.key});

  @override
  State<HotelPage> createState() => _HotelPageState();
}

class _HotelPageState extends State<HotelPage> {
  List<Map<String, dynamic>> hotels = [];
  List<Map<String, dynamic>> filteredHotels = [];
  bool loading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client.from('hotels').select().order('nom');
    setState(() {
      hotels = List<Map<String, dynamic>>.from(data);
      filteredHotels = hotels;
      loading = false;
    });
  }

  void _filterHotels(String value) {
    final q = value.toLowerCase();
    setState(() {
      searchQuery = value;
      filteredHotels = hotels.where((hotel) {
        final nom = (hotel['nom'] ?? '').toLowerCase();
        final ville = (hotel['ville'] ?? '').toLowerCase();
        return nom.contains(q) || ville.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF113CFC),
        title: const Text(
          'Hôtels',
          style: TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : hotels.isEmpty
              ? const Center(child: Text("Aucun hôtel trouvé."))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      // Banner
                      Container(
                        width: double.infinity,
                        height: 75,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF113CFC), Color(0xFF2EC4F1)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Trouvez l'hôtel parfait partout en Guinée",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Barre de recherche
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un hôtel, une ville...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF113CFC)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: const Color(0xFFF8F6F9),
                        ),
                        onChanged: _filterHotels,
                      ),
                      const SizedBox(height: 12),
                      // Affichage grille d’hôtels
                      Expanded(
                        child: filteredHotels.isEmpty
                            ? const Center(child: Text("Aucun hôtel trouvé."))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.77,
                                ),
                                itemCount: filteredHotels.length,
                                itemBuilder: (context, index) {
                                  final hotel = filteredHotels[index];
                                  final images = (hotel['images'] as List?)?.cast<String>() ?? [];
                                  final image = images.isNotEmpty
                                      ? images[0]
                                      : 'https://via.placeholder.com/300x200.png?text=H%C3%B4tel';

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => HotelDetailPage(hotelId: hotel['id']),
                                        ),
                                      );
                                    },
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Image principale de l'hôtel
                                          AspectRatio(
                                            aspectRatio: 16 / 11,
                                            child: Image.network(
                                              image,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.hotel, size: 40, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hotel['nom'] ?? "Sans nom",
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  hotel['ville'] ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if (hotel['prix'] != null && hotel['prix'].toString().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2.5),
                                                    child: Text(
                                                      '${hotel['prix']} ${hotel['devise'] ?? 'GNF'}',
                                                      style: const TextStyle(
                                                        color: Color(0xFF113CFC),
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
