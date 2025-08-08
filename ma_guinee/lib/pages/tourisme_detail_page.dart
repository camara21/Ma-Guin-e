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
  // Thème
  final primaryColor = const Color(0xFF113CFC);
  final green = const Color(0xFF009460);
  final sendColor = const Color(0xFFFF9800);

  // Avis (entrée utilisateur — jamais préremplie)
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();

  // État
  int _currentImage = 0;
  List<Map<String, dynamic>> _avis = [];
  double _noteMoyenne = 0;
  Map<String, dynamic>? _avisUtilisateur; // pour UPDATE/INSERT, mais sans préremplir

  @override
  void initState() {
    super.initState();
    _loadAvis();
  }

  @override
  void dispose() {
    _avisController.dispose();
    super.dispose();
  }

  // ----------------- Utils -----------------

  List<String> _images(Map<String, dynamic> lieu) {
    if (lieu['images'] is List && (lieu['images'] as List).isNotEmpty) {
      return (lieu['images'] as List).cast<String>();
    }
    final p = lieu['photo_url']?.toString() ?? '';
    return p.isNotEmpty ? [p] : [];
  }

  // ✅ only the 'contact' field (no tel/telephone columns)
  String _extractPhone(Map<String, dynamic> m) {
    final raw = (m['contact'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    return raw.replaceAll(RegExp(r'[\s\.\-]'), '');
  }

  // ----------------- Avis -----------------

  Future<void> _loadAvis() async {
    final user = Supabase.instance.client.auth.currentUser;

    final res = await Supabase.instance.client
        .from('avis')
        .select(
          'id, note, commentaire, utilisateur_id, created_at, utilisateurs(nom, prenom, photo_url)',
        )
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
        final aMoi = avisList.firstWhere(
          (a) => a['utilisateur_id'] == user.id,
          orElse: () => {},
        );
        _avisUtilisateur = aMoi.isEmpty ? null : aMoi;
      }
      // ⚠️ Ne PAS pré-remplir _noteUtilisateur ni _avisController.
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

    if (_avisUtilisateur != null) {
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci pour votre avis !")),
      );
    }
  }

  // ----------------- Actions -----------------

  void _contacterLieu(String numero) async {
    if (numero.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro indisponible.")),
      );
      return;
    }
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d’initier l’appel.")),
      );
    }
  }

  void _reserver() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Réservation", style: TextStyle(color: primaryColor)),
        content: const Text(
          "Réservation en ligne bientôt dispo.\n"
          "Contactez le gestionnaire ou l’agence touristique.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
        ],
      ),
    );
  }

  void _ouvrirGoogleMaps(double lat, double lon) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d’ouvrir Google Maps.")),
      );
    }
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    final lieu = widget.lieu;
    final images = _images(lieu);

    final String nom = (lieu['nom'] ?? 'Site touristique').toString();
    final String ville = (lieu['ville'] ?? '').toString();
    final String description = (lieu['description'] ?? '').toString();
    final String numero = _extractPhone(lieu); // ✅ uses only 'contact'
    final double? lat = (lieu['latitude'] as num?)?.toDouble();
    final double? lon = (lieu['longitude'] as num?)?.toDouble();
    final isWide = MediaQuery.of(context).size.width > 650;

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
                  height: isWide ? 360 : 220,
                  child: PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentImage = i),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.photo, size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                if (images.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (i) {
                        final active = _currentImage == i;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 16 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? primaryColor : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 16),

          // Titre + Ville
          Text(nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (ville.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green),
                const SizedBox(width: 6),
                Text(ville, style: TextStyle(color: green)),
              ],
            ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description),
          ],

          // Carte + bouton Google Maps
          if (lat != null && lon != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 210,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lon),
                    initialZoom: 13,
                  ),
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
                minimumSize: const Size(180, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Actions (Appeler / Réserver) — compact buttons
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (numero.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _contacterLieu(numero),
                  icon: const Icon(Icons.phone),
                  label: const Text("Appeler"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _reserver,
                icon: const Icon(Icons.event_available),
                label: const Text("Réserver"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(140, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Avis existants
          Text("⭐ Avis des visiteurs", style: Theme.of(context).textTheme.titleMedium),
          if (_avis.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text("Aucun avis pour le moment."),
            )
          else ...[
            const SizedBox(height: 4),
            Text("Note moyenne : ${_noteMoyenne.toStringAsFixed(1)} ⭐️"),
            const SizedBox(height: 10),
            ..._avis.map((a) {
              final user = a['utilisateurs'] ?? {};
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: (user['photo_url'] != null &&
                          user['photo_url'].toString().isNotEmpty)
                      ? NetworkImage(user['photo_url'])
                      : null,
                  child: (user['photo_url'] == null ||
                          user['photo_url'].toString().isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text("${user['prenom'] ?? ''} ${user['nom'] ?? ''}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${a['note']} ⭐️"),
                    if ((a['commentaire'] ?? '').toString().isNotEmpty)
                      Text(a['commentaire'].toString()),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 24),

          // Formulaire d'avis (jamais prérempli)
          Text("Laisser un avis", style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: List.generate(5, (i) {
              final active = i < _noteUtilisateur;
              return IconButton(
                onPressed: () => setState(() => _noteUtilisateur = i + 1),
                icon: Icon(active ? Icons.star : Icons.star_border),
                color: Colors.amber,
              );
            }),
          ),
          TextField(
            controller: _avisController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Votre avis...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: const Color(0xFFF8F6F9),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _envoyerAvis,
            icon: const Icon(Icons.send),
            label: const Text("Envoyer"),
            style: ElevatedButton.styleFrom(
              backgroundColor: sendColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}
