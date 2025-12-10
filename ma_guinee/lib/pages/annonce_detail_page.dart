// lib/pages/annonce_detail_page.dart
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:ma_guinee/models/annonce_model.dart';
import 'package:ma_guinee/pages/messages_annonce_page.dart';

class AnnonceDetailPage extends StatefulWidget {
  final AnnonceModel annonce;
  const AnnonceDetailPage({Key? key, required this.annonce}) : super(key: key);

  @override
  State<AnnonceDetailPage> createState() => _AnnonceDetailPageState();
}

class _AnnonceDetailPageState extends State<AnnonceDetailPage>
    with AutomaticKeepAliveClientMixin {
  final _sb = Supabase.instance.client;

  // ---------- PALETTE DOUCE ----------
  static const Color kPrimary = Color(0xFFD92D20); // rouge doux (actif)
  static const Color kPrimaryD =
      Color(0xFFB42318); // rouge doux foncé (pressed)
  static const Color kSecondary = Color(0xFFFFF1F1); // fond très léger
  static const Color kOnPrimary = Colors.white;

  // Neutres
  static const Color kPageBg = Color(0xFFF5F7FA);
  static const Color kCardStroke = Color(0xFFE5E7EB);
  static const Color kText = Color(0xFF1F2937);
  static const Color kText2 = Color(0xFF6B7280);

  // ---------- Storage ----------
  static const String _annonceBucket = 'annonce-photos';
  String _publicUrl(String p) {
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final path = p.startsWith('$_annonceBucket/')
        ? p.substring(_annonceBucket.length + 1)
        : p;
    return _sb.storage.from(_annonceBucket).getPublicUrl(path);
  }

  // UI
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  // Données
  Map<String, dynamic>? vendeur;
  late Future<List<AnnonceModel>> _futureSimilaires;
  late Future<List<AnnonceModel>> _futureSellerAnnonces;

  // Vues
  int _views = 0;
  bool _viewLogged = false;

  Color get _bg => kPageBg;

  bool get _isOwner => _sb.auth.currentUser?.id == widget.annonce.userId;
  String? get _meId => _sb.auth.currentUser?.id;

  String _fmtInt(num v) =>
      NumberFormat('#,##0', 'en_US').format(v.round()).replaceAll(',', '.');

  @override
  void initState() {
    super.initState();
    _views = widget.annonce.views;
    _chargerInfosVendeur();
    _futureSimilaires = _fetchAnnoncesSimilaires();
    _futureSellerAnnonces = _fetchSellerAnnonces();
    _incrementerVueEtCharger();

    // Pré-cache des photos pour un swipe instantané
    WidgetsBinding.instance.addPostFrameCallback((_) => _precachePhotos());
  }

  void _precachePhotos() {
    final photos = widget.annonce.images.map(_publicUrl);
    for (final url in photos) {
      precacheImage(NetworkImage(url), context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // ---------- Compteur de vues ----------
  Future<void> _incrementerVueEtCharger() async {
    if (_viewLogged) return;
    _viewLogged = true;
    try {
      final v = await _sb.rpc('increment_annonce_view', params: {
        '_annonce_id': widget.annonce.id,
      });
      if (v is int && mounted) setState(() => _views = v);
    } catch (_) {/* noop */}
  }

  // ---------- Vendeur & listes ----------
  Future<void> _chargerInfosVendeur() async {
    try {
      final data = await _sb
          .from('utilisateurs')
          .select()
          .eq('id', widget.annonce.userId)
          .maybeSingle();
      if (mounted && data is Map<String, dynamic>) {
        setState(() => vendeur = data);
      }
    } catch (_) {/* noop */}
  }

  Future<List<AnnonceModel>> _fetchAnnoncesSimilaires() async {
    try {
      final raw = await _sb
          .from('annonces')
          .select()
          .eq('ville', widget.annonce.ville)
          .neq('id', widget.annonce.id)
          .limit(5);
      final list = raw is List ? raw : <dynamic>[];
      return list
          .map((e) => AnnonceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <AnnonceModel>[];
    }
  }

  Future<List<AnnonceModel>> _fetchSellerAnnonces() async {
    try {
      final raw = await _sb
          .from('annonces')
          .select()
          .eq('user_id', widget.annonce.userId);
      final list = raw is List ? raw : <dynamic>[];
      return list
          .map((e) => AnnonceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <AnnonceModel>[];
    }
  }

  // ---------- Header images + actions ----------
  Widget _imagesHeader({double? height}) {
    final photos = widget.annonce.images.map(_publicUrl).toList();
    final hasImages = photos.isNotEmpty;

    final screenW = MediaQuery.of(context).size.width;
    // Ratio 4/3 : plus de hauteur, rendu plus "pro"
    final double headerH = height ?? screenW * 3 / 4;

    return SizedBox(
      height: headerH,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          hasImages
              ? PageView.builder(
                  controller: _pageController,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _openViewer(i),
                    child: CachedNetworkImage(
                      imageUrl: photos[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(color: Colors.black12),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.image_not_supported,
                              color: Colors.grey, size: 40),
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.image, size: 60, color: Colors.grey),
                  ),
                ),

          if (hasImages)
            Positioned(
              bottom: 12,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${photos.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),

          // Back
          Positioned(
            top: 12,
            left: 12,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Actions (icônes blanches au-dessus de la photo)
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: Icon(
                      widget.annonce.estFavori
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Colors.white,
                    ),
                    onPressed: () => setState(
                      () =>
                          widget.annonce.estFavori = !widget.annonce.estFavori,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: PopupMenuButton<String>(
                    color: Colors.white,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (v) =>
                        v == 'share' ? _shareAnnonce() : _openReportSheet(),
                    itemBuilder: (_) => _isOwner
                        ? const [
                            PopupMenuItem(
                                value: 'share', child: Text('Partager')),
                          ]
                        : const [
                            PopupMenuItem(
                                value: 'share', child: Text('Partager')),
                            PopupMenuItem(
                                value: 'report', child: Text('Signaler')),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openViewer(int index) {
    final photos = widget.annonce.images.map(_publicUrl).toList();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'viewer',
      barrierColor: Colors.black.withOpacity(0.92),
      pageBuilder: (_, __, ___) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: photos.length,
              pageController: PageController(initialPage: index),
              loadingBuilder: (context, event) => const SizedBox.shrink(),
              builder: (_, i) => PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(photos[i]),
                heroAttributes: PhotoViewHeroAttributes(tag: i),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareAnnonce() {
    final a = widget.annonce;
    Share.share([
      a.titre,
      '${_fmtInt(a.prix)} ${a.devise}',
      if (a.ville.isNotEmpty) 'Ville : ${a.ville}',
      if (a.description.isNotEmpty) a.description,
    ].join('\n'));
  }

  void _openReportSheet() {
    if (_meId == null) return _snack('Connexion requise pour signaler.');
    if (_isOwner) {
      return _snack('Vous ne pouvez pas signaler votre propre annonce.');
    }

    final reasons = [
      'Fausse annonce',
      'Tentative de fraude',
      'Contenu inapproprié',
      'Mauvaise expérience',
      'Usurpation d’identité',
      'Autre'
    ];
    final ctrl = TextEditingController();
    String selected = reasons.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Signaler cette annonce',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons
                    .map((r) => ChoiceChip(
                          label: Text(r),
                          selected: selected == r,
                          selectedColor: kSecondary,
                          onSelected: (_) => setLocal(() => selected = r),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Expliquez brièvement… (facultatif)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.report_gmailerrorred),
                  label: const Text('Envoyer le signalement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: kOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ).copyWith(
                    overlayColor: MaterialStateProperty.resolveWith(
                      (s) => s.contains(MaterialState.pressed)
                          ? kPrimaryD.withOpacity(.12)
                          : null,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final a = widget.annonce;
                    await _sb.from('reports').insert({
                      'context': 'annonce',
                      'cible_id': a.id,
                      'owner_id': a.userId,
                      'reported_by': _meId!,
                      'reason': selected,
                      'details':
                          ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : null,
                      'ville': a.ville,
                      'titre': a.titre,
                      'prix': a.prix,
                      'devise': a.devise,
                      'telephone': a.telephone,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    _snack('Signalement envoyé. Merci.');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Skeleton vendeur ----------
  Widget _vendeurSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vendu par', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade300,
          ),
          title: Container(
            height: 12,
            width: 100,
            color: Colors.grey.shade300,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              height: 10,
              width: 140,
              color: Colors.grey.shade200,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Fiche vendeur ----------
  Widget _buildVendeurComplet() {
    return FutureBuilder<List<AnnonceModel>>(
      future: _futureSellerAnnonces,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Désolé, impossible de charger les informations du vendeur pour l’instant. "
              "Vérifiez votre connexion puis réessayez.",
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        if (snap.connectionState != ConnectionState.done) {
          return _vendeurSkeleton();
        }

        final toutes = (snap.data ?? []);
        final totalAnnonces = toutes.length;

        final u = vendeur ?? {};
        final prenom = (u['prenom'] ?? '').toString().trim();
        final nom = (u['nom'] ?? '').toString().trim();
        final fallback = (u['name'] ?? u['username'] ?? '').toString().trim();
        final displayName = ('$prenom $nom').trim().isNotEmpty
            ? ('$prenom $nom').trim()
            : (fallback.isNotEmpty ? fallback : 'Utilisateur');

        final photo = (u['photo_url'] ?? '').toString().trim();
        final hasPhoto = photo.isNotEmpty && photo.startsWith('http');

        final dstr =
            (u['date_inscription'] ?? u['created_at'] ?? '').toString();
        final d = DateTime.tryParse(dstr);
        final membreDepuis =
            (d != null) ? 'Membre depuis ${d.month}/${d.year}' : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vendu par',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    hasPhoto ? CachedNetworkImageProvider(photo) : null,
                child: hasPhoto
                    ? null
                    : const Icon(Icons.person, color: Colors.white),
              ),
              title: Text(displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: kText)),
              subtitle: Text(
                [
                  if (membreDepuis.isNotEmpty) membreDepuis,
                  '$totalAnnonces ${totalAnnonces > 1 ? 'annonces' : 'annonce'}'
                ].join(' • '),
                style: const TextStyle(color: kText2),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- Autres annonces du vendeur ----------
  Widget _buildAutresDuVendeur() {
    return FutureBuilder<List<AnnonceModel>>(
      future: _futureSellerAnnonces,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "Nous n’arrivons pas à charger les autres annonces du vendeur. "
              "Veuillez réessayer plus tard.",
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list =
            (snap.data ?? []).where((a) => a.id != widget.annonce.id).toList();
        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Les autres annonces de ce vendeur',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final a = list[i];
                  final thumb =
                      a.images.isNotEmpty ? _publicUrl(a.images.first) : null;

                  return GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            AnnonceDetailPage(annonce: a),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        transitionsBuilder: (_, __, ___, child) => child,
                      ),
                    ),
                    child: Container(
                      width: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: kCardStroke),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (thumb != null)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
                              child: CachedNetworkImage(
                                imageUrl: thumb,
                                height: 90,
                                width: 150,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: Colors.grey.shade300),
                                errorWidget: (_, __, ___) => Container(
                                  height: 90,
                                  width: 150,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 90,
                              width: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8)),
                              ),
                              child: const Icon(Icons.image),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              a.titre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kText),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text("${_fmtInt(a.prix)} ${a.devise}",
                                style: const TextStyle(
                                    fontSize: 12, color: kText2)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- Skeleton similaires ----------
  Widget _similairesSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            "D’autres annonces qui pourraient vous intéresser",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) {
              return Container(
                width: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: kCardStroke),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 100,
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        height: 10,
                        width: 120,
                        color: Colors.grey.shade300,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        height: 10,
                        width: 80,
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------- Similaires ----------
  Widget _buildAnnoncesSimilaires() {
    return FutureBuilder<List<AnnonceModel>>(
      future: _futureSimilaires,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "Un problème empêche le chargement des annonces similaires. Réessayez plus tard.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        if (snap.connectionState != ConnectionState.done) {
          return _similairesSkeleton();
        }

        final list = snap.data ?? <AnnonceModel>[];
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "Pas d’annonce similaire pour ce produit dans votre ville.",
              textAlign: TextAlign.center,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "D’autres annonces qui pourraient vous intéresser",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final a = list[i];
                  final thumb =
                      a.images.isNotEmpty ? _publicUrl(a.images.first) : null;

                  return GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            AnnonceDetailPage(annonce: a),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        transitionsBuilder: (_, __, ___, child) => child,
                      ),
                    ),
                    child: Container(
                      width: 160,
                      decoration: BoxDecoration(
                        border: Border.all(color: kCardStroke),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (thumb != null)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
                              child: CachedNetworkImage(
                                imageUrl: thumb,
                                height: 100,
                                width: 160,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: Colors.grey.shade300),
                                errorWidget: (_, __, ___) => Container(
                                  height: 100,
                                  width: 160,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 100,
                              width: 160,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8)),
                              ),
                              child: const Icon(Icons.image),
                            ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              a.titre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: kText),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text("${_fmtInt(a.prix)} ${a.devise}",
                                style: const TextStyle(color: kText2)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- Utils ----------
  String _normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9\+]'), '');
  }

  // ---------- Barre d’actions bas ----------
  Widget _bottomActions() {
    if (_isOwner) return const SizedBox.shrink();
    final a = widget.annonce;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: _bg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: kPrimary),
                  foregroundColor: kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final me = _meId;
                  if (me == null) {
                    _snack('Connectez-vous pour envoyer un message.');
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessagesAnnoncePage(
                        annonceId: a.id,
                        annonceTitre: a.titre,
                        receiverId: a.userId,
                        senderId: me,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.forum_outlined),
                label: const Text("Message"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: kOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ).copyWith(
                  overlayColor: MaterialStateProperty.resolveWith(
                    (s) => s.contains(MaterialState.pressed)
                        ? kPrimaryD.withOpacity(.12)
                        : null,
                  ),
                ),
                onPressed: () async {
                  final telRaw = a.telephone;
                  final tel = _normalizePhone(telRaw);
                  if (tel.isEmpty) {
                    _snack(
                        'Numéro de téléphone indisponible dans cette annonce.');
                    return;
                  }
                  final uri = Uri.parse('tel:$tel');
                  final ok = await canLaunchUrl(uri);
                  if (!ok) {
                    _snack("Impossible d’ouvrir l’application Téléphone.");
                    return;
                  }
                  await launchUrl(uri);
                },
                icon: const Icon(Icons.call),
                label: const Text("Contacter"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final a = widget.annonce;

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: _bottomActions(),
      body: CustomScrollView(
        slivers: [
          // Image principale qui scrolle avec le reste (style Facebook)
          SliverToBoxAdapter(
            child: _imagesHeader(),
          ),

          // Contenu de la fiche
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.titre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Prix + Ville + Vues
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${_fmtInt(a.prix)} ${a.devise}',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: kText,
                                ),
                              ),
                              TextSpan(
                                text: '  •  ${a.ville}',
                                style: const TextStyle(
                                    fontSize: 16, color: kText2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.remove_red_eye_outlined,
                                size: 18, color: kText2),
                            const SizedBox(width: 4),
                            Text(
                              '${_fmtInt(_views)} vues',
                              style:
                                  const TextStyle(fontSize: 13, color: kText2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(a.description, style: const TextStyle(color: kText)),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: kCardStroke),
                  const SizedBox(height: 18),

                  _buildVendeurComplet(),
                  const SizedBox(height: 6),

                  _buildAutresDuVendeur(),
                  const SizedBox(height: 12),

                  _buildAnnoncesSimilaires(),
                  const SizedBox(height: 32), // petit espace avant le bas
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
