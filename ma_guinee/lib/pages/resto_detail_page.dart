// lib/pages/resto_detail_page.dart
import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'restaurant_reservation_page.dart';

// ✅ Centralisation erreurs (offline/supabase/timeout + overlay anti-spam)
import 'package:ma_guinee/utils/error_messages_fr.dart';

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
  String? _error; // message FR uniquement (pas de technique)

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

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// ✅ Hero seulement sur mobile (stabilité : évite flashes/erreurs sur web/desktop)
  bool get _enableHero => _isMobilePlatform;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _handleError(Object e, StackTrace st, {String? fallbackSnack}) {
    // ✅ Overlay centralisé (anti-spam + offline confirmé seulement)
    SoneyaErrorCenter.showException(e, st);

    // ✅ Snack FR propre (optionnel)
    final msg = (fallbackSnack != null && fallbackSnack.trim().isNotEmpty)
        ? fallbackSnack
        : frMessageFromError(e, st);
    _snack(msg);
  }

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

  bool _validUrl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final u = Uri.tryParse(s.trim());
    return u != null && (u.isScheme('http') || u.isScheme('https'));
  }

  @override
  void initState() {
    super.initState();
    _loadResto();
    _loadAvisBloc();

    _avisController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _avisController.dispose();
    // ✅ évite callbacks map après fermeture
    try {
      _mapController.dispose();
    } catch (_) {}
    super.dispose();
  }

  // ---------------- Images helpers ----------------
  List<String> _imagesFrom(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => _validUrl(s))
          .toList();
    }
    final p = (raw ?? '').toString().trim();
    return _validUrl(p) ? [p] : [];
  }

  // ------- RESTO -------
  Future<void> _loadResto() async {
    if (!mounted) return;
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
        _error = null;
      });

      // ✅ Réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();

      // Dès que les coordonnées arrivent → repositionner la carte
      final lat = (resto?['latitude'] as num?)?.toDouble();
      final lng = (resto?['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // ✅ évite crash/flash si retour rapide
          if (!mounted) return;
          try {
            _mapController.move(LatLng(lat, lng), 15);
          } catch (_) {}
        });
      }
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _syncing = false;
        _error = frMessageFromError(e as Object, st);
      });
      _handleError(e as Object, st);
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
        final denom = notes.isEmpty ? 1 : notes.length;
        moyenne = notes.fold<double>(0.0, (a, b) => a + b) / denom;
      }

      final user = _sb.auth.currentUser;
      final deja = user != null && list.any((a) => a['auteur_id'] == user.id);

      final ids = list
          .map((e) => e['auteur_id'])
          .where((v) => v != null)
          .map((v) => v.toString())
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

      // ✅ Réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      if (!mounted) return;
      // ✅ pas d’erreur brute
      SoneyaErrorCenter.showException(e as Object, st);
      // Si tu veux un snack (sinon tu peux le retirer)
      _snack(frMessageFromError(e as Object, st));
    }
  }

  Future<void> _envoyerAvis() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      _snack("Connectez-vous pour laisser un avis.");
      return;
    }
    if (_noteUtilisateur == 0 || _avisController.text.trim().isEmpty) {
      _snack("Veuillez noter et commenter.");
      return;
    }
    if (!_isUuid(_id)) {
      _snack("Erreur : ID du restaurant invalide.");
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

      if (!mounted) return;
      setState(() {
        _noteUtilisateur = 0;
        _avisController.clear();
        _dejaNote = true;
      });

      await _loadAvisBloc();

      if (!mounted) return;
      _snack("Avis enregistré.");

      // ✅ Réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      if (!mounted) return;
      _handleError(
        e as Object,
        st,
        fallbackSnack: "Erreur lors de l'envoi de l'avis. Veuillez réessayer.",
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
      _snack("Numéro indisponible.");
      return;
    }
    final uri = Uri(scheme: 'tel', path: tel);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack("Impossible d'appeler.");
      }
    } catch (e, st) {
      _handleError(e as Object, st, fallbackSnack: "Impossible d'appeler.");
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
        if (i < full) {
          return Icon(Icons.star, size: size, color: _restoSecondary);
        }
        if (i == full && half) {
          return Icon(Icons.star_half, size: size, color: _restoSecondary);
        }
        return Icon(Icons.star_border, size: size, color: _restoSecondary);
      }),
    );
  }

  Widget _avgBar() {
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
          enableHero: _enableHero, // ✅
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

    // ✅ Tag stable : basé uniquement sur l'ID (pas sur nom)
    final heroPrefix = 'resto_${(resto!['id'] ?? _id).toString()}';

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
                  onPageChanged: (i) {
                    if (!mounted) return;
                    setState(() => _currentIndex = i);
                  },
                  itemBuilder: (context, index) {
                    final url = images.isEmpty ? fallback : images[index];

                    final img = CachedNetworkImage(
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
                    );

                    final child = GestureDetector(
                      onTap: images.isEmpty
                          ? null
                          : () =>
                              _openFullScreenGallery(images, index, heroPrefix),
                      child: img,
                    );

                    // ✅ Hero seulement mobile, et seulement si images réelles
                    if (!_enableHero || images.isEmpty) return child;

                    return Hero(
                      tag: '${heroPrefix}_$index',
                      transitionOnUserGestures: true,
                      child: child,
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

        // 4) Note moyenne
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
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  } catch (e, st) {
                    _handleError(e as Object, st,
                        fallbackSnack: "Impossible d'ouvrir Google Maps.");
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

        // 6) Avis des utilisateurs
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
                      backgroundImage: (photo.isNotEmpty && _validUrl(photo))
                          ? NetworkImage(photo)
                          : null,
                      child: (photo.isNotEmpty && _validUrl(photo))
                          ? null
                          : const Icon(Icons.person, size: 18),
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

        // 7) Votre avis
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
          textInputAction:
              canSend ? TextInputAction.send : TextInputAction.newline,
          onSubmitted: (_) {
            if (canSend) _envoyerAvis();
          },
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
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Text(
                              _error?.isNotEmpty == true
                                  ? _error!
                                  : "Restaurant introuvable",
                              textAlign: TextAlign.center,
                            ),
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
            onPageChanged: (i) {
              if (!mounted) return;
              setState(() => _index = i);
            },
            itemCount: total,
            itemBuilder: (_, i) {
              final url = widget.images[i];

              final content = SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
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
              );

              // ✅ Hero seulement mobile
              if (!widget.enableHero) return content;

              return Hero(
                tag: '${widget.heroPrefix}_$i',
                child: content,
              );
            },
          );
        },
      ),
    );
  }
}
