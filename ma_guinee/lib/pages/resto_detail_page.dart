import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class RestoDetailPage extends StatefulWidget {
  final int restoId;
  const RestoDetailPage({super.key, required this.restoId});

  @override
  State<RestoDetailPage> createState() => _RestoDetailPageState();
}

class _RestoDetailPageState extends State<RestoDetailPage> {
  Map<String, dynamic>? resto;
  bool loading = true;
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  int _currentImage = 0;

  List<Map<String, dynamic>> _restosSimilaires = [];
  bool loadingSimilaires = false;

  @override
  void initState() {
    super.initState();
    _loadResto();
  }

  Future<void> _loadResto() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client
        .from('restaurants')
        .select()
        .eq('id', widget.restoId)
        .maybeSingle();
    setState(() {
      resto = data;
      loading = false;
    });
    if (data != null) _loadRestosSimilaires(data);
  }

  Future<void> _loadRestosSimilaires(Map<String, dynamic> restoData) async {
    setState(() => loadingSimilaires = true);
    final ville = restoData['ville'] ?? '';
    final res = await Supabase.instance.client
        .from('restaurants')
        .select()
        .eq('ville', ville)
        .neq('id', restoData['id'])
        .limit(6);

    setState(() {
      _restosSimilaires = List<Map<String, dynamic>>.from(res);
      loadingSimilaires = false;
    });
  }

  void _appeler(BuildContext context) async {
    final numero = resto?['tel'] ?? "";
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

  void _ouvrirWhatsApp(BuildContext context) async {
    final numero = resto?['whatsapp'] ?? "";
    if (numero.isNotEmpty) {
      final whats = numero.replaceAll(RegExp(r'\D'), '');
      final url = Uri.parse('https://wa.me/$whats');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
        );
      }
    }
  }

  Widget _buildStars(int rating, {void Function(int)? onTap}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber[700],
          ),
          onPressed: onTap != null ? () => onTap(index + 1) : null,
          iconSize: 30,
          splashRadius: 20,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 650;
    final primaryColor = const Color(0xFF113CFC);

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (resto == null) {
      return const Scaffold(
        body: Center(child: Text("Restaurant non trouvé")),
      );
    }

    final String nom = resto?['nom'] ?? 'Nom inconnu';
    final String ville = resto?['ville'] ?? 'Ville inconnue';
    final String cuisine = resto?['cuisine'] ?? '';
    final List<String> images = (resto?['images'] as List?)?.cast<String>() ?? [];
    final bool hasTel = (resto?['tel'] != null && resto?['tel'].isNotEmpty);
    final bool hasWhatsApp = (resto?['whatsapp'] != null && resto?['whatsapp'].isNotEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(nom, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: isWeb ? 26 : 20)),
        backgroundColor: Colors.white,
        elevation: 0.8,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carrousel d'images
                if (images.isNotEmpty)
                  Column(
                    children: [
                      SizedBox(
                        height: isWeb ? 340 : 210,
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
                                      height: 200,
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
                          padding: const EdgeInsets.only(top: 8, bottom: 6),
                          child: SizedBox(
                            height: 45,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, idx) => GestureDetector(
                                onTap: () => setState(() => _currentImage = idx),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 60,
                                    height: 45,
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
                  ),
                if (images.isEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 210,
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.restaurant, size: 70, color: Colors.grey)),
                    ),
                  ),
                const SizedBox(height: 20),

                Text(
                  nom,
                  style: TextStyle(fontSize: isWeb ? 30 : 24, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 8),
                Text(
                  cuisine,
                  style: const TextStyle(fontSize: 17, color: Color(0xFF009460)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFFCE1126)),
                    const SizedBox(width: 8),
                    Text(ville, style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 25),

                // --- Section note et avis
                Text("Notez ce restaurant :", style: TextStyle(fontSize: isWeb ? 19 : 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildStars(_noteUtilisateur, onTap: (note) {
                  setState(() => _noteUtilisateur = note);
                }),
                const SizedBox(height: 10),
                Text("Laissez un avis :", style: TextStyle(fontSize: isWeb ? 19 : 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _avisController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Partagez votre expérience...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    // 🔜 Envoyer à Supabase ici (table resto_avis à créer)
                    _avisController.clear();
                    setState(() => _noteUtilisateur = 0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Merci pour votre avis !")),
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text("Envoyer mon avis"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCD116),
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 30),

                // --- Boutons contact
                Row(
                  children: [
                    if (hasTel)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _appeler(context),
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text("Contacter"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCE1126),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    if (hasWhatsApp) const SizedBox(width: 14),
                    if (hasWhatsApp)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _ouvrirWhatsApp(context),
                          icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                          label: const Text("WhatsApp"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 35),

                // Section restaurants similaires
                if (loadingSimilaires)
                  const Center(child: CircularProgressIndicator())
                else if (_restosSimilaires.isNotEmpty) ...[
                  const Text("Restaurants similaires dans la ville",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.85,
                    ),
                    itemCount: _restosSimilaires.length,
                    itemBuilder: (context, i) {
                      final r = _restosSimilaires[i];
                      final imgs = (r['images'] as List?)?.cast<String>() ?? [];
                      final img = imgs.isNotEmpty ? imgs[0] : '';
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RestoDetailPage(restoId: r['id']),
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
                                        child: const Icon(Icons.restaurant, size: 30, color: Colors.grey),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['nom'] ?? "",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r['cuisine'] ?? "",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      r['ville'] ?? "",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
