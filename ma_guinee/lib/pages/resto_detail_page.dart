// lib/pages/resto_detail_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Page de réservation (appel uniquement)
import 'restaurant_reservation_page.dart';

class RestoDetailPage extends StatefulWidget {
  final String restoId; // UUID du restaurant
  const RestoDetailPage({super.key, required this.restoId});

  @override
  State<RestoDetailPage> createState() => _RestoDetailPageState();
}

class _RestoDetailPageState extends State<RestoDetailPage> {
  final _sb = Supabase.instance.client;

  Map<String, dynamic>? resto;
  bool loading = true;
  String? _error;

  // Avis
  List<Map<String, dynamic>> _avis = []; // {auteur_id, etoiles, commentaire, created_at}
  double _noteMoyenne = 0.0;
  bool _dejaNote = false;

  // Cache profils auteurs
  final Map<String, Map<String, dynamic>> _userCache = {};

  // Saisie avis
  int _noteUtilisateur = 0; // 1..5
  final _avisController = TextEditingController();

  // Galerie
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final primaryColor = const Color(0xFF113CFC);
  String get _id => widget.restoId;

  bool _isUuid(String id) {
    final r = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return r.hasMatch(id);
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

  List<String> _imagesFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];
    return const [];
  }

  // Si tu actives un CDN, adapte ici
  String _thumbUrl(String url) => url;
  String _fullUrl(String url) => url;

  // ───────────────────────── RESTO
  Future<void> _loadResto() async {
    setState(() {
      loading = true;
      _error = null;
    });
    try {
      final data = await _sb
          .from('restaurants')
          .select('id, nom, ville, description, specialites, horaires, images, latitude, longitude, tel')
          .eq('id', _id)
          .maybeSingle();

      setState(() {
        resto = data == null ? null : Map<String, dynamic>.from(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _error = 'Erreur de chargement: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error!)));
    }
  }

  // ───────────────────────── AVIS
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
        final notes = list.map((e) => (e['etoiles'] as num?)?.toDouble() ?? 0.0).toList();
        final sum = notes.fold<double>(0.0, (a, b) => a + b);
        moyenne = sum / notes.length;
      }

      final user = _sb.auth.currentUser;
      final deja = user != null && list.any((a) => a['auteur_id'] == user.id);

      final ids = list
          .map((e) => e['auteur_id'])
          .whereType<String>()
          .where(_isUuid)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> fetched = {};
      if (ids.isNotEmpty) {
        final orFilter = ids.map((id) => 'id.eq.$id').join(',');
        final profiles = await _sb
            .from('utilisateurs')
            .select('id, nom, prenom, photo_url')
            .or(orFilter);

        for (final p in List<Map<String, dynamic>>.from(profiles)) {
          final id = (p['id'] ?? '').toString();
          fetched[id] = {
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
        _dejaNote = deja;
        _userCache..clear()..addAll(fetched);
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

      setState(() {
        _noteUtilisateur = 0;
        _avisController.clear();
        _dejaNote = true;
      });
      FocusScope.of(context).unfocus();

      await _loadAvisBloc();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avis enregistré ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi de l'avis: $e")),
      );
    }
  }

  // ✅ Ouvre la page de réservation (aucun fallback de numéro)
  void _reserver() {
    final nom = (resto?['nom'] ?? '').toString();
    final telRaw = (resto?['tel'] ?? resto?['telephone'] ?? '').toString().trim(); // reste vide si absent
    final images = _imagesFrom(resto?['images']);
    final address = (resto?['ville'] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantReservationPage(
          restoName: nom.isEmpty ? 'Restaurant' : nom,
          phone: telRaw.isEmpty ? null : telRaw,   // null si pas de numéro
          address: address.isEmpty ? null : address,
          coverImage: images.isNotEmpty ? _fullUrl(images.first) : null,
        ),
      ),
    );
  }

  void _appeler() async {
    final telRaw = (resto?['tel'] ?? resto?['telephone'] ?? '').toString().trim();
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
          icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
          onPressed: onTap == null ? null : () => onTap(i + 1),
        );
      }),
    );
  }

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
                    imageProvider: CachedNetworkImageProvider(_fullUrl(images[index])),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    heroAttributes: PhotoViewHeroAttributes(tag: 'resto_$index'),
                  );
                },
                onPageChanged: (i) => setS(() => current = i),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
              Positioned(
                bottom: 24, left: 0, right: 0,
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
              Positioned(
                top: 24, right: 8,
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
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadResto();
          await _loadAvisBloc();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ---------- Galerie
            if (images.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 230, width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentIndex = i),
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () => _openFullScreenGallery(images, index),
                          child: Hero(
                            tag: 'resto_$index',
                            child: CachedNetworkImage(
                              imageUrl: _fullUrl(images[index]),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (_, __) => Container(color: Colors.grey[200]),
                              errorWidget: (_, __, ___) =>
                                  const Center(child: Icon(Icons.image_not_supported)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8, top: 8,
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
                        child: CachedNetworkImage(
                          imageUrl: _thumbUrl(images[index]),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[200]),
                          errorWidget: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (spec.isNotEmpty) const SizedBox(height: 2),
            if (spec.isNotEmpty) Text(spec, style: const TextStyle(color: Colors.green)),
            Row(children: [
              const Icon(Icons.location_on, color: Colors.red),
              const SizedBox(width: 4),
              Text(ville),
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc),
            ],
            if (horaire.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 4),
                Text(horaire),
              ]),
            ],
            if (_noteMoyenne > 0) ...[
              const SizedBox(height: 8),
              Text("Note moyenne : ${_noteMoyenne.toStringAsFixed(1)} ⭐️"),
            ],

            const Divider(height: 30),

            // ---------- Avis (saisie)
            const Text("Votre avis", style: TextStyle(fontWeight: FontWeight.bold)),
            if (_dejaNote)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  "Vous avez déjà laissé un avis. Vous pouvez le mettre à jour.",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            _buildStars(_noteUtilisateur, onTap: (n) => setState(() => _noteUtilisateur = n)),
            TextField(
              controller: _avisController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Votre commentaire",
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _envoyerAvis,
                icon: const Icon(Icons.send, size: 18, color: Colors.black87),
                label: Text(_dejaNote ? "Mettre à jour" : "Envoyer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE68A),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ---------- Carte
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

            // ---------- Liste des avis
            const Text("Avis des utilisateurs", style: TextStyle(fontWeight: FontWeight.bold)),
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

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (photo.isNotEmpty)
                          ? CachedNetworkImageProvider(photo)
                          : null,
                      child: photo.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(fullName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${a['etoiles']} ⭐️"),
                        if (a['commentaire'] != null &&
                            a['commentaire'].toString().trim().isNotEmpty)
                          Text(a['commentaire'].toString()),
                        const SizedBox(height: 4),
                        Text(
                          DateTime.tryParse(a['created_at']?.toString() ?? '')
                                  ?.toLocal()
                                  .toString() ?? '',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),
          ]),
        ),
      ),

      // ✅ Barre collée en bas (toujours visible)
      bottomNavigationBar: SafeArea(
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
                  onPressed: _appeler,
                  icon: const Icon(Icons.phone),
                  label: const Text("Appeler"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _reserver,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text("Réserver"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
