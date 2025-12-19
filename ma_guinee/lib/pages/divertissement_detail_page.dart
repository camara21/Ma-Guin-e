// lib/pages/divertissement/divertissement_detail_page.dart
import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ orientation lock (si tu l’utilises après)
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Centralisation erreurs (offline/supabase/timeout + overlay anti-spam)
import 'package:ma_guinee/utils/error_messages_fr.dart';

class DivertissementDetailPage extends StatefulWidget {
  final Map<String, dynamic> lieu;
  const DivertissementDetailPage({super.key, required this.lieu});

  @override
  State<DivertissementDetailPage> createState() =>
      _DivertissementDetailPageState();
}

class _DivertissementDetailPageState extends State<DivertissementDetailPage> {
  static const Color kPrimary = Colors.deepPurple;
  static const Color _neutralBorder = Color(0xFFE5E7EB);
  static const Color _neutralSurface = Colors.white;

  final _sb = Supabase.instance.client;

  // ✅ Anti-flash : Hero uniquement sur mobile (Android/iOS)
  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _enableHero => _isMobilePlatform;

  // Avis (édition)
  int _note = 0;
  final TextEditingController _avisController = TextEditingController();
  bool _submittingAvis = false;

  // Stats avis
  double? _noteMoyenne;
  int _nbAvis = 0;
  bool _loadingAvis = true;

  // Commentaires + profils
  bool _loadingCommentaires = true;
  List<Map<String, dynamic>> _avisList = [];
  final Map<String, Map<String, dynamic>> _usersById = {};

  // Galerie
  final PageController _pageController = PageController();
  int _currentImage = 0;

  bool get _canSubmitAvis =>
      !_submittingAvis && _note > 0 && _avisController.text.trim().isNotEmpty;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _handleError(Object e, StackTrace st, {String? fallbackSnack}) {
    // ✅ Centralisation + message FR
    SoneyaErrorCenter.showException(e, st);
    _snack(fallbackSnack ?? frMessageFromError(e, st));
  }

  Future<void> _precacheAll(BuildContext context, List<String> urls) async {
    for (final u in urls) {
      unawaited(precacheImage(NetworkImage(u), context).catchError((_) {}));
    }
  }

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

    _avisController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final imgs = _images(widget.lieu);
    if (imgs.isNotEmpty) _precacheAll(context, imgs);
  }

  @override
  void dispose() {
    _avisController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ----------------- SUPABASE: Avis (stats) -----------------
  Future<void> _loadAvisStats() async {
    if (mounted) setState(() => _loadingAvis = true);
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

      // ✅ réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      if (!mounted) return;
      _noteMoyenne = null;
      _nbAvis = 0;
      _handleError(
        e as Object,
        st,
        fallbackSnack: "Impossible de charger les avis. Veuillez réessayer.",
      );
    } finally {
      if (mounted) setState(() => _loadingAvis = false);
    }
  }

  // ----------------- SUPABASE: Avis (liste + profils) -----------------
  Future<void> _loadAvisCommentaires() async {
    if (mounted) setState(() => _loadingCommentaires = true);
    try {
      final lieuId = widget.lieu['id']?.toString();
      if (lieuId == null || !_isUuid(lieuId)) {
        _avisList = [];
      } else {
        final rows = await _sb
            .from('avis_lieux')
            .select('auteur_id, etoiles, commentaire, created_at')
            .eq('lieu_id', lieuId)
            .order('created_at', ascending: false)
            .limit(20);

        final list = List<Map<String, dynamic>>.from(rows);

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

        _avisList = list
            .where((r) =>
                (r['commentaire']?.toString().trim().isNotEmpty ?? false))
            .toList();
      }

      // ✅ réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      if (!mounted) return;
      _avisList = [];
      _handleError(
        e as Object,
        st,
        fallbackSnack:
            "Impossible de charger les commentaires. Veuillez réessayer.",
      );
    } finally {
      if (mounted) setState(() => _loadingCommentaires = false);
    }
  }

  Future<void> _submitAvis() async {
    if (_submittingAvis) return;

    final userId = _sb.auth.currentUser?.id;
    final lieuId = widget.lieu['id']?.toString();
    final commentaire = _avisController.text.trim();

    if (userId == null) {
      _snack("Veuillez vous connecter pour laisser un avis.");
      return;
    }
    if (lieuId == null || lieuId.isEmpty) {
      _snack("Lieu invalide.");
      return;
    }
    if (_note <= 0) {
      _snack("Choisissez une note (au moins 1 étoile).");
      return;
    }
    if (commentaire.isEmpty) {
      _snack("Écrivez un commentaire avant d’envoyer.");
      return;
    }

    try {
      if (mounted) setState(() => _submittingAvis = true);

      await _sb.from('avis_lieux').upsert(
        {
          'lieu_id': lieuId,
          'auteur_id': userId,
          'etoiles': _note,
          'commentaire': commentaire,
        },
        onConflict: 'lieu_id,auteur_id',
      );

      FocusManager.instance.primaryFocus?.unfocus();

      if (!mounted) return;
      _snack('Merci pour votre avis !');

      setState(() {
        _note = 0;
        _avisController.clear();
      });

      await _loadAvisStats();
      await _loadAvisCommentaires();

      // ✅ réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      if (!mounted) return;
      _handleError(
        e as Object,
        st,
        fallbackSnack: "Impossible d’envoyer votre avis. Veuillez réessayer.",
      );
    } finally {
      if (mounted) setState(() => _submittingAvis = false);
    }
  }

  // ----------------- Téléphone + Maps -----------------
  void _callPhone() async {
    final raw =
        (widget.lieu['contact'] ?? widget.lieu['telephone'] ?? '').toString();
    final phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          SoneyaErrorCenter.reportNetworkSuccess();
          return;
        }
      } catch (e, st) {
        _handleError(e as Object, st, fallbackSnack: "Impossible d'appeler.");
        return;
      }
    }
    if (!mounted) return;
    _snack("Numéro non disponible ou invalide");
  }

  void _openMap() async {
    final lat = (widget.lieu['latitude'] as num?)?.toDouble();
    final lon = (widget.lieu['longitude'] as num?)?.toDouble();
    if (lat != null && lon != null) {
      final uri = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=$lat,$lon");
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          SoneyaErrorCenter.reportNetworkSuccess();
          return;
        }
      } catch (e, st) {
        _handleError(
          e as Object,
          st,
          fallbackSnack: "Impossible d'ouvrir Google Maps.",
        );
        return;
      }
    }
    if (!mounted) return;
    _snack("Coordonnées GPS non disponibles");
  }

  // ----------------- Images -----------------
  List<String> _images(Map<String, dynamic> lieu) {
    final raw = lieu['images'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .map((e) => (e ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final p = (lieu['photo_url']?.toString() ?? '').trim();
    return p.isNotEmpty ? [p] : [];
  }

  // ✅ Anti-flash : route instantanée (pas d’animation) + Hero seulement mobile
  void _openFullScreenGallery(List<String> images, int initialIndex) {
    final heroPrefix =
        'divert_${widget.lieu['id'] ?? (widget.lieu['nom'] ?? '')}';

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => _FullscreenGalleryPage(
          images: images,
          initialIndex: initialIndex,
          heroPrefix: heroPrefix,
          enableHero: _enableHero,
        ),
      ),
    );
  }

  // ----------------- UI helpers -----------------
  Widget _starsAverage(double avg, {double size = 16}) {
    final full = avg.floor().clamp(0, 5);
    final half = (avg - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return Icon(Icons.star, color: Colors.amber, size: size);
        if (i == full && half) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        }
        return Icon(Icons.star_border, color: Colors.amber, size: size);
      }),
    );
  }

  Widget _starsFromInt(int n, {double size = 14}) {
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

  Widget _avgRatingBar() {
    if (_loadingAvis) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _neutralSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutralBorder),
      ),
      child: Row(
        children: [
          if (_noteMoyenne != null) _starsAverage(_noteMoyenne!, size: 16),
          if (_noteMoyenne != null) const SizedBox(width: 8),
          Text(
            _noteMoyenne != null
                ? '${_noteMoyenne!.toStringAsFixed(1)} / 5'
                : 'Aucune note',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '($_nbAvis avis)',
            style: const TextStyle(color: Colors.black54),
          ),
          const Spacer(),
          const Icon(Icons.verified, size: 18, color: kPrimary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lieu = widget.lieu;

    final images = _images(lieu);
    final String nom = (lieu['nom'] ?? '').toString();
    final String ville = (lieu['ville'] ?? '').toString();
    final String ambiance =
        (lieu['categorie'] ?? lieu['type'] ?? '').toString();
    final String horaires = (lieu['horaires'] ?? "Non renseigné").toString();
    final String description = (lieu['description'] ?? '').toString().trim();

    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);

    // ✅ tags stables + uniques
    final heroPrefix = 'divert_${lieu['id'] ?? nom}';

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(nom, overflow: TextOverflow.ellipsis),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0.8,
          iconTheme: const IconThemeData(color: Colors.white),
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
                    onPressed: _callPhone,
                    icon: const Icon(Icons.phone, size: 18, color: kPrimary),
                    label: const Text(
                      "Contacter",
                      style: TextStyle(
                        color: kPrimary,
                        fontWeight: FontWeight.w700,
                      ),
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
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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
        body: Listener(
          onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ GALERIE (anti-flash : Hero mobile only)
                if (images.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 230,
                          width: double.infinity,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: images.length,
                            onPageChanged: (i) =>
                                setState(() => _currentImage = i),
                            itemBuilder: (context, index) {
                              final child = GestureDetector(
                                onTap: () =>
                                    _openFullScreenGallery(images, index),
                                child: _FadeInNetworkImage(url: images[index]),
                              );

                              if (!_enableHero) return child;

                              return Hero(
                                tag: '${heroPrefix}_$index',
                                transitionOnUserGestures: true,
                                child: child,
                              );
                            },
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

                  // Miniatures
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
                                  color:
                                      isActive ? kPrimary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox.expand(
                                child: Image.network(
                                  images[index],
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[200],
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image),
                                  ),
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
                      height: 230,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 60),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                Text(
                  nom,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (ambiance.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    ambiance,
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: kPrimary, size: 21),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        ville,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.access_time, color: kPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child:
                          Text(horaires, style: const TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 15, height: 1.35),
                  ),
                ],
                const SizedBox(height: 12),
                _avgRatingBar(),

                const Divider(height: 30),
                const Text(
                  "Avis des utilisateurs",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

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
                      final String commentaire =
                          (r['commentaire'] ?? '').toString();
                      final String auteurId = (r['auteur_id'] ?? '').toString();
                      final u = _usersById[auteurId] ?? const {};
                      final prenom = (u['prenom'] ?? '').toString();
                      final nomU = (u['nom'] ?? '').toString();
                      final avatarUrl = (u['photo_url'] ?? '').toString();
                      final fullName = ('$prenom $nomU').trim().isEmpty
                          ? 'Utilisateur'
                          : ('$prenom $nomU').trim();
                      final String dateShort = (() {
                        final raw = r['created_at']?.toString();
                        if (raw == null) return '';
                        return raw.length >= 10 ? raw.substring(0, 10) : raw;
                      })();

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _neutralBorder),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl.isEmpty
                                      ? const Icon(Icons.person, size: 18)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      _starsFromInt(etoiles, size: 14),
                                    ],
                                  ),
                                ),
                                if (dateShort.isNotEmpty)
                                  Text(
                                    dateShort,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              commentaire,
                              style:
                                  const TextStyle(fontSize: 14.5, height: 1.3),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const Divider(height: 32),
                const Text(
                  "Votre avis",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < _note ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () => setState(() => _note = index + 1),
                      splashRadius: 21,
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _avisController,
                  maxLines: 3,
                  textInputAction: _canSubmitAvis
                      ? TextInputAction.send
                      : TextInputAction.newline,
                  onSubmitted: (_) {
                    if (_canSubmitAvis) _submitAvis();
                  },
                  decoration: InputDecoration(
                    hintText: "Écrivez votre avis ici...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _neutralBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _neutralBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kPrimary, width: 1.3),
                    ),
                    fillColor: Colors.grey[100],
                    filled: true,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _canSubmitAvis ? _submitAvis : null,
                    icon: _submittingAvis
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(_submittingAvis ? "Envoi..." : "Envoyer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: kPrimary.withOpacity(0.35),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 18),
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
      ),
    );
  }
}

// ------------------------------------------------------------
// Image stable (comme Tourisme)
// ------------------------------------------------------------
class _FadeInNetworkImage extends StatefulWidget {
  final String url;
  const _FadeInNetworkImage({required this.url});

  @override
  State<_FadeInNetworkImage> createState() => _FadeInNetworkImageState();
}

class _FadeInNetworkImageState extends State<_FadeInNetworkImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _ctrl.value = 0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.network(
        widget.url,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        gaplessPlayback: true,
        loadingBuilder: (ctx, child, ev) {
          if (ev == null) {
            _ctrl.forward();
            return FadeTransition(opacity: _fade, child: child);
          }
          return const _ImagePlaceholder();
        },
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Color(0xFFE5E7EB),
          child: Center(
              child: Icon(Icons.broken_image, size: 44, color: Colors.black26)),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE5E7EB),
      child: Center(child: Icon(Icons.image, size: 40, color: Colors.black26)),
    );
  }
}

// --------- Page plein écran (swipe + zoom, fond noir) ---------
class _FullscreenGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroPrefix;
  final bool enableHero;

  const _FullscreenGalleryPage({
    required this.images,
    required this.initialIndex,
    required this.heroPrefix,
    required this.enableHero,
  });

  @override
  State<_FullscreenGalleryPage> createState() => _FullscreenGalleryPageState();
}

class _FullscreenGalleryPageState extends State<_FullscreenGalleryPage> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _ctrl = PageController(initialPage: _index);
  }

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
          final url = widget.images[i].trim();

          final content = Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, ev) {
                  if (ev == null) return child;
                  return const ColoredBox(color: Colors.black);
                },
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white70,
                  size: 64,
                ),
              ),
            ),
          );

          if (!widget.enableHero) return content;

          return Hero(
            tag: '${widget.heroPrefix}_$i',
            child: content,
          );
        },
      ),
    );
  }
}
