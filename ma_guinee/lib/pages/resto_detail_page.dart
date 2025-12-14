import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'restaurant_reservation_page.dart';

class RestoDetailPage extends StatefulWidget {
  final String restoId; // UUID du restaurant
  const RestoDetailPage({super.key, required this.restoId});

  @override
  State<RestoDetailPage> createState() => _RestoDetailPageState();
}

class _RestoDetailPageState extends State<RestoDetailPage> {
  final _sb = Supabase.instance.client;

  // Palette Restaurants
  static const Color _restoPrimary = Color(0xFFE76F51);
  static const Color _restoSecondary = Color(0xFFF4A261);
  static const Color _restoOnPrimary = Color(0xFFFFFFFF);
  static const Color _restoOnSecondary = Color(0xFF000000);

  // Neutres
  static const Color _neutralBg = Color(0xFFF7F7F9);
  static const Color _neutralSurface = Color(0xFFFFFFFF);
  static const Color _neutralBorder = Color(0xFFE5E7EB);

  Map<String, dynamic>? resto;
  bool loading = true;
  bool _syncing = false;
  String? _error;

  // Avis
  List<Map<String, dynamic>> _avis = [];
  double _noteMoyenne = 0.0;
  bool _dejaNote = false;

  // Profils cache
  final Map<String, Map<String, dynamic>> _userCache = {};

  // Saisie avis
  int _noteUtilisateur = 0;
  final _avisController = TextEditingController();

  // Galerie
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Map
  final MapController _mapController = MapController();
  LatLng _defaultCenter = const LatLng(9.5, -13.7);

  String get _id => widget.restoId;

  bool _isUuid(String id) {
    final r = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return r.hasMatch(id);
  }

  String _fmtDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} • ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  void initState() {
    super.initState();
    _loadResto();
    _loadAvisBloc();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _avisController.dispose();
    super.dispose();
  }

  // ---------------- Images helpers ----------------
  List<String> _imagesFrom(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      return raw
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    final p = (raw ?? '').toString().trim();
    return p.isNotEmpty ? [p] : [];
  }

  // ------- RESTO -------
  Future<void> _loadResto() async {
    setState(() {
      if (resto == null) loading = true;
      _syncing = resto != null;
      _error = null;
    });
    try {
      final data = await _sb
          .from('restaurants')
          .select(
              'id, nom, ville, description, specialites, horaires, images, latitude, longitude, tel, telephone')
          .eq('id', _id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        resto = data == null ? null : Map<String, dynamic>.from(data);
        loading = false;
        _syncing = false;
      });

      // Dès que les coordonnées arrivent → repositionner la carte
      final lat = (resto?['latitude'] as num?)?.toDouble();
      final lng = (resto?['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(LatLng(lat, lng), 15);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _syncing = false;
        _error = 'Erreur de chargement: $e';
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_error!)));
    }
  }

  // ------- AVIS -------
  Future<void> _loadAvisBloc() async {
    try {
      final res = await _sb
          .from('avis_restaurants')
          .select('auteur_id, etoiles, commentaire, created_at')
          .eq('restaurant_id', _id)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(res);

      double moyenne = 0.0;
      if (list.isNotEmpty) {
        final notes =
            list.map((e) => (e['etoiles'] as num?)?.toDouble() ?? 0.0).toList();
        moyenne = notes.fold<double>(0.0, (a, b) => a + b) / notes.length;
      }

      final user = _sb.auth.currentUser;
      final deja = user != null && list.any((a) => a['auteur_id'] == user.id);

      final ids = list
          .map((e) => e['auteur_id'])
          .whereType<String>()
          .where(_isUuid)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> fetched = {};
      if (ids.isNotEmpty) {
        final orFilter = ids.map((id) => 'id.eq.$id').join(',');
        final profiles = await _sb
            .from('utilisateurs')
            .select('id, nom, prenom, photo_url')
            .or(orFilter);

        for (final p in List<Map<String, dynamic>>.from(profiles)) {
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
        _dejaNote = deja;
        _userCache
          ..clear()
          ..addAll(fetched);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement avis: $e')),
      );
    }
  }

  Future<void> _envoyerAvis() async {
    final user = _sb.auth.currentUser;
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
      await _sb.from('avis_restaurants').upsert(
        {
          'restaurant_id': _id,
          'auteur_id': user.id,
          'etoiles': _noteUtilisateur,
          'commentaire': _avisController.text.trim(),
        },
        onConflict: 'restaurant_id,auteur_id',
      );

      // ferme clavier
      FocusManager.instance.primaryFocus?.unfocus();

      setState(() {
        _noteUtilisateur = 0;
        _avisController.clear();
        _dejaNote = true;
      });

      await _loadAvisBloc();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avis enregistré.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi de l'avis: $e")),
      );
    }
  }

  // ------- Actions -------
  void _reserver() {
    final nom = (resto?['nom'] ?? '').toString();
    final telRaw =
        (resto?['tel'] ?? resto?['telephone'] ?? '').toString().trim();
    final images = _imagesFrom(resto?['images']);
    final address = (resto?['ville'] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantReservationPage(
          restaurantId: _id,
          restoName: nom.isEmpty ? 'Restaurant' : nom,
          phone: telRaw.isEmpty ? null : telRaw,
          address: address.isEmpty ? null : address,
          coverImage: images.isNotEmpty ? images.first : null,
          primaryColor: _restoPrimary,
        ),
      ),
    );
  }

  void _appeler() async {
    final telRaw =
        (resto?['tel'] ?? resto?['telephone'] ?? '').toString().trim();
    final tel = telRaw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (tel.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Numéro indisponible.")));
      return;
    }
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Impossible d'appeler $tel")));
    }
  }

  Widget _buildStars(int rating, {void Function(int)? onTap}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          iconSize: 22,
          icon: Icon(
            i < rating ? Icons.star : Icons.star_border,
            color: _restoSecondary,
          ),
          onPressed: onTap == null ? null : () => onTap(i + 1),
        );
      }),
    );
  }

  Widget _starsStatic(double avg, {double size = 16}) {
    final full = avg.floor().clamp(0, 5);
    final half = (avg - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full)
          return Icon(Icons.star, size: size, color: _restoSecondary);
        if (i == full && half) {
          return Icon(Icons.star_half, size: size, color: _restoSecondary);
        }
        return Icon(Icons.star_border, size: size, color: _restoSecondary);
      }),
    );
  }

  Widget _avgBar() {
    // ✅ Barre note moyenne sous la description
    if (_avis.isEmpty || _noteMoyenne <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _neutralBorder),
        ),
        child: Row(
          children: const [
            Text("Aucun avis pour le moment",
                style: TextStyle(color: Colors.black54)),
            Spacer(),
            Icon(Icons.verified, size: 18, color: _restoSecondary),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          Text('(${_avis.length})',
              style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          const Icon(Icons.verified, size: 18, color: _restoSecondary),
        ],
      ),
    );
  }

  // Plein écran
  void _openFullScreenGallery(
      List<String> images, int initialIndex, String heroPrefix) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenGalleryPage(
          images: images,
          initialIndex: initialIndex,
          heroPrefix: heroPrefix,
        ),
      ),
    );
  }

  // Skeleton
  Widget _buildSkeletonContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 230,
            width: double.infinity,
            color: Colors.grey.shade200,
          ),
        ),
        const SizedBox(height: 14),
        Container(height: 20, width: 200, color: Colors.grey.shade200),
        const SizedBox(height: 8),
        Container(height: 14, width: 140, color: Colors.grey.shade200),
        const SizedBox(height: 18),
        Container(
            height: 14, width: double.infinity, color: Colors.grey.shade200),
        const SizedBox(height: 6),
        Container(
            height: 14, width: double.infinity, color: Colors.grey.shade200),
        const SizedBox(height: 6),
        Container(height: 14, width: 180, color: Colors.grey.shade200),
        const SizedBox(height: 14),
        Container(
            height: 44, width: double.infinity, color: Colors.grey.shade200),
        const SizedBox(height: 24),
        Container(height: 18, width: 160, color: Colors.grey.shade200),
        const SizedBox(height: 10),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  // ------- Contenu réel -------
  Widget _buildRestoContent() {
    final nom = (resto!['nom'] ?? '').toString();
    final ville = (resto!['ville'] ?? '').toString();
    final desc = (resto!['description'] ?? '').toString().trim();
    final spec = (resto!['specialites'] ?? '').toString().trim();
    final horaire = (resto!['horaires'] ?? '').toString().trim();
    final images = _imagesFrom(resto!['images']);
    final lat = (resto!['latitude'] as num?)?.toDouble();
    final lng = (resto!['longitude'] as num?)?.toDouble();

    const fallback = 'https://via.placeholder.com/1200x800.png?text=Restaurant';
    final heroPrefix = 'resto_${resto!['id'] ?? nom}';

    final trueCenter = (lat != null && lng != null) ? LatLng(lat, lng) : null;

    final canSend =
        _noteUtilisateur > 0 && _avisController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1) Galerie
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              SizedBox(
                height: 230,
                width: double.infinity,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: images.isEmpty ? 1 : images.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (context, index) {
                    final url = images.isEmpty ? fallback : images[index];
                    return GestureDetector(
                      onTap: images.isEmpty
                          ? null
                          : () =>
                              _openFullScreenGallery(images, index, heroPrefix),
                      child: Hero(
                        tag: '${heroPrefix}_$index',
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.grey[200]),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: const Icon(Icons.image,
                                color: Colors.grey, size: 36),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if ((images.isNotEmpty ? images.length : 1) > 1)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

        const SizedBox(height: 14),

        // 2) Titre + ville + spécialités
        Text(nom,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 18),
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

        if (spec.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            spec,
            style: const TextStyle(
              color: _restoPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        // 3) Description
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(desc, style: const TextStyle(height: 1.35)),
        ],

        if (horaire.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(horaire)),
            ],
          ),
        ],

        // 4) Note moyenne (sous description)
        const SizedBox(height: 12),
        _avgBar(),

        const SizedBox(height: 18),
        const Divider(height: 30),

        // 5) Carte + Google Maps
        const Text("Localisation",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        SizedBox(
          height: 200,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: trueCenter ?? _defaultCenter,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: trueCenter ?? _defaultCenter,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        ElevatedButton.icon(
          onPressed: (lat == null || lng == null)
              ? null
              : () async {
                  final uri = Uri.parse(
                      "https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
          icon: const Icon(Icons.map),
          label: const Text("Ouvrir dans Google Maps"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _restoPrimary,
            foregroundColor: _restoOnPrimary,
          ),
        ),

        const SizedBox(height: 18),
        const Divider(height: 30),

        // 6) Avis des utilisateurs (AVANT votre avis)
        const Text("Avis des utilisateurs",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        if (_avis.isEmpty)
          const Text("Aucun avis pour le moment.")
        else
          Column(
            children: _avis.map((a) {
              final uid = (a['auteur_id'] ?? '').toString();
              final u = _userCache[uid] ?? const {};
              final prenom = (u['prenom'] ?? '').toString();
              final nomU = (u['nom'] ?? '').toString();
              final photo = (u['photo_url'] ?? '').toString();
              final fullName = ('$prenom $nomU').trim().isEmpty
                  ? 'Utilisateur'
                  : ('$prenom $nomU').trim();

              final etoiles = (a['etoiles'] as num?)?.toDouble() ?? 0.0;
              final commentaire = (a['commentaire'] ?? '').toString().trim();
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
                            Text(commentaire,
                                style: const TextStyle(height: 1.3)),
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
        const Divider(height: 30),

        // 7) Votre avis (TOUT EN BAS)
        const Text("Votre avis", style: TextStyle(fontWeight: FontWeight.bold)),
        if (_dejaNote)
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 6),
            child: Text(
              "Vous avez déjà laissé un avis. Renvoyez pour mettre à jour.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        _buildStars(_noteUtilisateur,
            onTap: (n) => setState(() => _noteUtilisateur = n)),
        TextField(
          controller: _avisController,
          minLines: 3,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _envoyerAvis(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: "Votre commentaire",
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(12),
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
              borderSide: const BorderSide(color: _restoPrimary, width: 1.4),
            ),
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
              backgroundColor: _restoPrimary,
              foregroundColor: _restoOnPrimary,
              disabledBackgroundColor: _restoPrimary.withOpacity(0.35),
              disabledForegroundColor: _restoOnPrimary.withOpacity(0.85),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const bottomGradient = LinearGradient(
      colors: [_restoPrimary, _restoSecondary],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final titreAppBar = (resto?['nom'] ?? 'Restaurant').toString();

    final showSkeleton = loading && resto == null;
    final showNotFound = !loading && resto == null;

    return Scaffold(
      backgroundColor: _neutralBg,
      appBar: AppBar(
        title: Text(
          titreAppBar,
          style: const TextStyle(
            color: _restoPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _neutralSurface,
        foregroundColor: _restoPrimary,
        elevation: 1,
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.check_circle, size: 16, color: Colors.black26),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _restoPrimary),
            onPressed: () {
              _loadResto();
              _loadAvisBloc();
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: SizedBox(
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: bottomGradient),
            ),
          ),
        ),
      ),

      // ✅ Tap partout = ferme le clavier
      body: Listener(
        onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: showSkeleton
                  ? _buildSkeletonContent()
                  : (showNotFound
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Text("Restaurant introuvable"),
                          ),
                        )
                      : _buildRestoContent()),
            ),
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
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
                  onPressed: (resto == null || loading) ? null : _appeler,
                  icon: const Icon(Icons.phone),
                  label: const Text("Appeler"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _restoSecondary,
                    foregroundColor: _restoOnSecondary,
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
                  onPressed: (resto == null || loading) ? null : _reserver,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text("Réserver"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _restoPrimary,
                    foregroundColor: _restoOnPrimary,
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
      ),
    );
  }
}

/* =======================
   Plein écran (fond noir)
   ======================= */

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
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: total,
            itemBuilder: (_, i) {
              final url = widget.images[i];

              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Hero(
                  tag: '${widget.heroPrefix}_$i',
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: SizedBox.expand(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, ev) {
                          if (ev == null) return child;
                          return const ColoredBox(color: Colors.black);
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white70,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
