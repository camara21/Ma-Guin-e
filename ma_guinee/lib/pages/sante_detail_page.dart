import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SanteDetailPage extends StatefulWidget {
  final int cliniqueId;
  const SanteDetailPage({super.key, required this.cliniqueId});

  @override
  State<SanteDetailPage> createState() => _SanteDetailPageState();
}

class _SanteDetailPageState extends State<SanteDetailPage> {
  Map<String, dynamic>? clinique;
  bool loading = true;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _loadClinique();
  }

  Future<void> _loadClinique() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client
        .from('cliniques')
        .select()
        .eq('id', widget.cliniqueId)
        .maybeSingle();
    setState(() {
      clinique = data;
      loading = false;
    });
  }

  void _contacterCentre(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _ouvrirCarte(BuildContext context) {
    final lat = clinique?['latitude'];
    final lng = clinique?['longitude'];
    if (lat != null && lng != null) {
      final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
      launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coordonnées non disponibles")),
      );
    }
  }

  void _prendreRendezVous(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Prise de rendez-vous'),
        content: const Text("La fonctionnalité de prise de rendez-vous sera bientôt disponible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (clinique == null) {
      return const Scaffold(
        body: Center(child: Text("Centre de santé introuvable.")),
      );
    }

    final String nom = clinique?['nom'] ?? 'Centre médical';
    final String ville = clinique?['ville'] ?? 'Ville inconnue';
    final String specialites = clinique?['specialites'] ?? clinique?['description'] ?? 'Spécialité non renseignée';
    final List<String> images = (clinique?['images'] as List?)?.cast<String>() ?? [];
    final String horaires = clinique?['horaires'] ??
        "Lundi - Vendredi : 8h à 18h\nSamedi : 8h à 13h\nDimanche : Fermé";
    final String tel = clinique?['tel'] ?? '';

    // Responsive : large pour web, normal pour mobile
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          nom,
          style: const TextStyle(
            color: Color(0xFF009460),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF009460)),
        elevation: 1,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📸 Carrousel images
                if (images.isNotEmpty)
                  Column(
                    children: [
                      SizedBox(
                        height: isWeb ? 290 : 200,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            PageView.builder(
                              itemCount: images.length,
                              controller: PageController(initialPage: _currentImage),
                              onPageChanged: (v) => setState(() => _currentImage = v),
                              itemBuilder: (context, idx) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    images[idx],
                                    height: isWeb ? 290 : 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: isWeb ? 290 : 200,
                                      color: Colors.grey.shade200,
                                      child: const Center(child: Icon(Icons.image_not_supported)),
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
                                  children: List.generate(images.length, (i) {
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: _currentImage == i ? 15 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: _currentImage == i ? Colors.teal : Colors.white,
                                        border: Border.all(color: Colors.black12),
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
                          padding: const EdgeInsets.only(top: 10),
                          child: SizedBox(
                            height: isWeb ? 60 : 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, idx) => GestureDetector(
                                onTap: () => setState(() => _currentImage = idx),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: isWeb ? 80 : 65,
                                    height: isWeb ? 60 : 44,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _currentImage == idx ? Colors.teal : Colors.grey.shade300,
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
                  ),
                if (images.isEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.local_hospital, size: 70, color: Colors.grey)),
                    ),
                  ),
                const SizedBox(height: 22),

                Text(
                  nom,
                  style: TextStyle(
                    fontSize: isWeb ? 30 : 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF113CFC),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_city, color: Color(0xFFCE1126)),
                    const SizedBox(width: 8),
                    Text(ville, style: const TextStyle(fontSize: 17, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Spécialités :",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  specialites,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),

                const SizedBox(height: 18),
                const Text(
                  "Horaires d’ouverture :",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(horaires, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 28),
                Row(
                  children: [
                    if (tel.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.call),
                          label: const Text("Contacter"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009460),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _contacterCentre(tel),
                        ),
                      ),
                    if (tel.isNotEmpty) const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: const Text("Rendez-vous"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCE1126),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _prendreRendezVous(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () => _ouvrirCarte(context),
                  icon: const Icon(Icons.map),
                  label: const Text("Localiser sur la carte"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCD116),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
