import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'reservation_tourisme_page.dart';

/// Palette Tourisme
const Color tourismePrimary = Color(0xFFDAA520);
const Color tourismeSecondary = Color(0xFFFFD700);
const Color tourismeOnPrimary = Color(0xFF000000);

class TourismeDetailPage extends StatefulWidget {
  final Map<String, dynamic> lieu;
  const TourismeDetailPage({super.key, required this.lieu});

  @override
  State<TourismeDetailPage> createState() => _TourismeDetailPageState();
}

class _TourismeDetailPageState extends State<TourismeDetailPage> {
  final _sb = Supabase.instance.client;

  // Neutres
  static const Color _neutralBorder = Color(0xFFE5E7EB);

  Map<String, dynamic>? _fullLieu;
  bool _loadingLieu = false;

  // Avis
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  List<Map<String, dynamic>> _avis = [];
  double _noteMoyenne = 0;
  bool _dejaNote = false;
  Map<String, Map<String, dynamic>> _usersById = {};

  // Galerie
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Carte instantanée
  final MapController _mapController = MapController();
  LatLng _defaultCenter = const LatLng(9.6412, -13.5784);
  double _defaultZoom = 15;

  bool _isUuid(String s) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(s);

  bool _validUrl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final u = Uri.tryParse(s.trim());
    return u != null && (u.isScheme('http') || u.isScheme('https'));
  }

  String _fmtDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} • ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _starsStatic(double avg, {double size = 14}) {
    final full = avg.floor().clamp(0, 5);
    final half = (avg - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) {
          return Icon(Icons.star, size: size, color: tourismeSecondary);
        }
        if (i == full && half) {
          return Icon(Icons.star_half, size: size, color: tourismeSecondary);
        }
        return Icon(Icons.star_border, size: size, color: tourismeSecondary);
      }),
    );
  }

  Widget _avgBar() {
    // ✅ Barre note moyenne (sous description)
    if (_avis.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _neutralBorder),
        ),
        child: Row(
          children: const [
            Text(
              "Aucun avis pour le moment",
              style: TextStyle(color: Colors.black54),
            ),
            Spacer(),
            Icon(Icons.verified, size: 18, color: tourismeSecondary),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutralBorder),
      ),
      child: Row(
        children: [
          _starsStatic(_noteMoyenne, size: 16),
          const SizedBox(width: 8),
          Text(
            '${_noteMoyenne.toStringAsFixed(1)} / 5',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '(${_avis.length})',
            style: const TextStyle(color: Colors.black54),
          ),
          const Spacer(),
          const Icon(Icons.verified, size: 18, color: tourismeSecondary),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadFullLieu();
    _loadAvisBloc();
  }

  @override
  void dispose() {
    _avisController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------
  // Images
  // -----------------------------------------------------
  List<String> _images(Map<String, dynamic> lieu) {
    final List<String> out = [];
    final raw = lieu['images'];

    if (raw is List) {
      for (final e in raw) {
        final s = e?.toString();
        if (_validUrl(s)) out.add(s!);
      }
    }

    final p = lieu['photo_url']?.toString();
    if (_validUrl(p)) out.add(p!);

    return out;
  }

  // -----------------------------------------------------
  // Téléphone
  // -----------------------------------------------------
  String _extractPhone(Map<String, dynamic> m) {
    final raw = (m['contact'] ?? m['telephone'] ?? m['phone'] ?? m['tel'] ?? '')
        .toString()
        .trim();
    return raw.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  // -----------------------------------------------------
  // Charger lieu
  // -----------------------------------------------------
  Future<void> _loadFullLieu() async {
    final id = widget.lieu['id']?.toString();
    if (id == null || !_isUuid(id)) return;

    setState(() => _loadingLieu = true);

    try {
      final rows = await _sb
          .from('lieux')
          .select(
              'id, nom, ville, description, type, categorie, images, latitude, longitude, created_at, contact, photo_url')
          .eq('id', id)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isNotEmpty && mounted) {
        _fullLieu = list.first;

        final lat = (_fullLieu!['latitude'] as num?)?.toDouble();
        final lon = (_fullLieu!['longitude'] as num?)?.toDouble();

        if (lat != null && lon != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mapController.move(LatLng(lat, lon), 15);
          });
        }
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

  // -----------------------------------------------------
  // Avis
  // -----------------------------------------------------
  Future<void> _loadAvisBloc() async {
    try {
      final lieuId = widget.lieu['id']?.toString();
      if (lieuId == null || !_isUuid(lieuId)) return;

      final rows = await _sb
          .from('avis_lieux')
          .select('auteur_id, etoiles, commentaire, created_at')
          .eq('lieu_id', lieuId)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(rows);

      double moyenne = 0.0;
      if (list.isNotEmpty) {
        final notes =
            list.map((e) => (e['etoiles'] as num?)?.toDouble() ?? 0.0).toList();
        moyenne =
            notes.isEmpty ? 0.0 : notes.reduce((a, b) => a + b) / notes.length;
      }

      final me = _sb.auth.currentUser;
      final deja = me != null && list.any((a) => a['auteur_id'] == me.id);

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
            'prenom': (p['prenom'] ?? '').toString(),
            'nom': (p['nom'] ?? '').toString(),
            'photo_url': (p['photo_url'] ?? '').toString(),
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

  // -----------------------------------------------------
  // Envoyer avis
  // -----------------------------------------------------
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

      // ✅ ferme clavier + reset
      FocusManager.instance.primaryFocus?.unfocus();

      if (!mounted) return;
      setState(() {
        _noteUtilisateur = 0;
        _avisController.clear();
        _dejaNote = true;
      });

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

  // -----------------------------------------------------
  // Actions
  // -----------------------------------------------------
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
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _ouvrirGoogleMaps(double lat, double lon) async {
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // -----------------------------------------------------
  // Plein écran
  // -----------------------------------------------------
  void _openFullScreenGallery(List<String> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenGalleryPage(
          images: images,
          initialIndex: initialIndex,
          heroPrefix: 'tourisme',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lieu = _fullLieu ?? widget.lieu;

    final images = _images(lieu);
    final nom = (lieu['nom'] ?? 'Site touristique').toString();
    final ville = (lieu['ville'] ?? '').toString();
    final description = (lieu['description'] ?? '').toString().trim();
    final numero = _extractPhone(lieu);

    final lat = (lieu['latitude'] as num?)?.toDouble();
    final lon = (lieu['longitude'] as num?)?.toDouble();

    final canSend =
        _noteUtilisateur > 0 && _avisController.text.trim().isNotEmpty;

    final mapCenter =
        (lat != null && lon != null) ? LatLng(lat, lon) : _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                nom,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: tourismePrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_loadingLieu)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: tourismePrimary),
        elevation: 0.6,
      ),

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
                offset: const Offset(0, -2),
              )
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
                      color: tourismePrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: tourismePrimary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                      color: tourismeOnPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tourismePrimary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ✅ Tap partout = ferme le clavier
      body: Listener(
        onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            // -----------------------------------------------------
            // Galerie
            // -----------------------------------------------------
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
                        itemBuilder: (_, index) => GestureDetector(
                          onTap: () => _openFullScreenGallery(images, index),
                          child: Hero(
                            tag: 'tourisme_$index',
                            child: CachedNetworkImage(
                              imageUrl: images[index],
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: Colors.grey.shade200),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.landscape,
                                    size: 40, color: Colors.grey),
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
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Miniatures
              if (images.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
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
                              color: isActive
                                  ? tourismePrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: CachedNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: Colors.grey.shade200),
                            errorWidget: (_, __, ___) =>
                                const Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ] else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 230,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.landscape, size: 60, color: Colors.grey),
                  ),
                ),
              ),

            // -----------------------------------------------------
            // Texte
            // -----------------------------------------------------
            const SizedBox(height: 12),
            Text(
              nom,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (ville.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.black54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ville,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // ✅ DESCRIPTION
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(height: 1.35)),
            ],

            // ✅ NOTE MOYENNE (SOUS DESCRIPTION)
            const SizedBox(height: 12),
            _avgBar(),

            const SizedBox(height: 16),
            const Divider(height: 28),

            // -----------------------------------------------------
            // CARTE
            // -----------------------------------------------------
            const Text("Localisation",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 210,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: _defaultZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.soneya.app',
                  ),
                  if (lat != null && lon != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lon),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            size: 40,
                            color: tourismePrimary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            if (lat != null && lon != null) ...[
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

            const SizedBox(height: 16),
            const Divider(height: 28),

            // -----------------------------------------------------
            // ✅ AVIS DES VISITEURS (AU-DESSUS de "Votre avis")
            // -----------------------------------------------------
            const Text(
              "Avis des visiteurs",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (_avis.isEmpty)
              const Text("Aucun avis pour le moment.")
            else
              Column(
                children: _avis.map((a) {
                  final uid = (a['auteur_id'] ?? '').toString();
                  final u = _usersById[uid] ?? const {};
                  final prenom = (u['prenom'] ?? '').toString();
                  final nomU = (u['nom'] ?? '').toString();
                  final photo = (u['photo_url'] ?? '').toString();
                  final fullName = ('$prenom $nomU').trim().isEmpty
                      ? 'Utilisateur'
                      : ('$prenom $nomU').trim();

                  final etoiles = (a['etoiles'] as num?)?.toDouble() ?? 0.0;
                  final commentaire =
                      (a['commentaire'] ?? '').toString().trim();
                  final dateStr = _fmtDate(a['created_at']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _neutralBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage:
                              (photo.isNotEmpty) ? NetworkImage(photo) : null,
                          child: photo.isEmpty
                              ? const Icon(Icons.person, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _starsStatic(etoiles, size: 14),
                                ],
                              ),
                              if (commentaire.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  commentaire,
                                  style: const TextStyle(height: 1.3),
                                ),
                              ],
                              if (dateStr.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 18),
            const Divider(height: 28),

            // -----------------------------------------------------
            // ✅ VOTRE AVIS (TOUT EN BAS)
            // -----------------------------------------------------
            const Text("Votre avis",
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (_dejaNote)
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 6),
                child: Text(
                  "Vous avez déjà laissé un avis. Renvoyez pour mettre à jour.",
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
              minLines: 3,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _envoyerAvis(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Votre avis…",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: tourismePrimary, width: 1.4),
                ),
                filled: true,
                fillColor: const Color(0xFFF8F6F9),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: canSend ? _envoyerAvis : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(_dejaNote ? "Mettre à jour" : "Envoyer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tourismePrimary,
                  foregroundColor: tourismeOnPrimary,
                  disabledBackgroundColor: tourismePrimary.withOpacity(0.35),
                  disabledForegroundColor: tourismeOnPrimary.withOpacity(0.85),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =====================================================
   GALERIE PLEIN ÉCRAN SANS SPINNER
   ===================================================== */
class _FullscreenGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroPrefix;

  const _FullscreenGalleryPage({
    required this.images,
    required this.initialIndex,
    required this.heroPrefix,
  });

  @override
  State<_FullscreenGalleryPage> createState() => _FullscreenGalleryPageState();
}

class _FullscreenGalleryPageState extends State<_FullscreenGalleryPage> {
  late final PageController _ctrl =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          '${_index + 1}/$total',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _ctrl,
        onPageChanged: (i) => setState(() => _index = i),
        itemCount: total,
        itemBuilder: (_, i) {
          final url = widget.images[i];
          return Center(
            child: Hero(
              tag: '${widget.heroPrefix}_$i',
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(color: Colors.black),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    size: 60,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
