import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TourismeDetailPage extends StatefulWidget {
  final Map<String, dynamic> lieu;

  const TourismeDetailPage({super.key, required this.lieu});

  @override
  State<TourismeDetailPage> createState() => _TourismeDetailPageState();
}

class _TourismeDetailPageState extends State<TourismeDetailPage> {
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  int _currentImage = 0;

  void _contacterLieu(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro invalide")),
      );
    }
  }

  void _envoyerAvis() {
    final note = _noteUtilisateur;
    final avis = _avisController.text.trim();
    if (note == 0 || avis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci de noter et d’écrire un avis.")),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Merci pour votre avis !")),
    );
    setState(() {
      _noteUtilisateur = 0;
      _avisController.clear();
    });
  }

  // Sélectionne toujours la/les images ou le photo_url fallback
  List<String> getImages(Map<String, dynamic> lieu) {
    if (lieu['images'] is List && (lieu['images'] as List).isNotEmpty) {
      return (lieu['images'] as List).cast<String>();
    }
    if (lieu['photo_url'] != null && lieu['photo_url'].toString().isNotEmpty) {
      return [lieu['photo_url']];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final lieu = widget.lieu;
    final images = getImages(lieu);

    final String nom = lieu['nom'] ?? 'Site touristique';
    final String ville = lieu['ville'] ?? 'Ville inconnue';
    final String description = lieu['description'] ?? 'Aucune description disponible.';
    final String horaires = lieu['horaires'] ?? "Lundi - Dimanche : 08h00 - 18h00";
    final String numero = lieu['contact'] ?? lieu['tel'] ?? '';
    final String? mapsUrl = lieu['maps_url'];

    final bool isWeb = MediaQuery.of(context).size.width > 650;
    final primaryColor = const Color(0xFF113CFC);
    final secondaryColor = const Color(0xFF009460);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          nom,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: isWeb ? 26 : 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: IconThemeData(color: primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Color(0xFFCE1126)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Ajouté aux favoris !")),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Carousel Images ----------
                if (images.isNotEmpty)
                  Column(
                    children: [
                      SizedBox(
                        height: isWeb ? 340 : 210,
                        child: PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _currentImage = i),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                images[index],
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image, size: 50),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (images.length > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentImage == i ? 18 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentImage == i
                                      ? primaryColor.withOpacity(0.9)
                                      : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: isWeb ? 340 : 210,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported, size: 60),
                    ),
                  ),
                const SizedBox(height: 20),

                // ---------- Titre, ville ----------
                Text(
                  nom,
                  style: TextStyle(
                    fontSize: isWeb ? 30 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF009460), size: 20),
                    const SizedBox(width: 5),
                    Text(
                      ville,
                      style: const TextStyle(fontSize: 16, color: Color(0xFF009460)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ---------- Description ----------
                Text(
                  description,
                  style: TextStyle(fontSize: isWeb ? 19 : 16),
                ),
                const SizedBox(height: 20),

                // ---------- Horaires ----------
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, color: Color(0xFF113CFC)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          horaires,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ---------- Boutons action ----------
                Wrap(
                  runSpacing: 10,
                  spacing: 16,
                  children: [
                    if (numero.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _contacterLieu(numero),
                        icon: const Icon(Icons.call),
                        label: const Text("Appeler le site"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                          textStyle: TextStyle(fontSize: isWeb ? 18 : 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (mapsUrl != null && mapsUrl.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(mapsUrl)),
                        icon: const Icon(Icons.map, color: Color(0xFF113CFC)),
                        label: const Text("Voir sur la carte"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor, width: 1.4),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                          textStyle: TextStyle(fontSize: isWeb ? 18 : 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 30),

                // ---------- Section avis (simulé) ----------
                Text("⭐ Avis des visiteurs",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isWeb ? 21 : 17,
                      color: Colors.black87,
                    )),
                const SizedBox(height: 12),
                ...[
                  "“Magnifique site, à visiter absolument !” - Aissatou",
                  "“J’ai adoré la vue et l’ambiance.” - Mamadou",
                  "“Un peu difficile d’accès mais ça vaut le détour.” - Ibrahima",
                ].map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 2.5),
                  child: Text(a, style: const TextStyle(fontSize: 15, color: Colors.black54)),
                )),

                const SizedBox(height: 24),

                // ---------- Notation + avis utilisateur ----------
                Text("Donnez votre avis :",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isWeb ? 20 : 16,
                    )),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < _noteUtilisateur ? Icons.star : Icons.star_border,
                        color: Colors.amber[700],
                      ),
                      onPressed: () => setState(() => _noteUtilisateur = index + 1),
                      iconSize: 30,
                      splashRadius: 20,
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _avisController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Partagez votre expérience...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _envoyerAvis,
                  icon: const Icon(Icons.send),
                  label: const Text("Envoyer mon avis"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    textStyle: TextStyle(fontSize: isWeb ? 17 : 15, fontWeight: FontWeight.w600),
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
