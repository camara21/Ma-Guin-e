import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DivertissementDetailPage extends StatefulWidget {
  final Map<String, dynamic> lieu;

  const DivertissementDetailPage({super.key, required this.lieu});

  @override
  State<DivertissementDetailPage> createState() => _DivertissementDetailPageState();
}

class _DivertissementDetailPageState extends State<DivertissementDetailPage> {
  int _note = 0;
  final TextEditingController _avisController = TextEditingController();
  int _currentImage = 0;

  void _callPhone(BuildContext context) async {
    final phone = widget.lieu['telephone'];
    if (phone != null && await canLaunchUrl(Uri.parse('tel:$phone'))) {
      await launchUrl(Uri.parse('tel:$phone'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro non disponible ou invalide")),
      );
    }
  }

  void _openMap(BuildContext context) {
    final lat = widget.lieu['latitude'];
    final lon = widget.lieu['longitude'];
    if (lat != null && lon != null) {
      launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon"));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coordonnées GPS non disponibles")),
      );
    }
  }

  void _envoyerAvis() {
    final avis = _avisController.text.trim();
    if (_note == 0 || avis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci de noter et écrire un avis.")),
      );
      return;
    }

    debugPrint("⭐ Note : $_note");
    debugPrint("💬 Avis : $avis");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Merci pour votre avis !")),
    );

    setState(() {
      _note = 0;
      _avisController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lieu = widget.lieu;
    final horaires = lieu['horaires'] ?? "Non renseigné";

    final List<String> images = (lieu['images'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          lieu['nom'],
          style: const TextStyle(color: Color(0xFF113CFC), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carrousel d'images multi-photos
            if (images.isNotEmpty)
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (index) => setState(() => _currentImage = index),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.network(
                            images[index],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
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
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Center(child: Icon(Icons.image_not_supported, size: 60)),
                ),
              ),

            const SizedBox(height: 20),

            Text(
              lieu['nom'],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            if (lieu['ambiance'] != null) ...[
              const SizedBox(height: 8),
              Text(
                lieu['ambiance'],
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 18),

            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFCE1126), size: 21),
                const SizedBox(width: 7),
                Text(lieu['ville'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time, color: Color(0xFF113CFC)),
                const SizedBox(width: 8),
                Expanded(child: Text(horaires, style: const TextStyle(fontSize: 15))),
              ],
            ),
            const SizedBox(height: 26),

            // ⭐ Zone de notation
            const Text("Notez ce lieu :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _note ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _note = index + 1),
                  splashRadius: 21,
                );
              }),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _avisController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Écrivez votre avis ici...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                fillColor: Colors.grey[100],
                filled: true,
              ),
            ),

            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _envoyerAvis,
              icon: const Icon(Icons.send),
              label: const Text("Envoyer l'avis"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 1.5,
              ),
            ),

            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callPhone(context),
                    icon: const Icon(Icons.phone),
                    label: const Text("Appeler"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCE1126),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openMap(context),
                    icon: const Icon(Icons.map),
                    label: const Text("Voir sur la carte"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009460),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
