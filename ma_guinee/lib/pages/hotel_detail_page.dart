// lib/pages/hotel_detail_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'hotel_reservation_page.dart';

class HotelDetailPage extends StatefulWidget {
  final dynamic hotelId;
  const HotelDetailPage({super.key, required this.hotelId});

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  final _sb = Supabase.instance.client;

  static const Color hotelsPrimary = Color(0xFF264653);
  static const Color hotelsSecondary = Color(0xFF2A9D8F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color neutralBorder = Color(0xFFE5E7EB);

  static const Color _neutralBg = Color(0xFFF7F7F9);
  static const Color _neutralSurface = Color(0xFFFFFFFF);

  Map<String, dynamic>? hotel;
  bool loading = true;
  String? _error;

  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  double _noteMoyenne = 0;
  List<Map<String, dynamic>> _avis = [];
  final Map<String, Map<String, dynamic>> _userCache = {};

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  String get _id => widget.hotelId.toString();
  bool _isUuid(String id) => RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
      .hasMatch(id);

  @override
  void initState() {
    super.initState();
    _loadHotel();
    _loadAvisBloc();
  }

  @override
  void dispose() {
    _avisController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _formatGNF(dynamic value) {
    if (value == null) return '—';
    final n = (value is num)
        ? value.toInt()
        : int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  String _fmtDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} • ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _loadHotel() async {
    setState(() {
      loading = true;
      _error = null;
    });

    try {
      final data =
          await _sb.from('hotels').select().eq('id', _id).maybeSingle();

      if (!mounted) return;
      setState(() {
        hotel = data == null ? null : Map<String, dynamic>.from(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadAvisBloc() async {
    try {
      final rows = await _sb
          .from('avis_hotels')
          .select('auteur_id, etoiles, commentaire, created_at')
          .eq('hotel_id', _id)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(rows);

      double moyenne = 0.0;
      if (list.isNotEmpty) {
        final notes =
            list.map((e) => (e['etoiles'] as num?)?.toDouble() ?? 0.0).toList();
        moyenne = notes.fold<double>(0.0, (a, b) => a + b) / notes.length;
      }

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
            .select('id, nom, prenom, photo_url')
            .or(orFilter);

        for (final p in List<Map<String, dynamic>>.from(profs)) {
          final id = (p['id'] ?? '').toString();
          fetched[id] = {
            'nom': (p['nom'] ?? '').toString(),
            'prenom': (p['prenom'] ?? '').toString(),
            'photo_url': (p['photo_url'] ?? '').toString(),
          };
        }
      }

      if (!mounted) return;
      setState(() {
        _avis = list;
        _noteMoyenne = moyenne;
        _userCache
          ..clear()
          ..addAll(fetched);
      });
    } catch (_) {
      // silencieux comme avant
    }
  }

  Future<void> _envoyerAvis() async {
    final commentaire = _avisController.text.trim();
    if (_noteUtilisateur == 0 || commentaire.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Veuillez noter et écrire un commentaire.")),
      );
      return;
    }

    final user = _sb.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connectez-vous pour laisser un avis.")),
      );
      return;
    }

    if (!_isUuid(_id)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur : ID hôtel invalide.")),
      );
      return;
    }

    try {
      await _sb.from('avis_hotels').upsert(
        {
          'hotel_id': _id,
          'auteur_id': user.id,
          'etoiles': _noteUtilisateur,
          'commentaire': commentaire,
        },
        onConflict: 'hotel_id,auteur_id',
      );

      FocusManager.instance.primaryFocus?.unfocus();

      _avisController.clear();
      setState(() => _noteUtilisateur = 0);

      await _loadAvisBloc();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avis envoyé.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur envoi avis : $e")),
      );
    }
  }

  void _contacter() async {
    final tel = (hotel?['telephone'] ?? hotel?['tel'] ?? hotel?['phone'] ?? '')
        .toString()
        .trim();
    if (tel.isEmpty) return;

    final cleaned = tel.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _localiser() async {
    final lat = (hotel?['latitude'] as num?)?.toDouble();
    final lon = (hotel?['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return;

    final uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lon",
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<String> _imagesFromHotel() {
    final raw = hotel?['images'];

    List<String> normalize(List list) => list
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (raw is List && raw.isNotEmpty) {
      return normalize(raw);
    }

    if (raw is String) {
      final s = raw.trim();
      if (s.isNotEmpty) {
        if (s.startsWith('[')) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is List) return normalize(decoded);
          } catch (_) {}
        }
        if (s.contains(',')) {
          final parts = s.split(',').map((e) => e.trim()).toList();
          final out = parts.where((e) => e.isNotEmpty).toList();
          if (out.isNotEmpty) return out;
        }
        return [s];
      }
    }

    final p = (hotel?['photo_url'] ?? '').toString().trim();
    return p.isNotEmpty ? [p] : [];
  }

  void _openFullScreenGallery(List<String> images, int index) {
    if (images.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenGalleryPage(
          images: images,
          initialIndex: index,
          heroPrefix: 'hotel_${_id}_',
        ),
      ),
    );
  }

  // ---------- UI helpers ----------
  Widget _starsStatic(double avg, {double size = 16}) {
    final full = avg.floor().clamp(0, 5);
    final half = (avg - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) {
          return Icon(Icons.star, size: size, color: Colors.amber);
        }
        if (i == full && half) {
          return Icon(Icons.star_half, size: size, color: Colors.amber);
        }
        return Icon(Icons.star_border, size: size, color: Colors.amber);
      }),
    );
  }

  Widget _starsPick(int rating, {required void Function(int) onTap}) {
    return Row(
      children: List.generate(5, (i) {
        final active = i < rating;
        return IconButton(
          iconSize: 28,
          onPressed: () => onTap(i + 1),
          icon: Icon(active ? Icons.star : Icons.star_border,
              color: Colors.amber),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (hotel?['nom'] ?? 'Hôtel').toString();

    return Scaffold(
      backgroundColor: _neutralBg,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _neutralSurface,
        titleTextStyle: const TextStyle(
          color: hotelsPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: hotelsPrimary),
        elevation: 1,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: SizedBox(
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [hotelsPrimary, hotelsSecondary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ),
      ),

      // ✅ Tap partout = ferme le clavier (sans casser le scroll)
      body: Listener(
        onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: loading
            ? _buildSkeletonBody()
            : (hotel == null
                ? Center(
                    child: Text(
                      _error == null ? "Hôtel introuvable" : "Erreur : $_error",
                    ),
                  )
                : _buildDetailBody()),
      ),

      bottomNavigationBar:
          (!loading && hotel != null) ? _buildBottomBar() : null,
    );
  }

  Widget _buildSkeletonBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 240,
              width: double.infinity,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 16, width: 180, color: Colors.grey.shade200),
          const SizedBox(height: 8),
          Container(height: 16, width: 220, color: Colors.grey.shade200),
          const SizedBox(height: 8),
          Container(
              height: 14, width: double.infinity, color: Colors.grey.shade200),
          const SizedBox(height: 6),
          Container(
              height: 14, width: double.infinity, color: Colors.grey.shade200),
          const SizedBox(height: 6),
          Container(height: 14, width: 160, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildDetailBody() {
    final images = _imagesFromHotel();

    final nom = (hotel?['nom'] ?? 'Hôtel').toString();
    final ville = (hotel?['ville'] ?? 'Non précisé').toString();
    final prix = hotel?['prix'];
    final desc = (hotel?['description'] ?? 'Aucune description').toString();

    final canSend =
        _noteUtilisateur > 0 && _avisController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1) Galerie
          if (images.isNotEmpty) ...[
            _buildProGallery(images, nom),
            const SizedBox(height: 14),
          ] else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 240,
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 60),
                ),
              ),
            ),

          // 2) Titre + ville
          Text(
            nom,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Colors.red),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  ville,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3) Prix
          Text(
            "Prix moyen : ${_formatGNF(prix)} GNF / nuit",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 10),

          // 4) Description
          Text(
            "Description :\n$desc",
            style: const TextStyle(height: 1.35),
          ),

          // 5) ✅ Bar note moyenne SOUS la description
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: neutralBorder),
            ),
            child: Row(
              children: [
                _noteMoyenne > 0
                    ? Row(
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
                        ],
                      )
                    : const Text(
                        "Aucun avis pour le moment",
                        style: TextStyle(color: Colors.black54),
                      ),
                const Spacer(),
                const Icon(Icons.verified, size: 18, color: hotelsSecondary),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 24),

          // 6) Localisation (bouton)
          const Text(
            "Localisation",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _localiser,
            icon: const Icon(Icons.map),
            label: const Text("Localiser"),
            style: ElevatedButton.styleFrom(
              backgroundColor: hotelsSecondary,
              foregroundColor: onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 22),
          const Divider(height: 24),

          // 7) ✅ Avis des utilisateurs (AU-DESSUS de “Votre avis”)
          const Text(
            "Avis des utilisateurs",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),

          if (_avis.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text("Aucun avis pour le moment."),
            )
          else
            Column(
              children: _avis.map((a) {
                final uid = (a['auteur_id'] ?? '').toString();
                final u = _userCache[uid] ?? const {};
                final prenom = (u['prenom'] ?? '').toString();
                final nomU = (u['nom'] ?? '').toString();
                final photo = (u['photo_url'] ?? '').toString();
                final fullName = ('$prenom $nomU').trim().isNotEmpty
                    ? ('$prenom $nomU').trim()
                    : 'Utilisateur';

                final etoiles = (a['etoiles'] as num?)?.toDouble() ?? 0.0;
                final commentaire = (a['commentaire'] ?? '').toString().trim();
                final dateStr = _fmtDate(a['created_at']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: neutralBorder),
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
                                      fontWeight: FontWeight.w700,
                                    ),
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

          const SizedBox(height: 22),
          const Divider(height: 24),

          // 8) ✅ Votre avis (TOUT EN BAS)
          const Text(
            "Votre avis",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),

          _starsPick(_noteUtilisateur,
              onTap: (n) => setState(() => _noteUtilisateur = n)),

          TextField(
            controller: _avisController,
            minLines: 3,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _envoyerAvis(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Partagez votre expérience...",
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: neutralBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: neutralBorder),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: canSend ? _envoyerAvis : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text("Envoyer"),
              style: ElevatedButton.styleFrom(
                backgroundColor: hotelsSecondary,
                foregroundColor: onPrimary,
                disabledBackgroundColor: hotelsSecondary.withOpacity(0.35),
                disabledForegroundColor: onPrimary.withOpacity(0.8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProGallery(List<String> images, String title) {
    final heroPrefix = 'hotel_${_id}_';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              SizedBox(
                height: 240,
                width: double.infinity,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (context, index) {
                    final url = images[index];
                    return GestureDetector(
                      onTap: () => _openFullScreenGallery(images, index),
                      child: Hero(
                        tag: '${heroPrefix}$index',
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image,
                                color: Colors.black26, size: 42),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Gradient overlay bas + titre
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.55),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildDots(images.length, _currentIndex),
                    ],
                  ),
                ),
              ),

              // Compteur top-right
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.40),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
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

        // Thumbnails
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isActive = index == _currentIndex;
                return GestureDetector(
                  onTap: () {
                    _pageController.jumpToPage(index);
                    setState(() => _currentIndex = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? hotelsPrimary : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image,
                            color: Colors.black26, size: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDots(int count, int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(left: 5),
          width: active ? 14 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    final nom = (hotel?['nom'] ?? 'Hôtel').toString();
    final telRaw =
        (hotel?['telephone'] ?? hotel?['tel'] ?? hotel?['phone'] ?? '')
            .toString()
            .trim();
    final address = (hotel?['adresse'] ?? hotel?['ville'] ?? '').toString();
    final images = _imagesFromHotel();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: _neutralSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _contacter,
                icon: const Icon(Icons.chat),
                label: const Text("Contacter"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hotelsSecondary,
                  foregroundColor: onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _ouvrirReservation(
                  nom: nom,
                  telRaw: telRaw,
                  address: address,
                  images: images,
                ),
                icon: const Icon(Icons.calendar_today),
                label: const Text("Réserver"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hotelsPrimary,
                  foregroundColor: onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _ouvrirReservation({
    required String nom,
    required String telRaw,
    required String address,
    required List<String> images,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelReservationPage(
          hotelId: _id,
          hotelName: nom.isEmpty ? 'Hôtel' : nom,
          phone: telRaw.isEmpty ? null : telRaw,
          address: address.isEmpty ? null : address,
          coverImage: images.isNotEmpty ? images.first : null,
          primaryColor: hotelsPrimary,
        ),
      ),
    );
  }
}

/* ===========================
   FULLSCREEN VIEWER (OK)
   =========================== */

class _FullscreenGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroPrefix; // ex: 'hotel_<id>_'

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

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
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
        title: Text(
          '${_index + 1}/$total',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: total,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          return Center(
            child: Hero(
              tag: '${widget.heroPrefix}$i',
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: widget.images[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(color: Colors.black),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
