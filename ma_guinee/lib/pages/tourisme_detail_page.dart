import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

  List<Map<String, dynamic>> _avis = [];
  double _noteMoyenne = 0;
  Map<String, dynamic>? _avisUtilisateur;

  @override
  void initState() {
    super.initState();
    _loadAvis();
  }

  Future<void> _loadAvis() async {
    final user = Supabase.instance.client.auth.currentUser;

    final res = await Supabase.instance.client
        .from('avis')
        .select('id, note, commentaire, utilisateur_id, created_at, utilisateurs(nom, prenom, photo_url)')
        .eq('contexte', 'tourisme')
        .eq('cible_id', widget.lieu['id'])
        .order('created_at', ascending: false);

    final avisList = List<Map<String, dynamic>>.from(res);

    double somme = 0;
    for (var a in avisList) {
      somme += (a['note'] as num).toDouble();
    }

    setState(() {
      _avis = avisList;
      _noteMoyenne = avisList.isNotEmpty ? somme / avisList.length : 0;

      if (user != null) {
        _avisUtilisateur = avisList.firstWhere(
          (a) => a['utilisateur_id'] == user.id,
          orElse: () => {},
        );

        if (_avisUtilisateur != null && _avisUtilisateur!.isNotEmpty) {
          _noteUtilisateur = _avisUtilisateur!['note'];
          _avisController.text = _avisUtilisateur!['commentaire'] ?? '';
        }
      }
    });
  }

  Future<void> _envoyerAvis() async {
    final note = _noteUtilisateur;
    final commentaire = _avisController.text.trim();
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connexion requise.")),
      );
      return;
    }

    if (note == 0 || commentaire.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci de noter et d’écrire un avis.")),
      );
      return;
    }

    if (_avisUtilisateur != null && _avisUtilisateur!.isNotEmpty) {
      await Supabase.instance.client.from('avis').update({
        'note': note,
        'commentaire': commentaire,
      }).eq('id', _avisUtilisateur!['id']);
    } else {
      await Supabase.instance.client.from('avis').insert({
        'utilisateur_id': user.id,
        'contexte': 'tourisme',
        'cible_id': widget.lieu['id'],
        'note': note,
        'commentaire': commentaire,
      });
    }

    setState(() {
      _noteUtilisateur = 0;
      _avisController.clear();
    });

    await _loadAvis();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Merci pour votre avis !")),
    );
  }

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

  void _reserver() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Réservation"),
        content: const Text(
            "Merci pour votre intérêt ! Pour réserver ce site touristique, veuillez contacter directement le gestionnaire ou l’agence touristique référencée."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
        ],
      ),
    );
  }

  void _ouvrirGoogleMaps(double lat, double lon) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d’ouvrir Google Maps.")),
      );
    }
  }

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
    final String numero = lieu['contact'] ?? lieu['tel'] ?? '';
    final double? lat = lieu['latitude'];
    final double? lon = lieu['longitude'];
    final primaryColor = const Color(0xFF113CFC);
    final isWeb = MediaQuery.of(context).size.width > 650;

    return Scaffold(
      appBar: AppBar(
        title: Text(nom, style: TextStyle(color: primaryColor)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: primaryColor),
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (images.isNotEmpty)
            Column(
              children: [
                SizedBox(
                  height: isWeb ? 350 : 210,
                  child: PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentImage = i),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(images[i], fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
                ),
                if (images.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImage == i ? 16 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentImage == i ? primaryColor : Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Text(nom, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on, color: Colors.green),
            const SizedBox(width: 6),
            Text(ville, style: const TextStyle(color: Colors.green)),
          ]),
          const SizedBox(height: 14),
          Text(description),
          const SizedBox(height: 14),
          if (lat != null && lon != null)
            Column(
              children: [
                SizedBox(
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(center: LatLng(lat, lon), zoom: 13),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.app',
                        ),
                        MarkerLayer(markers: [
                          Marker(
                            point: LatLng(lat, lon),
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, size: 40, color: Colors.red),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _ouvrirGoogleMaps(lat, lon),
                  icon: const Icon(Icons.map),
                  label: const Text("Ouvrir dans Google Maps"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _reserver,
                icon: const Icon(Icons.event_available),
                label: const Text("Réserver"),
              ),
              if (numero.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _contacterLieu(numero),
                  icon: const Icon(Icons.phone),
                  label: const Text("Appeler"),
                ),
            ],
          ),
          const SizedBox(height: 30),
          Text("⭐ Avis des visiteurs", style: Theme.of(context).textTheme.titleMedium),
          if (_avis.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text("Aucun avis pour le moment."),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Note moyenne : ${_noteMoyenne.toStringAsFixed(1)} ⭐️"),
                const SizedBox(height: 10),
                ..._avis.map((avis) {
                  final user = avis['utilisateurs'] ?? {};
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['photo_url'] != null ? NetworkImage(user['photo_url']) : null,
                      child: user['photo_url'] == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text("${user['prenom'] ?? ''} ${user['nom'] ?? ''}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${avis['note']} ⭐️"),
                        if (avis['commentaire'] != null) Text(avis['commentaire']),
                      ],
                    ),
                  );
                }),
              ],
            ),
          const SizedBox(height: 30),
          Text("Laisser un avis", style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: List.generate(5, (i) {
              return IconButton(
                onPressed: () => setState(() => _noteUtilisateur = i + 1),
                icon: Icon(i < _noteUtilisateur ? Icons.star : Icons.star_border, color: Colors.amber),
              );
            }),
          ),
          TextField(
            controller: _avisController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Votre avis...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _envoyerAvis,
            icon: const Icon(Icons.send),
            label: const Text("Envoyer"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }
}
