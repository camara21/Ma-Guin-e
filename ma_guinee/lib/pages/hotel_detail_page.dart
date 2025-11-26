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
  bool _isUuid(String id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id);

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
        moyenne = notes.reduce((a, b) => a + b) / notes.length;
      }

      final ids = list
          .map((e) => e['auteur_id'])
          .whereType<String>()
          .where(_isUuid)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> fetched = {};

      if (ids.isNotEmpty) {
        final orFilter = ids.map((id) => 'id.eq.$id').join(',');

        final profs = await _sb
            .from('utilisateurs')
            .select('id, nom, prenom, photo_url')
            .or(orFilter);

        for (final p in List<Map<String, dynamic>>.from(profs)) {
          fetched[p['id']] = {
            'nom': p['nom'],
            'prenom': p['prenom'],
            'photo_url': p['photo_url'],
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
    } catch (e) {}
  }

  Future<void> _envoyerAvis() async {
    final commentaire = _avisController.text.trim();
    if (_noteUtilisateur == 0 || commentaire.isEmpty) return;

    final user = _sb.auth.currentUser;
    if (user == null) return;

    if (!_isUuid(_id)) return;

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

      _avisController.clear();
      setState(() => _noteUtilisateur = 0);
      await _loadAvisBloc();
    } catch (e) {}
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

    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }

    final p = (hotel?['photo_url'] ?? '').toString();
    return p.isNotEmpty ? [p] : [];
  }

  void _openFullScreenGallery(List<String> images, int index) {
    if (images.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenGalleryPage(
          images: images,
          initialIndex: index,
          heroPrefix: 'hotel',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (hotel?['nom'] ?? 'Hôtel').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
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
      body: loading
          ? _buildSkeletonBody()
          : (hotel == null
              ? Center(
                  child: Text(
                    _error == null ? "Hôtel introuvable" : "Erreur : $_error",
                  ),
                )
              : _buildDetailBody()),
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 230,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      onPageChanged: (i) {
                        // TRANSITION INSTANTANÉE
                        setState(() => _currentIndex = i);
                      },
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => _openFullScreenGallery(images, index),
                        child: Hero(
                          tag: 'hotel_$index',
                          child: CachedNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: Colors.grey[200]),
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
                            const TextStyle(color: Colors.white, fontSize: 11),
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
                    final isActive = index == _currentIndex;

                    return GestureDetector(
                      onTap: () {
                        // TRANSITION INSTANTANÉE
                        _pageController.jumpToPage(index);
                        setState(() => _currentIndex = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                isActive ? hotelsPrimary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: CachedNetworkImage(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.grey[200]),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ] else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 230,
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 60),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            "Ville : ${(hotel!['ville'] ?? 'Non précisé').toString()}",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (_) {
              final prix = hotel!['prix'];
              return Text(
                "Prix moyen : ${_formatGNF(prix)} GNF / nuit",
                style: const TextStyle(fontSize: 16),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            "Description :\n${(hotel!['description'] ?? 'Aucune description').toString()}",
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _localiser,
            icon: const Icon(Icons.map),
            label: const Text("Localiser"),
            style: ElevatedButton.styleFrom(
              backgroundColor: hotelsSecondary,
              foregroundColor: onPrimary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Avis client :",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            _avis.isEmpty
                ? "Pas d'avis"
                : "${_noteMoyenne.toStringAsFixed(1)} / 5",
          ),
          const SizedBox(height: 10),
          const Text(
            "Notez cet hôtel :",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: List.generate(5, (i) {
              return IconButton(
                icon: Icon(
                  i < _noteUtilisateur ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => setState(() => _noteUtilisateur = i + 1),
                iconSize: 28,
              );
            }),
          ),
          TextField(
            controller: _avisController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Partagez votre expérience...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _envoyerAvis,
            icon: const Icon(Icons.send),
            label: const Text("Envoyer mon avis"),
            style: ElevatedButton.styleFrom(
              backgroundColor: hotelsSecondary,
              foregroundColor: onPrimary,
            ),
          ),
        ],
      ),
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
          color: Colors.white,
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
              tag: '${widget.heroPrefix}_$i',
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
