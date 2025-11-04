import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DivertissementDetailPage extends StatefulWidget {
  final Map<String, dynamic> lieu;
  const DivertissementDetailPage({super.key, required this.lieu});

  @override
  State<DivertissementDetailPage> createState() =>
      _DivertissementDetailPageState();
}

class _DivertissementDetailPageState extends State<DivertissementDetailPage> {
  static const Color kPrimary = Colors.deepPurple;

  final _sb = Supabase.instance.client;

  // Avis (édition)
  int _note = 0;
  final TextEditingController _avisController = TextEditingController();

  // Stats avis (affichage)
  double? _noteMoyenne;
  int _nbAvis = 0;
  bool _loadingAvis = true;

  // Commentaires (liste + profils)
  bool _loadingCommentaires = true;
  List<Map<String, dynamic>> _avisList = []; // avis_lieux rows
  final Map<String, Map<String, dynamic>> _usersById = {}; // auteur_id -> {prenom, nom, photo_url}

  // Galerie
  final PageController _pageController = PageController();
  int _currentImage = 0;

  bool _isUuid(String s) {
    final r = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return r.hasMatch(s);
  }

  @override
  void initState() {
    super.initState();
    _loadAvisStats();
    _loadAvisCommentaires();
  }

  @override
  void dispose() {
    _avisController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ----------------- SUPABASE: Avis (stats) -----------------
  Future<void> _loadAvisStats() async {
    setState(() => _loadingAvis = true);
    try {
      final lieuId = widget.lieu['id']?.toString();

      if (lieuId == null || lieuId.isEmpty) {
        _noteMoyenne = null;
        _nbAvis = 0;
      } else {
        final rows = await _sb
            .from('avis_lieux')
            .select('etoiles')
            .eq('lieu_id', lieuId);

        final notes = List<Map<String, dynamic>>.from(rows)
            .map((r) => (r['etoiles'] as num?)?.toDouble())
            .whereType<double>()
            .toList();

        _nbAvis = notes.length;
        _noteMoyenne =
            _nbAvis == 0 ? null : notes.reduce((a, b) => a + b) / _nbAvis;
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur avis: ${e.message}')),
      );
      _noteMoyenne = null;
      _nbAvis = 0;
    } finally {
      if (mounted) setState(() => _loadingAvis = false);
    }
  }

  // ----------------- SUPABASE: Avis (liste + profils via `utilisateurs`) -----------------
  Future<void> _loadAvisCommentaires() async {
    setState(() => _loadingCommentaires = true);
    try {
      final lieuId = widget.lieu['id']?.toString();
      if (lieuId == null || !_isUuid(lieuId)) {
        _avisList = [];
      } else {
        // 1) Récupère les 20 avis les plus récents (sans jointure)
        final rows = await _sb
            .from('avis_lieux')
            .select('auteur_id, etoiles, commentaire, created_at')
            .eq('lieu_id', lieuId)
            .order('created_at', ascending: false)
            .limit(20);

        final list = List<Map<String, dynamic>>.from(rows);

        // 2) Récupère les profils dans `utilisateurs` comme dans Tourisme
        _usersById.clear();
        final ids = list
            .map((e) => (e['auteur_id'] ?? '').toString())
            .where(_isUuid)
            .toSet()
            .toList();

        if (ids.isNotEmpty) {
          final orFilter = ids.map((id) => 'id.eq.$id').join(',');
          final profs = await _sb
              .from('utilisateurs')
              .select('id, prenom, nom, photo_url')
              .or(orFilter);

          for (final p in List<Map<String, dynamic>>.from(profs)) {
            final id = (p['id'] ?? '').toString();
            _usersById[id] = {
              'prenom': p['prenom'],
              'nom': p['nom'],
              'photo_url': p['photo_url'],
            };
          }
        }

        // 3) On garde uniquement ceux qui ont un commentaire non vide
        _avisList = list
            .where((r) =>
                (r['commentaire']?.toString().trim().isNotEmpty ?? false))
            .toList();
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur commentaires: ${e.message}')),
      );
      _avisList = [];
    } finally {
      if (mounted) setState(() => _loadingCommentaires = false);
    }
  }

  Future<void> _submitAvis() async {
    final userId = _sb.auth.currentUser?.id;
    final lieuId = widget.lieu['id']?.toString();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Veuillez vous connecter pour laisser un avis.")),
      );
      return;
    }
    if (lieuId == null || lieuId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lieu invalide.")),
      );
      return;
    }
    if (_note <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Choisissez une note (au moins 1 étoile).")),
      );
      return;
    }

    try {
      final payload = {
        'lieu_id': lieuId,
        'auteur_id': userId,
        'etoiles': _note,
        'commentaire':
            _avisController.text.trim().isEmpty ? null : _avisController.text.trim(),
      };

      await _sb.from('avis_lieux').upsert(
            payload,
            onConflict: 'lieu_id,auteur_id',
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci pour votre avis !')),
      );
      setState(() {
        _note = 0;
        _avisController.clear();
      });
      await _loadAvisStats();
      await _loadAvisCommentaires(); // rafraîchit la liste + profils
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur avis: ${e.message}')),
      );
    }
  }

  // ----------------- Téléphone + Maps -----------------
  void _callPhone() async {
    final raw =
        (widget.lieu['contact'] ?? widget.lieu['telephone'] ?? '').toString();
    final phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Numéro non disponible ou invalide")),
    );
  }

  void _openMap() async {
    final lat = (widget.lieu['latitude'] as num?)?.toDouble();
    final lon = (widget.lieu['longitude'] as num?)?.toDouble();
    if (lat != null && lon != null) {
      final uri = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=$lat,$lon");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Coordonnées GPS non disponibles")),
    );
  }

  // ----------------- Images -----------------
  List<String> _images(Map<String, dynamic> lieu) {
    if (lieu['images'] is List && (lieu['images'] as List).isNotEmpty) {
      return (lieu['images'] as List).map((e) => e.toString()).toList();
    }
    final p = lieu['photo_url']?.toString() ?? '';
    return p.isNotEmpty ? [p] : [];
  }

  // ----------------- Plein écran -----------------
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
                    heroAttributes:
                        PhotoViewHeroAttributes(tag: 'divert_$index'),
                  );
                },
                onPageChanged: (i) => setS(() => current = i),
                backgroundDecoration:
                    const BoxDecoration(color: Colors.black),
              ),
              Positioned(
                top: 24,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
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
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  // ----------------- UI helpers -----------------
  Widget _starsFromAverage(double avg, {double size = 18}) {
    final n = avg.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < n ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        ),
      ),
    );
  }

  Widget _starsFromInt(int n, {double size = 16}) {
    final clamped = n.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < clamped ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lieu = widget.lieu;
    final horaires = (lieu['horaires'] ?? "Non renseigné").toString();
    final images = _images(lieu);

    final String nom = (lieu['nom'] ?? '').toString();
    final String ville = (lieu['ville'] ?? '').toString();
    final String ambiance =
        (lieu['categorie'] ?? lieu['type'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(nom, overflow: TextOverflow.ellipsis),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0.8,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Barre d’actions
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
                  onPressed: _callPhone,
                  icon: const Icon(Icons.phone, size: 18, color: kPrimary),
                  label: const Text(
                    "Contacter",
                    style:
                        TextStyle(color: kPrimary, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kPrimary, width: 1.5),
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
                  onPressed: _openMap,
                  icon: const Icon(Icons.map, size: 18, color: Colors.white),
                  label: const Text(
                    "Itinéraire",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
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

      // Contenu
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- Galerie ----------
            if (images.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (i) =>
                            setState(() => _currentImage = i),
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () =>
                              _openFullScreenGallery(images, index),
                          child: Hero(
                            tag: 'divert_$index',
                            child: Image.network(
                              images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(Icons.image_not_supported),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (images.length > 1)
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
                            '${_currentImage + 1}/${images.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (images.length > 1)
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isActive = index == _currentImage;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          );
                          setState(() => _currentImage = index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive
                                  ? kPrimary
                                  : Colors.transparent,
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
            ] else
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 60),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ---------- Infos ----------
            Text(nom,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (ambiance.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ambiance,
                  style:
                      const TextStyle(fontSize: 15, color: Colors.grey)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.location_on, color: kPrimary, size: 21),
                const SizedBox(width: 7),
                Text(ville,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time, color: kPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    horaires,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ---------- Bloc note moyenne ----------
            if (_loadingAvis)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  if (_noteMoyenne != null)
                    _starsFromAverage(_noteMoyenne!, size: 18),
                  if (_noteMoyenne != null) const SizedBox(width: 8),
                  Text(
                    _noteMoyenne != null
                        ? '${_noteMoyenne!.toStringAsFixed(2)} / 5'
                        : 'Aucune note',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Text('($_nbAvis avis)',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),

            const Divider(height: 30),

            // ---------- Liste des commentaires ----------
            const Text("Avis des utilisateurs",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_loadingCommentaires)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_avisList.isEmpty)
              const Text(
                "Aucun commentaire pour le moment.",
                style: TextStyle(color: Colors.grey),
              )
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _avisList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final r = _avisList[idx];
                  final int etoiles = (r['etoiles'] as num?)?.toInt() ?? 0;
                  final String commentaire = (r['commentaire'] ?? '').toString();
                  final String auteurId = (r['auteur_id'] ?? '').toString();
                  final u = _usersById[auteurId] ?? const {};
                  final prenom = (u['prenom'] ?? '').toString();
                  final nomU = (u['nom'] ?? '').toString();
                  final avatarUrl = (u['photo_url'] ?? '').toString();
                  final fullName =
                      ('$prenom $nomU').trim().isEmpty ? 'Utilisateur' : ('$prenom $nomU').trim();
                  final String dateShort = (() {
                    final raw = r['created_at']?.toString();
                    if (raw == null) return '';
                    return raw.length >= 10 ? raw.substring(0, 10) : raw;
                  })();

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: const Color(0xFFEAEAEA)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(Icons.person, size: 18)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  _starsFromInt(etoiles, size: 14),
                                ],
                              ),
                            ),
                            if (dateShort.isNotEmpty)
                              Text(dateShort,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          commentaire,
                          style: const TextStyle(fontSize: 14.5),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const Divider(height: 32),

            // ---------- Saisie avis ----------
            const Text("Notez ce lieu :",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(index < _note ? Icons.star : Icons.star_border,
                      color: Colors.amber),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                fillColor: Colors.grey[100],
                filled: true,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _submitAvis,
              icon: const Icon(Icons.send),
              label: const Text("Envoyer l'avis"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
