import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'reservation_tourisme_page.dart';

/// === Palette Tourisme ===
const Color tourismePrimary = Color(0xFFDAA520);
const Color tourismeSecondary = Color(0xFFFFD700);
const Color tourismeOnPrimary = Color(0xFF000000);
const Color tourismeOnSecondary = Color(0xFF000000);

class TourismeDetailPage extends StatefulWidget {
  final Map<String, dynamic> lieu; // données partielles depuis la liste
  const TourismeDetailPage({super.key, required this.lieu});

  @override
  State<TourismeDetailPage> createState() => _TourismeDetailPageState();
}

class _TourismeDetailPageState extends State<TourismeDetailPage> {
  final _sb = Supabase.instance.client;

  // ----- Lieu complet (chargé par id) -----
  Map<String, dynamic>? _fullLieu; // remplace widget.lieu quand chargé
  bool _loadingLieu = false;

  // Avis (saisie)
  int _noteUtilisateur = 0; // 1..5
  final TextEditingController _avisController = TextEditingController();

  // Avis (lecture)
  List<Map<String, dynamic>> _avis = []; // {auteur_id, etoiles, commentaire, created_at}
  double _noteMoyenne = 0;
  bool _dejaNote = false;
  Map<String, Map<String, dynamic>> _usersById = {}; // auteur_id -> {prenom, nom, photo_url}

  // Galerie
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  bool _isUuid(String s) {
    final r = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return r.hasMatch(s);
  }

  @override
  void initState() {
    super.initState();
    _loadFullLieu();   // récupère description, coordonnées complètes, etc.
    _loadAvisBloc();   // charge les avis
  }

  @override
  void dispose() {
    _avisController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ---------- utils ----------
  List<String> _images(Map<String, dynamic> lieu) {
    if (lieu['images'] is List && (lieu['images'] as List).isNotEmpty) {
      return (lieu['images'] as List).map((e) => e.toString()).toList();
    }
    final p = lieu['photo_url']?.toString() ?? '';
    return p.isNotEmpty ? [p] : [];
  }

  String _extractPhone(Map<String, dynamic> m) {
    final raw = (m['contact'] ??
            m['telephone'] ??
            m['phone'] ??
            m['tel'] ??
            '')
        .toString()
        .trim();
    return raw.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  // ---------- Charger le lieu COMPLET par id ----------
  Future<void> _loadFullLieu() async {
    final id = widget.lieu['id']?.toString();
    if (id == null || !_isUuid(id)) return;

    setState(() => _loadingLieu = true);
    try {
      final rows = await _sb
          .from('lieux')
          .select('''
            id, nom, ville, description, type, categorie,
            images, latitude, longitude, created_at,
            contact, photo_url
          ''')
          .eq('id', id)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isNotEmpty && mounted) {
        setState(() => _fullLieu = list.first);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de charger le détail: $e")),
      );
    } finally {
      if (mounted) setState(() => _loadingLieu = false);
    }
  }

  // ---------- Charger avis + profils ----------
  Future<void> _loadAvisBloc() async {
    try {
      final lieuId = widget.lieu['id']?.toString();
      if (lieuId == null || !_isUuid(lieuId)) return;

      // 1) Avis
      final rows = await _sb
          .from('avis_lieux')
          .select('auteur_id, etoiles, commentaire, created_at')
          .eq('lieu_id', lieuId)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(rows);

      // 2) Moyenne
      double moyenne = 0.0;
      if (list.isNotEmpty) {
        final notes =
            list.map((e) => (e['etoiles'] as num?)?.toDouble() ?? 0.0).toList();
        final sum = notes.fold<double>(0.0, (a, b) => a + b);
        moyenne = notes.isEmpty ? 0.0 : sum / notes.length;
      }

      // 3) déjà noté ?
      final me = _sb.auth.currentUser;
      final deja = me != null && list.any((a) => a['auteur_id'] == me.id);

      // 4) Profils
      final ids = list
          .map((e) => e['auteur_id'])
          .whereType<String>()
          .where(_isUuid)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> fetched = {};
      if (ids.isNotEmpty) {
        final orFilter = ids.map((id) => 'id.eq.$id').join(',');
        final profs = await _sb
            .from('utilisateurs')
            .select('id, prenom, nom, photo_url')
            .or(orFilter);

        for (final p in List<Map<String, dynamic>>.from(profs)) {
          final id = (p['id'] ?? '').toString();
          fetched[id] = {
            'prenom': p['prenom'],
            'nom': p['nom'],
            'photo_url': p['photo_url'],
          };
        }
      }

      if (!mounted) return;
      setState(() {
        _avis = list;
        _noteMoyenne = moyenne;
        _dejaNote = deja;
        _usersById
          ..clear()
          ..addAll(fetched);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement avis : $e')),
      );
    }
  }

  // ---------- Envoyer / MAJ avis (1 par utilisateur) ----------
  Future<void> _envoyerAvis() async {
    final note = _noteUtilisateur;
    final commentaire = _avisController.text.trim();
    final me = _sb.auth.currentUser;

    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connexion requise.")),
      );
      return;
    }
    if (note == 0 || commentaire.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci de noter et d'écrire un avis.")),
      );
      return;
    }

    final lieuId = widget.lieu['id']?.toString() ?? '';
    if (!_isUuid(lieuId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID du lieu invalide.")),
      );
      return;
    }

    try {
      await _sb.from('avis_lieux').upsert(
        {
          'lieu_id': lieuId,
          'auteur_id': me.id,
          'etoiles': note,
          'commentaire': commentaire,
        },
        onConflict: 'lieu_id,auteur_id',
      );

      if (!mounted) return;
      setState(() {
        _noteUtilisateur = 0;
        _avisController.clear();
        _dejaNote = true;
      });
      FocusScope.of(context).unfocus();
      await _loadAvisBloc();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Merci pour votre avis !")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi : $e")),
      );
    }
  }

  // ---------- Actions ----------
  Future<void> _contacterLieu(String numero) async {
    final num = numero.trim();
    if (num.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro indisponible.")),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: num);
    final ok = await canLaunchUrl(uri);
    if (!ok || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir l'appel.")),
      );
    }
  }

  Future<void> _ouvrirGoogleMaps(double lat, double lon) async {
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Galerie plein écran
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
                itemCount: images.length,
                pageController: controller,
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: NetworkImage(images[index]),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    heroAttributes: PhotoViewHeroAttributes(
                      tag: 'tourisme_${images[index]}_$index',
                    ),
                  );
                },
                onPageChanged: (i) => setS(() => current = i),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  @override
  Widget build(BuildContext context) {
    // utilise le lieu complet si dispo, sinon les données minimales venues de la liste
    final lieu = _fullLieu ?? widget.lieu;

    final images = _images(lieu);
    final String nom = (lieu['nom'] ?? 'Site touristique').toString();
    final String ville = (lieu['ville'] ?? '').toString();
    final String description = (lieu['description'] ?? '').toString();
    final String numero = _extractPhone(lieu);
    final double? lat = (lieu['latitude'] as num?)?.toDouble();
    final double? lon = (lieu['longitude'] as num?)?.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                nom,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: tourismePrimary, fontWeight: FontWeight.w700),
              ),
            ),
            if (_loadingLieu) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: tourismePrimary),
        elevation: 0.6,
      ),

      // === Barre d’actions FIXE en bas ===
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFEAEAEA))),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _contacterLieu(numero),
                  icon:
                      const Icon(Icons.phone, size: 18, color: tourismePrimary),
                  label: const Text(
                    "Contacter",
                    style: TextStyle(
                        color: tourismePrimary, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: tourismePrimary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReservationTourismePage(lieu: lieu),
                      ),
                    );
                  },
                  icon: const Icon(Icons.event_available,
                      size: 18, color: tourismeOnPrimary),
                  label: const Text(
                    "Réserver",
                    style: TextStyle(
                        color: tourismeOnPrimary, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tourismePrimary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // place pour la barre fixe
        children: [
          // Galerie
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
                          tag: 'tourisme_${images[index]}_$index',
                          child: Image.network(
                            images[index],
                            fit: BoxFit.cover,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${images.length}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
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
                          color:
                              isActive ? tourismePrimary : Colors.transparent,
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

          const SizedBox(height: 12),
          Text(nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (ville.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 4),
                Text(ville, style: const TextStyle(color: Colors.black87)),
              ],
            ),

          // Description chargée uniquement en détail
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description),
          ],

          if (lat != null && lon != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 210,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat, lon),
                  initialZoom: 13,
                ),
                children: [
                  // Ne pas marquer `const` ici
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(lat, lon),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on,
                          size: 40, color: Colors.red),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _ouvrirGoogleMaps(lat, lon),
              icon: const Icon(Icons.map),
              label: const Text("Ouvrir dans Google Maps"),
              style: ElevatedButton.styleFrom(
                backgroundColor: tourismePrimary,
                foregroundColor: tourismeOnPrimary,
              ),
            ),
          ],

          const SizedBox(height: 24),
          Text("Avis des visiteurs",
              style: Theme.of(context).textTheme.titleMedium),
          if (_avis.isEmpty)
            const Text("Aucun avis pour le moment.")
          else ...[
            Text("Note moyenne : ${_noteMoyenne.toStringAsFixed(1)} ★"),
            const SizedBox(height: 6),
            ..._avis.map((a) {
              final uid = (a['auteur_id'] ?? '').toString();
              final u = _usersById[uid] ?? const {};
              final prenom = (u['prenom'] ?? '').toString();
              final nomU = (u['nom'] ?? '').toString();
              final photo = (u['photo_url'] ?? '').toString();
              final fullName =
                  ('$prenom $nomU').trim().isEmpty ? 'Utilisateur' : ('$prenom $nomU').trim();
              final note = (a['etoiles'] as num?)?.toInt() ?? 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(fullName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$note ★"),
                    if ((a['commentaire'] ?? '').toString().isNotEmpty)
                      Text(a['commentaire'].toString()),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 24),
          Text("Laisser un avis", style: Theme.of(context).textTheme.titleSmall),
          if (_dejaNote)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                "Vous avez déjà laissé un avis. Renvoyez pour le mettre à jour.",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
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
              hintText: "Votre avis…",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: const Color(0xFFF8F6F9),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _envoyerAvis,
            icon: const Icon(Icons.send),
            label: Text(_dejaNote ? "Mettre à jour" : "Envoyer"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFDE68A),
              foregroundColor: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
