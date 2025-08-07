import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/avis_service.dart';

class HotelDetailPage extends StatefulWidget {
  final dynamic hotelId; // ✅ accepte UUID String (ou autre), on le normalise avec _id
  const HotelDetailPage({super.key, required this.hotelId});

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  Map<String, dynamic>? hotel;
  bool loading = true;

  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  double _noteMoyenne = 0;
  List<Map<String, dynamic>> _avis = [];

  // Pour éviter de re-préremplir immédiatement après un envoi
  bool _justSubmitted = false;

  String get _id => widget.hotelId.toString();

  bool _isUuid(String id) {
    final re = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return re.hasMatch(id);
  }

  @override
  void initState() {
    super.initState();
    _loadHotel();
    _loadAvis();
  }

  Future<void> _loadHotel() async {
    setState(() => loading = true);

    final data = await Supabase.instance.client
        .from('hotels')
        .select()
        .eq('id', _id) // ✅ même type que dans la BDD (UUID)
        .maybeSingle();

    setState(() {
      hotel = data;
      loading = false;
    });
  }

  Future<void> _loadAvis() async {
    final res = await Supabase.instance.client
        .from('avis')
        .select('id, note, commentaire, created_at, utilisateurs(nom, prenom, photo_url)')
        .eq('contexte', 'hotel')
        .eq('cible_id', _id) // ✅ filtre sur le même UUID
        .order('created_at', ascending: false);

    final notes = res.map((e) => (e['note'] as num).toDouble()).toList();
    final moyenne = notes.isNotEmpty ? notes.reduce((a, b) => a + b) / notes.length : 0.0;

    setState(() {
      _avis = List<Map<String, dynamic>>.from(res);
      _noteMoyenne = moyenne;
    });

    // (optionnel) Si tu veux préremplir quand l'user a déjà noté, enlève le flag _justSubmitted si besoin
    _justSubmitted = false;
  }

  Future<void> _envoyerAvis() async {
    final commentaire = _avisController.text.trim();
    final note = _noteUtilisateur;
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connectez-vous pour laisser un avis.")),
      );
      return;
    }
    if (note == 0 || commentaire.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez donner une note et un avis.")),
      );
      return;
    }
    if (!_isUuid(_id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur : ID de l'hôtel invalide.")),
      );
      return;
    }

    await AvisService().ajouterOuModifierAvis(
      contexte: 'hotel',
      cibleId: _id,           // ✅ UUID correct
      utilisateurId: user.id, // UUID Supabase de l'utilisateur
      note: note,
      commentaire: commentaire,
    );

    // Reset UI
    _avisController.clear();
    setState(() => _noteUtilisateur = 0);
    _justSubmitted = true;
    FocusScope.of(context).unfocus();

    await _loadAvis();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Merci pour votre avis !")),
    );
  }

  void _contacter() async {
    final tel = hotel?['telephone'];
    if (tel != null && tel.toString().isNotEmpty) {
      final uri = Uri.parse('tel:$tel');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'appeler $tel")),
        );
      }
    }
  }

  void _localiser() async {
    final latitude = hotel?['latitude'];
    final longitude = hotel?['longitude'];
    if (latitude != null && longitude != null) {
      final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$latitude,$longitude");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _showReservationMessage() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Réservation"),
        content: const Text(
          "Le service de réservation en ligne sera bientôt disponible. Merci pour votre patience.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(int rating, {void Function(int)? onTap}) {
    return Row(
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: onTap != null ? () => onTap(index + 1) : null,
          iconSize: 30,
          splashRadius: 20,
        );
      }),
    );
  }

  Widget _buildAvisList() {
    if (_avis.isEmpty) return const Text("Pas encore d'avis");

    return Column(
      children: _avis.map((avis) {
        final utilisateur = avis['utilisateurs'] ?? {};
        final nom = "${utilisateur['prenom'] ?? ''} ${utilisateur['nom'] ?? ''}".trim();
        final note = avis['note'] ?? 0;
        final commentaire = avis['commentaire'] ?? '';
        final photo = utilisateur['photo_url'];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                radius: 22,
                child: photo == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < note ? Icons.star : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(commentaire),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.9),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || hotel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<String> images = (hotel!['images'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(hotel!['nom'] ?? ''),
        backgroundColor: const Color(0xFF113CFC),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (images.isNotEmpty) _buildImageCarousel(images),
            const SizedBox(height: 16),
            Text("Ville : ${hotel!['ville'] ?? 'Non précisé'}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Prix moyen : ${hotel!['prix'] ?? 'Non précisé'} ${hotel!['devise'] ?? ''}",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Description :\n${hotel!['description'] ?? 'Aucune description'}"),
            const SizedBox(height: 20),

            const Text("Avis client :", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_avis.isEmpty ? "Pas d'avis" : "${_noteMoyenne.toStringAsFixed(1)} / 5"),

            const SizedBox(height: 10),
            const Text("Notez cet hôtel :", style: TextStyle(fontWeight: FontWeight.bold)),
            _buildStars(_noteUtilisateur, onTap: (val) => setState(() => _noteUtilisateur = val)),
            TextField(
              controller: _avisController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Partagez votre expérience avec cet hôtel...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _envoyerAvis,
              icon: const Icon(Icons.send),
              label: const Text("Envoyer mon avis"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFCD116),
                foregroundColor: Colors.black,
              ),
            ),

            const SizedBox(height: 20),
            _buildAvisList(),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _localiser,
                  icon: const Icon(Icons.map),
                  label: const Text("Localiser"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                ),
                ElevatedButton.icon(
                  onPressed: _contacter,
                  icon: const Icon(Icons.phone),
                  label: const Text("Contacter"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: _showReservationMessage,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Réserver"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
