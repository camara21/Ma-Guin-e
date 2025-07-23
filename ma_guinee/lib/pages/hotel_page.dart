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
  bool loading = true;

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
      loading = false;
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
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: hotels.length,
                  itemBuilder: (context, index) {
                    final hotel = hotels[index];
                    final images = (hotel['images'] as List?)?.cast<String>() ?? [];
                    final image = images.isNotEmpty ? images[0] : 'https://via.placeholder.com/150';
                    return Card(
                      color: Colors.indigo.shade50.withOpacity(0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.only(bottom: 14),
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(image),
                          radius: 26,
                        ),
                        title: Text(
                          hotel['nom'] ?? "Sans nom",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          hotel['adresse'] ?? '',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        trailing: const Icon(Icons.hotel, color: Color(0xFF009460)),
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
