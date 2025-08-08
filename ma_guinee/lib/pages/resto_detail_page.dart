import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view/photo_view.dart';
import '../services/avis_service.dart';

class RestoDetailPage extends StatefulWidget {
  final String restoId; // UUID
  const RestoDetailPage({super.key, required this.restoId});

  @override
  State<RestoDetailPage> createState() => _RestoDetailPageState();
}

class _RestoDetailPageState extends State<RestoDetailPage> {
  Map<String, dynamic>? resto;
  bool loading = true;

  // Avis
  int _noteUtilisateur = 0; // jamais prérempli
  final _avisController = TextEditingController(); // jamais prérempli
  List<Map<String, dynamic>> _avis = [];
  double _noteMoyenne = 0;
  final _avisService = AvisService();
  bool _userHasExistingReview = false; // info seulement

  // Galerie
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final primaryColor = const Color(0xFF113CFC);
  String get _id => widget.restoId;

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

  @override
  void dispose() {
    _pageController.dispose();
    _avisController.dispose();
    super.dispose();
  }

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  Future<void> _loadResto() async {
    setState(() => loading = true);
    try {
      final data = await Supabase.instance.client
          .from('restaurants')
          .select()
          .eq('id', _id)
          .maybeSingle();
      setState(() {
        resto = (data == null) ? null : Map<String, dynamic>.from(data);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur de chargement: $e')));
    }
  }

  Future<void> _loadAvis() async {
    try {
      final res = await Supabase.instance.client
          .from('avis')
          .select('*, utilisateurs(*)')
          .eq('contexte', 'restaurant')
          .eq('cible_id', _id)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(res);
      final notes = list.map<int>((e) => (e['note'] as num?)?.toInt() ?? 0).toList();
      final moyenne =
          notes.isNotEmpty ? notes.reduce((a, b) => a + b) / notes.length : 0.0;

      // L'utilisateur a-t-il déjà donné un avis ? (juste indicatif)
      final user = Supabase.instance.client.auth.currentUser;
      final already = user != null && list.any((a) => a['utilisateur_id'] == user.id);

      setState(() {
        _avis = list;
        _noteMoyenne = moyenne;
        _userHasExistingReview = already;
        // Ne JAMAIS remplir _noteUtilisateur ou _avisController ici
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur chargement avis: $e')));
    }
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

    try {
      // Upsert (ajouter ou modifier l'avis existant)
      await _avisService.ajouterOuModifierAvis(
        contexte: 'restaurant',
        cibleId: _id,
        utilisateurId: user.id,
        note: _noteUtilisateur,
        commentaire: _avisController.text.trim(),
      );

      // On ne cache pas : on nettoie juste les champs après envoi
      setState(() {
        _noteUtilisateur = 0;
        _avisController.clear();
        _userHasExistingReview = true; // affichera l'info
      });
      FocusScope.of(context).unfocus();

      await _loadAvis();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Merci pour votre avis !")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi de l'avis: $e")),
      );
    }
  }

  void _reserver() {
    final lat = (resto?['latitude'] as num?)?.toDouble();
    final lng = (resto?['longitude'] as num?)?.toDouble();
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
    // colonne correcte = 'tel' (fallback 'telephone' si jamais tu l'as aussi)
    final telRaw =
        (resto?['tel'] ?? resto?['telephone'] ?? '').toString().trim();
    final tel = telRaw.replaceAll(RegExp(r'[^0-9+]'), ''); // nettoyer
    if (tel.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro indisponible.")),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible d'ouvrir le téléphone pour $tel")),
      );
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

  // --------- PLEIN ÉCRAN (PhotoViewGallery) ----------
  void _openFullScreenGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) {
        final controller = PageController(initialPage: initialIndex);
        int current = initialIndex;
        return StatefulBuilder(builder: (context, setS) {
          return Stack(
            children: [
              PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                itemCount: images.length,
                pageController: controller,
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: NetworkImage(images[index]),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    heroAttributes: PhotoViewHeroAttributes(tag: 'resto_$index'),
                  );
                },
                onPageChanged: (i) => setS(() => current = i),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
              // Compteur 1/N
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${current + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
              // Fermer
              Positioned(
                top: 24,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          );
        });
      },
    );
  }
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (resto == null) {
      return const Scaffold(body: Center(child: Text("Introuvable")));
    }

    final nom = (resto!['nom'] ?? '').toString();
    final ville = (resto!['ville'] ?? '').toString();
    final desc = (resto!['description'] ?? '').toString();
    final spec = (resto!['specialites'] ?? '').toString();
    final horaire = (resto!['horaires'] ?? '').toString();
    final images = _imagesFrom(resto!['images']);
    final lat = (resto!['latitude'] as num?)?.toDouble();
    final lng = (resto!['longitude'] as num?)?.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(nom, style: TextStyle(color: primaryColor)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ---------- CARROUSEL + MINIATURES ----------
          if (images.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  SizedBox(
                    height: 230,
                    width: double.infinity,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => _openFullScreenGallery(images, index),
                        child: Hero(
                          tag: 'resto_$index',
                          child: Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${images.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isActive = index == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                      );
                      setState(() => _currentIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive ? primaryColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          // ------------------------------------------------

          const SizedBox(height: 12),
          Text(nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (spec.isNotEmpty) const SizedBox(height: 2),
          if (spec.isNotEmpty)
            Text(spec, style: const TextStyle(color: Colors.green)),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red),
              const SizedBox(width: 4),
              Text(ville),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(desc),
          ],
          if (horaire.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 4),
                Text(horaire),
              ],
            ),
          ],
          if (_noteMoyenne > 0) ...[
            const SizedBox(height: 8),
            Text("Note moyenne : ${_noteMoyenne.toStringAsFixed(1)} ⭐️"),
          ],
          const Divider(height: 30),

          const Text("Votre avis", style: TextStyle(fontWeight: FontWeight.bold)),
          if (_userHasExistingReview)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                "Vous avez déjà donné un avis. Renvoyez pour le mettre à jour.",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
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
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 15,
                ),
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
                final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
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
                    backgroundImage: (user['photo_url'] != null && user['photo_url'].toString().isNotEmpty)
                        ? NetworkImage(user['photo_url'])
                        : null,
                    child: (user['photo_url'] == null || user['photo_url'].toString().isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text("${user['prenom'] ?? ''} ${user['nom'] ?? ''}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${a['note']} ⭐️"),
                      if (a['commentaire'] != null) Text(a['commentaire'].toString()),
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
