import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HotelDetailPage extends StatefulWidget {
  final int hotelId;
  const HotelDetailPage({super.key, required this.hotelId});

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  Map<String, dynamic>? hotel;
  bool loading = true;
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  int _currentImage = 0;
  List<Map<String, dynamic>> _hotelsSimilaires = [];
  bool loadingSimilaires = false;

  @override
  void initState() {
    super.initState();
    _loadHotel();
  }

  Future<void> _loadHotel() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client
        .from('hotels')
        .select()
        .eq('id', widget.hotelId)
        .maybeSingle();
    setState(() {
      hotel = data;
      loading = false;
    });
    if (data != null) _loadHotelsSimilaires(data);
  }

  Future<void> _loadHotelsSimilaires(Map<String, dynamic> hotelData) async {
    setState(() => loadingSimilaires = true);
    final ville = hotelData['ville'] ?? '';
    final res = await Supabase.instance.client
        .from('hotels')
        .select()
        .eq('ville', ville)
        .neq('id', hotelData['id'])
        .limit(6);

    setState(() {
      _hotelsSimilaires = List<Map<String, dynamic>>.from(res);
      loadingSimilaires = false;
    });
  }

  void _appelerHotel(BuildContext context) async {
    final numero = hotel?['telephone'] ?? '';
    if (numero.isNotEmpty) {
      final uri = Uri.parse('tel:$numero');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'appeler $numero")),
        );
      }
    }
  }

  void _ouvrirCarte(BuildContext context) {
    final latitude = hotel?['latitude'];
    final longitude = hotel?['longitude'];
    if (latitude != null && longitude != null) {
      final uri = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude");
      launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coordonnées GPS non disponibles")),
      );
    }
  }

  Future<void> _envoyerAvis() async {
    final avis = _avisController.text.trim();
    final note = _noteUtilisateur;
    if (note == 0 || avis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez noter et écrire un avis.")),
      );
      return;
    }

    await Supabase.instance.client.from('hotel_avis').insert({
      'hotel_id': widget.hotelId,
      'note': note,
      'avis': avis,
      'created_at': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Merci pour votre avis !")),
    );
    setState(() {
      _noteUtilisateur = 0;
      _avisController.clear();
    });
  }

  Widget _buildStars(int rating, {void Function(int)? onTap}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: onTap != null ? () => onTap(index + 1) : null,
          iconSize: 28,
          splashRadius: 20,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 650;

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (hotel == null) {
      return const Scaffold(
        body: Center(child: Text("Hôtel non trouvé")),
      );
    }

    final String nom = hotel?['nom'] ?? 'Nom inconnu';
    final String adresse = hotel?['adresse'] ?? 'Adresse inconnue';
    final String ville = hotel?['ville'] ?? '';
    final String description = hotel?['description'] ?? '';
    final List<String> images = (hotel?['images'] as List?)?.cast<String>() ?? [];
    final int etoiles = hotel?['etoiles'] ?? 0;
    final String prix = hotel?['prix'] ?? 'Non renseigné';
    final String avis = hotel?['avis'] ?? "Pas d'avis";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(nom,
            style: const TextStyle(
                color: Color(0xFF113CFC), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (images.isNotEmpty)
                  Column(
                    children: [
                      SizedBox(
                        height: isWeb ? 320 : 220,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            PageView.builder(
                              itemCount: images.length,
                              onPageChanged: (value) {
                                setState(() => _currentImage = value);
                              },
                              itemBuilder: (context, idx) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    images[idx],
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 220,
                                      color: Colors.grey.shade300,
                                      child: const Center(
                                          child: Icon(Icons.image_not_supported)),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (images.length > 1)
                              Positioned(
                                bottom: 10,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(images.length, (index) {
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: _currentImage == index ? 18 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: _currentImage == index
                                            ? const Color(0xFFFCD116)
                                            : Colors.grey.shade400,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (images.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 8),
                          child: SizedBox(
                            height: 48,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, idx) => GestureDetector(
                                onTap: () => setState(() => _currentImage = idx),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 65,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _currentImage == idx ? const Color(0xFFFCD116) : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Image.network(
                                      images[idx],
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Container(
                    height: isWeb ? 320 : 220,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                        child: Icon(Icons.hotel, size: 70, color: Colors.grey)),
                  ),
                const SizedBox(height: 22),

                Text(nom,
                    style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF113CFC))),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Color(0xFFCE1126)),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Text(adresse,
                            style: const TextStyle(fontSize: 15))),
                  ],
                ),
                const SizedBox(height: 10),
                if (etoiles > 0)
                  Row(
                    children: List.generate(
                      etoiles,
                      (i) => const Icon(Icons.star,
                          color: Colors.amber, size: 20),
                    ),
                  ),
                const SizedBox(height: 20),

                const Text("Prix moyen :",
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(prix,
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF009460))),
                const SizedBox(height: 16),

                if (ville.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.location_city,
                          size: 20, color: Colors.black54),
                      const SizedBox(width: 8),
                      Text(ville, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],

                if (description.isNotEmpty) ...[
                  const Text("Description :",
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(description,
                      style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 22),
                ],

                const Text("Avis client :",
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(avis,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 22),

                const Text("Notez cet hôtel :",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 9),
                _buildStars(_noteUtilisateur, onTap: (rating) {
                  setState(() => _noteUtilisateur = rating);
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: _avisController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Partagez votre expérience avec cet hôtel...",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 9),
                ElevatedButton.icon(
                  onPressed: _envoyerAvis,
                  icon: const Icon(Icons.send),
                  label: const Text("Envoyer mon avis"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCD116),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () => _ouvrirCarte(context),
                  icon: const Icon(Icons.map),
                  label: const Text("Localiser sur la carte"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.phone, color: Colors.white),
                        label: const Text("Contacter"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009460),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _appelerHotel(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: const Text("Réserver"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCE1126),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Réservation'),
                              content: const Text('La fonction de réservation sera bientôt disponible.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 35),

                // Section hôtels similaires
                if (loadingSimilaires)
                  const Center(child: CircularProgressIndicator())
                else if (_hotelsSimilaires.isNotEmpty) ...[
                  const Text("Hôtels similaires dans la ville",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.85,
                    ),
                    itemCount: _hotelsSimilaires.length,
                    itemBuilder: (context, i) {
                      final h = _hotelsSimilaires[i];
                      final imgs = (h['images'] as List?)?.cast<String>() ?? [];
                      final img = imgs.isNotEmpty ? imgs[0] : '';
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HotelDetailPage(hotelId: h['id']),
                            ),
                          );
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                child: img.isNotEmpty
                                    ? Image.network(img, height: 84, width: double.infinity, fit: BoxFit.cover)
                                    : Container(
                                        height: 84,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.hotel, size: 30, color: Colors.grey),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h['nom'] ?? "",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      h['adresse'] ?? "",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.black54, fontSize: 12),
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
