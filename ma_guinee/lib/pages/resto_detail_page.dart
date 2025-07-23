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
    final List<String> images = (resto?['images'] as List?)?.cast<String>() ?? [];
    final bool hasTel = (resto?['tel'] != null && resto?['tel'].isNotEmpty);
    final bool hasWhatsApp = (resto?['whatsapp'] != null && resto?['whatsapp'].isNotEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(nom, style: const TextStyle(color: Color(0xFF113CFC), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carrousel d'images
            if (images.isNotEmpty)
              Column(
                children: [
                  SizedBox(
                    height: 200,
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
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                images[idx],
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 200,
                                  color: Colors.grey.shade300,
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
                                return Container(
                                  width: _currentImage == index ? 15 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: _currentImage == index ? Colors.orange : Colors.white,
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
                      padding: const EdgeInsets.only(top: 10, bottom: 8),
                      child: SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, idx) => GestureDetector(
                            onTap: () {
                              setState(() => _currentImage = idx);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 60,
                                height: 42,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: _currentImage == idx ? Colors.orange : Colors.grey.shade300, width: 2),
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
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.restaurant, size: 70, color: Colors.grey)),
                ),
              ),
            const SizedBox(height: 18),

            Text(nom, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(resto?['cuisine'] ?? '', style: const TextStyle(fontSize: 16, color: Color(0xFF009460))),
            const SizedBox(height: 15),
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFCE1126)),
                const SizedBox(width: 8),
                Text(ville, style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 22),
            const Text("Notez ce restaurant :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildStars(_noteUtilisateur, onTap: (note) {
              setState(() => _noteUtilisateur = note);
            }),
            const SizedBox(height: 8),
            const Text("Laissez un avis :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 25),
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
                      ),
                    ),
                  ),
                if (hasWhatsApp) const SizedBox(width: 10),
                if (hasWhatsApp)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _ouvrirWhatsApp(context),
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                      label: const Text("WhatsApp"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
