// lib/pages/sante_detail_page.dart
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'sante_rdv_page.dart';

// ✅ Centralisation erreurs (offline/supabase/timeout + overlay anti-spam)
import 'package:ma_guinee/utils/error_messages_fr.dart';

const kHealthYellow = Color(0xFFFCD116);
const kHealthGreen = Color(0xFF009460);
const kNeutralBorder = Color(0xFFE5E7EB);

class SanteDetailPage extends StatefulWidget {
  final dynamic cliniqueId; // BIGINT en base
  const SanteDetailPage({super.key, required this.cliniqueId});

  @override
  State<SanteDetailPage> createState() => _SanteDetailPageState();
}

class _SanteDetailPageState extends State<SanteDetailPage> {
  Map<String, dynamic>? clinique;
  bool loading = true;

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // ✅ Hero uniquement sur mobile (anti flash web/desktop)
  bool get _enableHero => _isMobilePlatform;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _handleError(Object e, StackTrace st, {String? fallbackSnack}) {
    SoneyaErrorCenter.showException(e, st);
    _snack(fallbackSnack ?? frMessageFromError(e, st));
  }

  @override
  void initState() {
    super.initState();
    _loadClinique();
  }

  Future<void> _loadClinique() async {
    setState(() => loading = true);

    final int? idForQuery = (widget.cliniqueId is num)
        ? (widget.cliniqueId as num).toInt()
        : int.tryParse(widget.cliniqueId.toString());

    if (idForQuery == null) {
      if (!mounted) return;
      setState(() => loading = false);
      _snack('ID de clinique invalide.');
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('cliniques')
          .select()
          .eq('id', idForQuery)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        clinique = (data == null) ? null : Map<String, dynamic>.from(data);
        loading = false;
      });

      // ✅ Réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      if (!mounted) return;
      setState(() => loading = false);

      _handleError(
        e as Object,
        st,
        fallbackSnack: "Impossible de charger le centre. Veuillez réessayer.",
      );
    }
  }

  List<String> _imagesFromClinique() {
    final raw = clinique?['images'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    final p = (clinique?['photo_url'] ?? '').toString();
    return p.isNotEmpty ? [p] : [];
  }

  Widget _smartImage(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image, size: 36, color: Colors.grey),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }

  // ---------- transition instantanée + Hero safe ----------
  void _openFullScreenGallery(List<String> images, int initialIndex) {
    if (images.isEmpty) return;

    final int? cliniqueIdInt = (widget.cliniqueId is num)
        ? (widget.cliniqueId as num).toInt()
        : int.tryParse(widget.cliniqueId.toString());

    final heroPrefix = 'clinique_${cliniqueIdInt ?? (clinique?['id'] ?? 'x')}';

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

  Future<void> _contacterCentre(String numero) async {
    final cleaned = numero.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      _snack("Numéro indisponible.");
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleaned);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        SoneyaErrorCenter.reportNetworkSuccess();
      } else {
        _snack("Impossible d'appeler.");
      }
    } catch (e, st) {
      _handleError(e as Object, st, fallbackSnack: "Impossible d'appeler.");
    }
  }

  Future<void> _ouvrirCarte() async {
    final lat = (clinique?['latitude'] as num?)?.toDouble();
    final lng = (clinique?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      _snack("Coordonnées non disponibles.");
      return;
    }

    final uri =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        SoneyaErrorCenter.reportNetworkSuccess();
      } else {
        _snack("Impossible d'ouvrir Google Maps.");
      }
    } catch (e, st) {
      _handleError(
        e as Object,
        st,
        fallbackSnack: "Impossible d'ouvrir Google Maps.",
      );
    }
  }

  void _ouvrirRdv() {
    final nom = (clinique?['nom'] ?? 'Centre médical').toString();
    final tel = (clinique?['tel'] ?? clinique?['telephone'] ?? '').toString();
    final address =
        (clinique?['adresse'] ?? clinique?['ville'] ?? '').toString();
    final images = _imagesFromClinique();

    final int? cliniqueIdInt = (widget.cliniqueId is num)
        ? (widget.cliniqueId as num).toInt()
        : int.tryParse(widget.cliniqueId.toString());

    if (cliniqueIdInt == null) {
      _snack('ID de clinique invalide.');
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => SanteRdvPage(
          cliniqueId: cliniqueIdInt,
          cliniqueName: nom.isEmpty ? 'Centre médical' : nom,
          phone: tel.trim().isEmpty ? null : tel.trim(),
          address: address.trim().isEmpty ? null : address.trim(),
          coverImage: images.isNotEmpty ? images.first : null,
          primaryColor: kHealthGreen,
        ),
      ),
    );
  }

  Widget _buildSkeleton(bool isWide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: isWide ? 300 : 230,
              color: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 24, width: 220, color: Colors.grey.shade200),
          const SizedBox(height: 8),
          Container(height: 14, width: 120, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Container(height: 16, width: 100, color: Colors.grey.shade200),
          const SizedBox(height: 6),
          Container(
              height: 50, width: double.infinity, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Container(height: 16, width: 80, color: Colors.grey.shade200),
          const SizedBox(height: 6),
          Container(
              height: 50, width: double.infinity, color: Colors.grey.shade200),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    const bottomGradient = LinearGradient(
      colors: [kHealthGreen, kHealthYellow],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    // Valeurs par défaut
    String nom = 'Centre médical';
    String ville = '';
    String specialites = '';
    List<String> images = const [];
    String horaires = '';
    String tel = '';

    if (clinique != null) {
      nom = (clinique?['nom'] ?? 'Centre médical').toString();
      ville = (clinique?['ville'] ?? 'Ville inconnue').toString();
      specialites = (clinique?['specialites'] ??
              clinique?['description'] ??
              'Spécialité non renseignée')
          .toString();
      images = _imagesFromClinique();
      horaires = (clinique?['horaires'] ??
              "Lundi - Vendredi : 8h – 18h\nSamedi : 8h – 13h\nDimanche : Fermé")
          .toString();
      tel = (clinique?['tel'] ?? clinique?['telephone'] ?? '').toString();
    }

    final int? cliniqueIdInt = (widget.cliniqueId is num)
        ? (widget.cliniqueId as num).toInt()
        : int.tryParse(widget.cliniqueId.toString());
    final heroPrefix = 'clinique_${cliniqueIdInt ?? (clinique?['id'] ?? 'x')}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: kHealthGreen),
        title: Text(
          nom,
          style: const TextStyle(
            color: kHealthGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
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
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          child: loading
              ? _buildSkeleton(isWide)
              : (clinique == null)
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text("Centre de santé introuvable."),
                      ),
                    )
                  : SingleChildScrollView(
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
                                    height: isWide ? 300 : 230,
                                    width: double.infinity,
                                    child: PageView.builder(
                                      controller: _pageController,
                                      itemCount: images.length,
                                      onPageChanged: (i) {
                                        if (!mounted) return;
                                        setState(() => _currentIndex = i);
                                      },
                                      itemBuilder: (context, index) {
                                        final child = GestureDetector(
                                          onTap: () => _openFullScreenGallery(
                                              images, index),
                                          child: _smartImage(
                                            images[index],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
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
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 230,
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(
                                    Icons.local_hospital,
                                    size: 70,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            nom,
                            style: TextStyle(
                              fontSize: isWide ? 28 : 24,
                              fontWeight: FontWeight.bold,
                              color: kHealthGreen,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: kHealthYellow, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ville,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 6),
                          const Text(
                            "Spécialités",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(specialites),
                          const SizedBox(height: 16),
                          const Text(
                            "Horaires",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(horaires),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _ouvrirCarte,
                            icon: const Icon(Icons.map),
                            label: const Text("Localiser sur la carte"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kHealthYellow,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
      bottomNavigationBar: (!loading && clinique != null)
          ? SafeArea(
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
                        onPressed: tel.trim().isEmpty
                            ? null
                            : () => _contacterCentre(tel),
                        icon: const Icon(Icons.call_rounded),
                        label: const Text("Appeler"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kHealthGreen,
                          foregroundColor: Colors.white,
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
                        onPressed: _ouvrirRdv,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text("Rendez-vous"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kHealthYellow,
                          foregroundColor: Colors.black,
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
            )
          : null,
    );
  }
}

/// --------------------------------------------------------------
///   GALLERIE PLEIN ÉCRAN (Hero uniquement sur mobile)
/// --------------------------------------------------------------
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
        onPageChanged: (i) {
          if (!mounted) return;
          setState(() => _index = i);
        },
        itemCount: total,
        itemBuilder: (_, i) {
          final url = widget.images[i];

          final content = Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white70,
                  size: 64,
                ),
                placeholder: (_, __) => Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image,
                    color: Colors.white54,
                    size: 48,
                  ),
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
