import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/avis_service.dart';

class RestoDetailPage extends StatefulWidget {
  final dynamic restoId;
  const RestoDetailPage({super.key, required this.restoId});

  @override
  State<RestoDetailPage> createState() => _RestoDetailPageState();
}

class _RestoDetailPageState extends State<RestoDetailPage> {
  Map<String, dynamic>? resto;
  bool loading = true;

  int _noteUtilisateur = 0;
  final _avisController = TextEditingController();
  List<Map<String, dynamic>> _avis = [];
  double _noteMoyenne = 0;
  final _avisService = AvisService();

  // ✅ flag pour éviter de re-préremplir le champ juste après un envoi
  bool _justSubmitted = false;

  final primaryColor = const Color(0xFF113CFC);

  String get _id => widget.restoId.toString();

  bool _isUuid(String id) {
    final uuidRegExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegExp.hasMatch(id);
  }

  @override
  void initState() {
    super.initState();
    _loadResto();
    _loadAvis();
  }

  Future<void> _loadResto() async {
    setState(() => loading = true);

    final data = await Supabase.instance.client
        .from('restaurants')
        .select()
        .eq('id', _id)
        .maybeSingle();

    setState(() {
      resto = data;
      loading = false;
    });
  }

  Future<void> _loadAvis() async {
    final res = await Supabase.instance.client
        .from('avis')
        .select('*, utilisateurs(*)')
        .eq('contexte', 'restaurant')
        .eq('cible_id', _id)
        .order('created_at', ascending: false);

    final notes = res.map<int>((e) => e['note'] as int).toList();
    final moyenne = notes.isNotEmpty
        ? notes.reduce((a, b) => a + b) / notes.length
        : 0.0;

    setState(() {
      _avis = List<Map<String, dynamic>>.from(res);
      _noteMoyenne = moyenne;
    });

    // ✅ on ne préremplit pas si on vient juste d'envoyer
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && !_justSubmitted) {
      final existing = _avis.firstWhere(
        (a) => a['utilisateur_id'] == user.id,
        orElse: () => {},
      );
      if (existing.isNotEmpty) {
        _noteUtilisateur = existing['note'];
        _avisController.text = existing['commentaire'] ?? '';
      }
    }

    // ✅ reset du flag après le rechargement
    _justSubmitted = false;
  }

  Future<void> _envoyerAvis() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connectez-vous pour laisser un avis.")),
      );
      return;
    }

    if (_noteUtilisateur == 0 || _avisController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez noter et commenter.")),
      );
      return;
    }

    if (!_isUuid(_id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur : ID du restaurant invalide.")),
      );
      return;
    }

    await _avisService.ajouterOuModifierAvis(
      contexte: 'restaurant',
      cibleId: _id,
      utilisateurId: user.id,
      note: _noteUtilisateur,
      commentaire: _avisController.text.trim(),
    );

    // ✅ vider les champs et marquer qu'on vient d'envoyer
    _noteUtilisateur = 0;
    _avisController.clear();
    _justSubmitted = true;
    FocusScope.of(context).unfocus(); // optionnel : ferme le clavier

    await _loadAvis();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Merci pour votre avis !")),
    );
  }

  void _reserver() {
    final lat = resto?['latitude'];
    final lng = resto?['longitude'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Réservation",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: const Text(
          "Réservation en ligne bientôt dispo.\n"
          "Contactez le restaurant par téléphone ou sur place.",
        ),
        actions: [
          if (lat != null && lng != null)
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse("https://www.google.com/maps?q=$lat,$lng");
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.map),
              label: const Text("Voir sur Maps"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  void _appeler() async {
    final tel = resto?['telephone'] as String? ?? '';
    if (tel.isNotEmpty) {
      final uri = Uri.parse('tel:$tel');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  Widget _buildStars(int rating, {void Function(int)? onTap}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return IconButton(
          icon: Icon(
            i < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: onTap == null ? null : () => onTap(i + 1),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (resto == null) return const Scaffold(body: Center(child: Text("Introuvable")));

    final nom = resto!['nom'] as String? ?? '';
    final ville = resto!['ville'] as String? ?? '';
    final desc = resto!['description'] as String? ?? '';
    final spec = resto!['specialites'] as String? ?? '';
    final horaire = resto!['horaires'] as String? ?? '';
    final List<String> images = (resto!['images'] as List?)?.cast<String>() ?? [];
    final lat = resto!['latitude'] as double?;
    final lng = resto!['longitude'] as double?;

    return Scaffold(
      appBar: AppBar(
        title: Text(nom, style: TextStyle(color: primaryColor)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(images.first,
                  height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          Text(nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (spec.isNotEmpty) Text(spec, style: const TextStyle(color: Colors.green)),
          Row(children: [
            const Icon(Icons.location_on, color: Colors.red),
            const SizedBox(width: 4),
            Text(ville),
          ]),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(desc),
          ],
          if (horaire.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.schedule, size: 20),
              const SizedBox(width: 4),
              Text(horaire),
            ]),
          ],
          if (_noteMoyenne > 0) ...[
            const SizedBox(height: 8),
            Text("Note moyenne : ${_noteMoyenne.toStringAsFixed(1)} ⭐️"),
          ],
          const Divider(height: 30),

          const Text("Votre avis", style: TextStyle(fontWeight: FontWeight.bold)),
          _buildStars(_noteUtilisateur, onTap: (n) => setState(() => _noteUtilisateur = n)),
          TextField(
            controller: _avisController,
            decoration: const InputDecoration(
              hintText: "Votre commentaire",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _envoyerAvis,
            icon: const Icon(Icons.send),
            label: const Text("Envoyer"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          ),

          const SizedBox(height: 30),

          if (lat != null && lng != null) ...[
            const Text("Localisation", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(center: LatLng(lat, lng), zoom: 15),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(lat, lng),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(
                    "https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.map),
              label: const Text("Ouvrir dans Google Maps"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],

          const SizedBox(height: 30),

          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _appeler,
                icon: const Icon(Icons.phone),
                label: const Text("Appeler"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _reserver,
                icon: const Icon(Icons.calendar_month),
                label: const Text("Réserver"),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              ),
            ),
          ]),

          const SizedBox(height: 30),

          const Text("Avis des utilisateurs", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_avis.isEmpty)
            const Text("Aucun avis pour le moment.")
          else
            Column(
              children: _avis.map((a) {
                final user = a['utilisateurs'] ?? {};
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['photo_url'] != null
                        ? NetworkImage(user['photo_url'])
                        : null,
                    child: user['photo_url'] == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text("${user['prenom'] ?? ''} ${user['nom'] ?? ''}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${a['note']} ⭐️"),
                      if (a['commentaire'] != null) Text(a['commentaire']),
                    ],
                  ),
                );
              }).toList(),
            ),
        ]),
      ),
    );
  }
}
