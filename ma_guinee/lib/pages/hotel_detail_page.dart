import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'hotel_reservation_page.dart';

class HotelDetailPage extends StatefulWidget {
  final dynamic hotelId; // UUID (String) ou autre -> stringifié
  const HotelDetailPage({super.key, required this.hotelId});

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  final _sb = Supabase.instance.client;

  static const Color hotelsPrimary   = Color(0xFF264653);
  static const Color hotelsSecondary = Color(0xFF2A9D8F);
  static const Color onPrimary       = Color(0xFFFFFFFF);
  static const Color neutralBorder   = Color(0xFFE5E7EB);

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
    setState(() { loading = true; _error = null; });
    try {
      final data = await _sb.from('hotels').select().eq('id', _id).maybeSingle();
      if (!mounted) return;
      setState(() { hotel = data == null ? null : Map<String, dynamic>.from(data); loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; _error = e.toString(); });
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
        final notes = list.map((e) => (e['etoiles'] as num?)?.toDouble() ?? 0.0).toList();
        moyenne = notes.reduce((a, b) => a + b) / notes.length;
      }

      final ids = list.map((e) => e['auteur_id']).whereType<String>().where(_isUuid).toSet().toList();
      Map<String, Map<String, dynamic>> fetched = {};
      if (ids.isNotEmpty) {
        final orFilter = ids.map((id) => 'id.eq.$id').join(',');
        final profs = await _sb.from('utilisateurs').select('id, nom, prenom, photo_url').or(orFilter);
        for (final p in List<Map<String, dynamic>>.from(profs)) {
          final id = (p['id'] ?? '').toString();
          fetched[id] = {'nom': p['nom'], 'prenom': p['prenom'], 'photo_url': p['photo_url']};
        }
      }

      if (!mounted) return;
      setState(() { _avis = list; _noteMoyenne = moyenne; _userCache..clear()..addAll(fetched); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur chargement avis: $e')));
    }
  }

  Future<void> _envoyerAvis() async {
    final commentaire = _avisController.text.trim();
    if (_noteUtilisateur == 0 || commentaire.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez donner une note et un avis.")));
      return;
    }
    final user = _sb.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connectez-vous pour laisser un avis.")));
      return;
    }
    if (!_isUuid(_id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID hôtel invalide.")));
      return;
    }

    try {
      await _sb.from('avis_hotels').upsert(
        {'hotel_id': _id, 'auteur_id': user.id, 'etoiles': _noteUtilisateur, 'commentaire': commentaire},
        onConflict: 'hotel_id,auteur_id',
      );

      _avisController.clear();
      setState(() => _noteUtilisateur = 0);
      await _loadAvisBloc();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Merci pour votre avis !")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur envoi avis: $e")));
    }
  }

  void _contacter() async {
    final tel = (hotel?['telephone'] ?? hotel?['tel'] ?? hotel?['phone'] ?? '').toString().trim();
    if (tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Numéro indisponible.")));
      return;
    }
    final cleaned = tel.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _localiser() async {
    final lat = (hotel?['latitude'] as num?)?.toDouble();
    final lon = (hotel?['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Coordonnées indisponibles.")));
      return;
    }
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<String> _imagesFromHotel() {
    final raw = hotel?['images'];
    if (raw is List && raw.isNotEmpty) return raw.map((e) => e.toString()).toList();
    final p = (hotel?['photo_url'] ?? '').toString();
    return p.isNotEmpty ? [p] : [];
  }

  void _openFullScreenGallery(List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenGalleryPage(images: images, initialIndex: initialIndex, heroPrefix: 'hotel'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (hotel == null) return const Scaffold(body: Center(child: Text("Hôtel introuvable")));

    final images = _imagesFromHotel();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text((hotel!['nom'] ?? '').toString()),
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: hotelsPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        iconTheme: const IconThemeData(color: hotelsPrimary),
        elevation: 1,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: SizedBox(
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [hotelsPrimary, hotelsSecondary], begin: Alignment.centerLeft, end: Alignment.centerRight),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                          tag: 'hotel_$index',
                          child: LayoutBuilder(
                            builder: (ctx, cons) {
                              final w = cons.maxWidth;
                              const h = 230.0;
                              return CachedNetworkImage(
                                imageUrl: images[index],
                                fit: BoxFit.cover,
                                memCacheWidth: w.isFinite ? (w * 2).round() : null,
                                memCacheHeight: (h * 2).round(),
                                placeholder: (_, __) => Container(color: Colors.grey[200]),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              );
                            },
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
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(14)),
                      child: Text('${_currentIndex + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
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
                        _pageController.animateToPage(index, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                        setState(() => _currentIndex = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isActive ? hotelsPrimary : Colors.transparent, width: 2),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: CachedNetworkImage(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[200]),
                          errorWidget: (_, __, ___) => Container(color: Colors.grey[200], alignment: Alignment.center, child: const Icon(Icons.broken_image)),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ] else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(height: 230, color: Colors.grey.shade300, child: const Center(child: Icon(Icons.image_not_supported, size: 60))),
            ),

          const SizedBox(height: 16),
          Text("Ville : ${(hotel!['ville'] ?? 'Non précisé').toString()}", style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final prix = hotel!['prix'];
            final p = _formatGNF(prix);
            return Text("Prix moyen : $p GNF / nuit", style: const TextStyle(fontSize: 16));
          }),
          const SizedBox(height: 8),
          Text("Description :\n${(hotel!['description'] ?? 'Aucune description').toString()}"),
          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _localiser,
              icon: const Icon(Icons.map),
              label: const Text("Localiser"),
              style: ElevatedButton.styleFrom(backgroundColor: hotelsSecondary, foregroundColor: onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),

          const SizedBox(height: 20),
          const Text("Avis client :", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(_avis.isEmpty ? "Pas d'avis" : "${_noteMoyenne.toStringAsFixed(1)} / 5"),

          const SizedBox(height: 10),
          const Text("Notez cet hôtel :", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(children: List.generate(5, (i) {
            return IconButton(
              icon: Icon(i < _noteUtilisateur ? Icons.star : Icons.star_border, color: Colors.amber),
              onPressed: () => setState(() => _noteUtilisateur = i + 1),
              iconSize: 28,
              splashRadius: 20,
            );
          })),
          TextField(
            controller: _avisController,
            maxLines: 3,
            decoration: InputDecoration(hintText: "Partagez votre expérience avec cet hôtel...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _envoyerAvis,
            icon: const Icon(Icons.send),
            label: const Text("Envoyer mon avis"),
            style: ElevatedButton.styleFrom(backgroundColor: hotelsSecondary, foregroundColor: onPrimary),
          ),

          const SizedBox(height: 20),
          if (_avis.isEmpty)
            const Text("Pas encore d'avis")
          else
            Column(
              children: _avis.map((avis) {
                final uid = (avis['auteur_id'] ?? '').toString();
                final u = _userCache[uid] ?? const <String, dynamic>{};
                final nom = "${(u['prenom'] ?? '').toString()} ${(u['nom'] ?? '').toString()}".trim();
                final note = (avis['etoiles'] as num?)?.toInt() ?? 0;
                final commentaire = (avis['commentaire'] ?? '').toString();
                final photo = (u['photo_url'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: neutralBorder), borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(radius: 22, backgroundImage: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null, child: photo.isEmpty ? const Icon(Icons.person) : null),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nom.isEmpty ? 'Utilisateur' : nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Row(children: List.generate(5, (i) => Icon(i < note ? Icons.star : Icons.star_border, size: 16, color: Colors.amber))),
                        const SizedBox(height: 5),
                        if (commentaire.isNotEmpty) Text(commentaire),
                      ]),
                    ),
                  ]),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
        ]),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))]),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _contacter,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text("Contacter"),
                  style: ElevatedButton.styleFrom(backgroundColor: hotelsSecondary, foregroundColor: onPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _ouvrirReservation,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text("Réserver"),
                  style: ElevatedButton.styleFrom(backgroundColor: hotelsPrimary, foregroundColor: onPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrirReservation() {
    final nom = (hotel?['nom'] ?? 'Hôtel').toString();
    final telRaw = (hotel?['telephone'] ?? hotel?['tel'] ?? hotel?['phone'] ?? '').toString().trim();
    final address = (hotel?['adresse'] ?? hotel?['ville'] ?? '').toString();
    final images = _imagesFromHotel();

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

/// Réutilisable
class _FullscreenGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroPrefix;
  const _FullscreenGalleryPage({required this.images, required this.initialIndex, required this.heroPrefix});

  @override
  State<_FullscreenGalleryPage> createState() => _FullscreenGalleryPageState();
}

class _FullscreenGalleryPageState extends State<_FullscreenGalleryPage> {
  late final PageController _ctrl = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), elevation: 0, title: Text('${_index + 1}/$total', style: const TextStyle(color: Colors.white))),
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
                minScale: 1.0, maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: url, fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70, size: 64),
                  placeholder: (_, __) => const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
