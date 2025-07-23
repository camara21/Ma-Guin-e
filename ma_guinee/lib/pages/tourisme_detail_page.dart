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

  void _contacterLieu(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Impossible d’appeler le numéro $numero');
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

    debugPrint("📨 Avis envoyé : Note=$note | Avis=$avis");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Merci pour votre avis !")),
    );

    setState(() {
      _noteUtilisateur = 0;
      _avisController.clear();
    });

    // 🔜 Enregistrement futur dans Supabase ici
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
    final lieu = widget.lieu;
    final List<String> images = lieu['images'] != null
        ? List<String>.from(lieu['images'])
        : [lieu['image'] ?? ''];

    final String nom = lieu['nom'] ?? 'Site touristique';
    final String ville = lieu['ville'] ?? 'Ville inconnue';
    final String description = lieu['description'] ?? 'Aucune description disponible.';
    final String horaires = lieu['horaires'] ?? "Lundi - Dimanche : 08h00 - 18h00";
    final String numero = lieu['tel'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          nom,
          style: const TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📸 Images (carousel)
            if (images.isNotEmpty)
              SizedBox(
                height: 200,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        images[index],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade300,
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),

            // 🏞 Nom & Ville
            Text(
              nom,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 6),
            Text(
              ville,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 18),

            // 📝 Description
            Text(description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 18),

            // ⏰ Horaires
            const Text("🕒 Horaires d’ouverture", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(horaires, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 18),

            // 📞 Contacter
            if (numero.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: () => _contacterLieu(numero),
                icon: const Icon(Icons.call),
                label: const Text("Appeler le site"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009460),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 🗺️ Localisation
            ElevatedButton.icon(
              onPressed: () {
                if (lieu['maps_url'] != null && lieu['maps_url'].toString().isNotEmpty) {
                  launchUrl(Uri.parse(lieu['maps_url']));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lien carte indisponible")),
                  );
                }
              },
              icon: const Icon(Icons.map),
              label: const Text("Localiser sur la carte"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF113CFC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 28),

            // ⭐ Avis
            const Text("⭐ Avis des visiteurs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            const Text("“Magnifique site, à visiter absolument !” - Aissatou"),
            const Text("“J’ai adoré la vue et l’ambiance.” - Mamadou"),
            const Text("“Un peu difficile d’accès mais ça vaut le détour.” - Ibrahima"),
            const SizedBox(height: 22),

            // ⭐ Notation + Avis
            const Text("Donnez votre avis :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildStars(_noteUtilisateur, onTap: (note) {
              setState(() => _noteUtilisateur = note);
            }),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
